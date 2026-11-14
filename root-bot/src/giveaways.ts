import {
  rootServer,
  ChannelGuid,
  ChannelMessageCreatedEvent,
  ChannelMessageEvent,
  ChannelMessageReactionCreatedEvent,
  ChannelMessageReactionDeletedEvent,
  JobData,
  JobInterval,
  JobScheduleEvent,
  MessageGuid,
  RootApiException,
  UserGuid,
} from "@rootsdk/server-bot";
import { isMod, mention, say } from "./members";

type Giveaway = {
  messageId: MessageGuid;
  channelId: ChannelGuid;
  prize: string;
  winners: number;
  endsAt: number;
  hostId: UserGuid;
  entrants: UserGuid[];
  ended: boolean;
  winnerIds: UserGuid[];
};

const TAG = "giveaway";
const gKey = (messageId: string) => `giveaway:${messageId}`;
const latestKey = (channelId: string) => `giveaway-latest:${channelId}`;
const store = () => rootServer.dataStore.appData;

/** "30m", "2h", "1d", "1h30m" → milliseconds. */
export function parseDuration(text: string): number | undefined {
  const parts = [...text.toLowerCase().matchAll(/(\d+)\s*([smhdw])/g)];
  if (parts.length === 0 || parts.map((p) => p[0]).join("") !== text.toLowerCase().replace(/\s+/g, "")) return undefined;
  const unit: Record<string, number> = { s: 1e3, m: 6e4, h: 36e5, d: 864e5, w: 6048e5 };
  return parts.reduce((ms, p) => ms + Number(p[1]) * unit[p[2]], 0);
}

function pickWinners(entrants: UserGuid[], count: number, exclude: UserGuid[] = []): UserGuid[] {
  const pool = entrants.filter((u) => !exclude.includes(u));
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, count);
}

async function names(ids: UserGuid[]): Promise<string> {
  const out: string[] = [];
  for (const id of ids) {
    let name = "winner";
    try {
      name = (await rootServer.community.communityMembers.get({ userId: id })).nickname || name;
    } catch {}
    out.push(mention(id, name));
  }
  return out.join(", ");
}

export function initializeGiveaways(): void {
  rootServer.jobScheduler.on(JobScheduleEvent.Job, onJob);
  rootServer.jobScheduler.on(JobScheduleEvent.JobMissed, onJob); // bot was offline when it ended: end it now
  rootServer.community.channelMessages.on(ChannelMessageEvent.ChannelMessageReactionCreated, onReactAdd);
  rootServer.community.channelMessages.on(ChannelMessageEvent.ChannelMessageReactionDeleted, onReactRemove);
}

async function onJob(job: JobData): Promise<void> {
  if (job.tag !== TAG) return;
  try {
    await endGiveaway(job.resourceId);
  } catch (err) {
    console.error("Ending giveaway failed:", err instanceof RootApiException ? err.errorCode : err);
  }
}

async function onReactAdd(evt: ChannelMessageReactionCreatedEvent): Promise<void> {
  if (String(evt.userId) === String(rootServer.appId)) return;
  const g = await store().get<Giveaway>(gKey(evt.messageId));
  if (!g || g.ended || g.entrants.includes(evt.userId)) return;
  await store().update<Giveaway>(gKey(evt.messageId), (cur) =>
    cur.entrants.includes(evt.userId) ? cur : { ...cur, entrants: [...cur.entrants, evt.userId] }, g);
}

async function onReactRemove(evt: ChannelMessageReactionDeletedEvent): Promise<void> {
  const g = await store().get<Giveaway>(gKey(evt.messageId));
  if (!g || g.ended) return;
  await store().update<Giveaway>(gKey(evt.messageId), (cur) =>
    ({ ...cur, entrants: cur.entrants.filter((u) => u !== evt.userId) }), g);
}

async function endGiveaway(messageId: string): Promise<string | undefined> {
  const g = await store().get<Giveaway>(gKey(messageId));
  if (!g || g.ended) return undefined;
  const winnerIds = pickWinners(g.entrants, g.winners);
  await store().set({ key: gKey(messageId), value: { ...g, ended: true, winnerIds } });
  await rootServer.jobScheduler.deleteByResourceId(messageId).catch(() => {});

  const text = winnerIds.length
    ? `🎉 **Giveaway ended: ${g.prize}**\nCongratulations ${await names(winnerIds)}! 🥳\n(${g.entrants.length} entered)`
    : `🎉 **Giveaway ended: ${g.prize}**\nNobody entered, so there's no winner this time.`;
  await say(g.channelId, text);
  return text;
}

export const GIVEAWAY_COMMANDS = {
  /** /giveaway 1h [2w] Prize name */
  giveaway: async (evt: ChannelMessageCreatedEvent, args: string): Promise<string | undefined> => {
    if (!(await isMod(evt.userId))) return "🔒 Only mods can start giveaways.";
    const [durText, ...rest] = args.split(/\s+/);
    const duration = parseDuration(durText ?? "");
    let winners = 1;
    if (/^\d+w$/i.test(rest[0] ?? "")) winners = Math.max(1, Math.min(20, parseInt(rest.shift()!, 10)));
    const prize = rest.join(" ").trim();
    if (!duration || !prize)
      return "Usage: `/giveaway <time> [winners] <prize>`\nExamples: `/giveaway 1h Art commission`, `/giveaway 2d 3w Sticker pack`";
    if (duration < 60_000 || duration > 30 * 864e5) return "⏱️ Giveaways can last from 1 minute to 30 days.";

    const endsAt = Date.now() + duration;
    const msg = await rootServer.community.channelMessages.create({
      channelId: evt.channelId,
      content:
        `🎉 **GIVEAWAY: ${prize}** 🎉\n` +
        `React to this message to enter!\n` +
        `🏆 Winners: ${winners}  ⏰ Ends in ${durText}\nHosted by ${mention(evt.userId, "host")}`,
    });
    const g: Giveaway = {
      messageId: msg.id, channelId: evt.channelId, prize, winners, endsAt,
      hostId: evt.userId, entrants: [], ended: false, winnerIds: [],
    };
    await store().set({ key: gKey(msg.id), value: g });
    await store().set({ key: latestKey(evt.channelId), value: String(msg.id) });
    await rootServer.jobScheduler.create({
      resourceId: String(msg.id), tag: TAG, start: new Date(endsAt), jobInterval: JobInterval.OneTime,
    });
    try {
      await rootServer.community.channelMessages.reactionCreate({ channelId: evt.channelId, messageId: msg.id, shortcode: "tada" });
    } catch {}
    return undefined;
  },

  /** /gend: end the latest giveaway in this channel now. */
  gend: async (evt: ChannelMessageCreatedEvent): Promise<string | undefined> => {
    if (!(await isMod(evt.userId))) return "🔒 Only mods can end giveaways.";
    const id = await store().get<string>(latestKey(evt.channelId));
    if (!id || !(await endGiveaway(id))) return "There's no running giveaway in this channel.";
    return undefined;
  },

  /** /greroll: pick a new winner for the latest ended giveaway in this channel. */
  greroll: async (evt: ChannelMessageCreatedEvent): Promise<string | undefined> => {
    if (!(await isMod(evt.userId))) return "🔒 Only mods can reroll giveaways.";
    const id = await store().get<string>(latestKey(evt.channelId));
    const g = id ? await store().get<Giveaway>(gKey(id)) : undefined;
    if (!g || !g.ended) return "There's no finished giveaway in this channel to reroll.";
    const [winner] = pickWinners(g.entrants, 1, g.winnerIds);
    if (!winner) return "Nobody else entered, so there's no one to reroll to.";
    await store().set({ key: gKey(g.messageId), value: { ...g, winnerIds: [...g.winnerIds, winner] } });
    return `🔁 New winner for **${g.prize}**: ${await names([winner])}! 🎉`;
  },
};
