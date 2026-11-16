import {
  rootServer,
  ChannelGuid,
  ChannelMessageCreatedEvent,
  JobData,
  JobInterval,
  JobScheduleEvent,
  RootApiException,
  UserGuid,
} from "@rootsdk/server-bot";
import { EIGHT_BALL } from "./content";
import { parseDuration } from "./giveaways";
import { claimDaily, getRecord, levelFor, progressBar, rankOf } from "./levels";
import { displayName, mention, mentionedUsers, say } from "./members";

const store = () => rootServer.dataStore.appData;
const pick = <T>(list: readonly T[]): T => list[Math.floor(Math.random() * list.length)];

function randomHex(): string {
  // Pleasant random colours: random hue, medium-high saturation and lightness.
  const h = Math.random() * 360, s = 0.45 + Math.random() * 0.4, l = 0.4 + Math.random() * 0.35;
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    const c = l - s * Math.min(l, 1 - l) * Math.max(-1, Math.min(k - 3, 9 - k, 1));
    return Math.round(c * 255).toString(16).padStart(2, "0");
  };
  return `#${f(0)}${f(8)}${f(4)}`.toUpperCase();
}

// ---------- Reminders ----------

type Reminder = { userId: UserGuid; name: string; channelId: ChannelGuid; text: string };
const REMIND_TAG = "remind";
const remindKey = (id: string) => `remind:${id}`;

export function initializeFun(): void {
  rootServer.jobScheduler.on(JobScheduleEvent.Job, onJob);
  rootServer.jobScheduler.on(JobScheduleEvent.JobMissed, onJob);
}

async function onJob(job: JobData): Promise<void> {
  if (job.tag !== REMIND_TAG) return;
  const r = await store().get<Reminder>(remindKey(job.resourceId));
  if (!r) return;
  await store().delete(remindKey(job.resourceId));
  try {
    await say(r.channelId, `⏰ ${mention(r.userId, r.name)}, reminder: ${r.text}`);
  } catch (err) {
    console.error("Reminder failed:", err instanceof RootApiException ? err.errorCode : err);
  }
}

// ---------- Art trades ----------

type TradeEntry = { userId: UserGuid; name: string; note: string; at: number };
const TRADE_QUEUE = "trade-queue";

// ---------- Commands ----------

export const FUN_COMMANDS = {
  coinflip: () => (Math.random() < 0.5 ? "🪙 **Heads!**" : "🪙 **Tails!**"),

  "8ball": (_evt: ChannelMessageCreatedEvent, args: string) =>
    args.trim() ? `🎱 ${pick(EIGHT_BALL)}` : "Ask me a question! `/8ball Will my sketch turn out great?`",

  /** /roll, /roll 20, /roll 2d6 */
  roll: (_evt: ChannelMessageCreatedEvent, args: string) => {
    const m = args.trim().toLowerCase().match(/^(?:(\d{1,2})d)?(\d{1,4})?$/);
    if (!m) return "Usage: `/roll`, `/roll 20` or `/roll 2d6`";
    const count = Math.max(1, Math.min(20, Number(m[1] ?? 1)));
    const sides = Math.max(2, Math.min(1000, Number(m[2] ?? 6)));
    const rolls = Array.from({ length: count }, () => 1 + Math.floor(Math.random() * sides));
    const total = rolls.reduce((a, b) => a + b, 0);
    return count === 1 ? `🎲 You rolled **${total}** (1-${sides})` : `🎲 ${rolls.join(" + ")} = **${total}**`;
  },

  /** /colors 3: random colours to draw with. */
  colors: (_evt: ChannelMessageCreatedEvent, args: string) => {
    const n = Math.max(1, Math.min(8, parseInt(args, 10) || 3));
    const list = Array.from({ length: n }, randomHex);
    return `🎨 **Colour challenge:** use only these ${n} colours!\n${list.map((c) => `\`${c}\``).join("  ")}`;
  },

  /** /poll Question | Option 1 | Option 2 ... */
  poll: async (evt: ChannelMessageCreatedEvent, args: string) => {
    const parts = args.split("|").map((p) => p.trim()).filter(Boolean);
    if (parts.length < 3 || parts.length > 11)
      return "Usage: `/poll Question | Option 1 | Option 2` (2 to 10 options)";
    const [question, ...options] = parts;
    const nums = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"];
    const codes = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "keycap_ten"];
    const msg = await rootServer.community.channelMessages.create({
      channelId: evt.channelId,
      content:
        `📊 **${question}**\n${options.map((o, i) => `${nums[i]} ${o}`).join("\n")}\n` +
        `_React with the number to vote. Poll by ${await displayName(evt.userId)}_`,
    });
    for (let i = 0; i < options.length; i++) {
      try {
        await rootServer.community.channelMessages.reactionCreate({ channelId: evt.channelId, messageId: msg.id, shortcode: codes[i] });
      } catch {
        break; // emoji name not recognised: people can still react themselves
      }
    }
    return undefined;
  },

  daily: async (evt: ChannelMessageCreatedEvent) => {
    const name = await displayName(evt.userId);
    const r = await claimDaily(evt.userId, name, evt.channelId);
    if (!r.claimed) return `⏳ You've already claimed today's bonus, ${name}. Come back tomorrow! (🔥 ${r.streak}-day streak)`;
    return (
      `🎁 **+${r.gain} XP**, ${name}! 🔥 Streak: **${r.streak} day${r.streak === 1 ? "" : "s"}**` +
      (r.weekBonus ? "\n🌟 7-day streak bonus included! Amazing dedication!" : "")
    );
  },

  /** /profile or /profile @user */
  profile: async (evt: ChannelMessageCreatedEvent) => {
    const userId = mentionedUsers(evt)[0] ?? evt.userId;
    const rec = await getRecord(userId);
    const name = rec?.name ?? (await displayName(userId));
    const xp = rec?.xp ?? 0;
    const rank = await rankOf(userId);
    let joined = "";
    try {
      const m = await rootServer.community.communityMembers.get({ userId });
      if (m.joinedAt) joined = `\n📅 Joined: ${new Date(m.joinedAt).toISOString().slice(0, 10)}`;
    } catch {}
    return (
      `🪪 **${name}**\n` +
      `⭐ Level **${levelFor(xp)}**  ·  🏆 Rank **${rank ? `#${rank}` : "-"}**\n${progressBar(xp)}\n` +
      `🖼️ Art posts: **${rec?.artPosts ?? 0}**  ·  🔥 Daily streak: **${rec?.streak ?? 0}**` +
      joined
    );
  },

  /** /remind 30m finish the lineart */
  remind: async (evt: ChannelMessageCreatedEvent, args: string) => {
    const [when, ...rest] = args.trim().split(/\s+/);
    const ms = parseDuration(when ?? "");
    const text = rest.join(" ").trim();
    if (!ms || !text) return "Usage: `/remind <time> <what>`, e.g. `/remind 30m finish the lineart` or `/remind 2h stretch!`";
    if (ms < 60_000 || ms > 30 * 864e5) return "⏱️ Reminders can be from 1 minute to 30 days.";
    const id = `${evt.userId}-${Date.now()}`;
    const name = await displayName(evt.userId);
    await store().set({ key: remindKey(id), value: { userId: evt.userId, name, channelId: evt.channelId, text } });
    await rootServer.jobScheduler.create({ resourceId: id, tag: REMIND_TAG, start: new Date(Date.now() + ms), jobInterval: JobInterval.OneTime });
    return `⏰ Got it, ${name}! I'll remind you in ${when}.`;
  },

  /** /trade [what you'd like to draw]: join the queue, or get matched with whoever is waiting. */
  trade: async (evt: ChannelMessageCreatedEvent, args: string) => {
    const name = await displayName(evt.userId);
    const queue = (await store().get<TradeEntry[]>(TRADE_QUEUE)) ?? [];
    const fresh = queue.filter((t) => Date.now() - t.at < 7 * 864e5); // entries expire after a week
    if (args.trim().toLowerCase() === "cancel") {
      await store().set({ key: TRADE_QUEUE, value: fresh.filter((t) => t.userId !== evt.userId) });
      return "👋 You've left the art trade queue.";
    }
    if (fresh.some((t) => t.userId === evt.userId)) return "🤝 You're already waiting for a trade partner. (`/trade cancel` to leave)";
    const partner = fresh[0];
    if (!partner) {
      await store().set({ key: TRADE_QUEUE, value: [{ userId: evt.userId, name, note: args.trim(), at: Date.now() }] });
      return "🤝 You're in the art trade queue! I'll pair you with the next person who types `/trade`.";
    }
    await store().set({ key: TRADE_QUEUE, value: fresh.slice(1) });
    const note = (t: { note: string }) => (t.note ? `: _${t.note}_` : "");
    return (
      `🎨 **Art trade match!** ${mention(partner.userId, partner.name)}${note(partner)} 🤝 ${mention(evt.userId, name)}${note({ note: args.trim() })}\n` +
      "Draw something for each other and share it here when you're done! ✨"
    );
  },

  stats: async () => {
    const community = await rootServer.community.communities.get();
    const members = await rootServer.community.communityMembers.listAll();
    const recs = await rootServer.dataStore.appData.selectValue<{ xp: number; artPosts?: number }>("xp:%");
    const art = recs.reduce((n, r) => n + (r.artPosts ?? 0), 0);
    return (
      `📈 **${community.name}**\n` +
      `👥 Members: **${members.length}**\n` +
      `⭐ Members with XP: **${recs.length}**\n` +
      `🖼️ Art posts counted: **${art}**`
    );
  },
};
