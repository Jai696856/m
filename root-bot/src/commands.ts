import {
  rootServer,
  MessageType,
  ChannelMessageEvent,
  ChannelMessageCreatedEvent,
  RootApiException,
} from "@rootsdk/server-bot";
import { CHALLENGE, HELP, PALETTES, RULES, SUBJECTS, TWISTS } from "./content";
import { displayName, isAdmin } from "./members";
import { allRecords, awardXp, getRecord, levelFor, progressBar } from "./levels";
import { setWelcomeChannel } from "./welcome";

function pick<T>(list: readonly T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}

type Handler = (evt: ChannelMessageCreatedEvent) => Promise<string> | string;

const COMMANDS: Record<string, Handler> = {
  help: () => HELP,
  prompt: () => `🖌️ **Your prompt:** ${pick(SUBJECTS)}, ${pick(TWISTS)}.`,
  palette: () => {
    const p = pick(PALETTES);
    return `🎨 **${p.name}**\n${p.colors.map((c) => `\`${c}\``).join("  ")}`;
  },
  challenge: () => CHALLENGE,
  rules: () => RULES,
  hi: async (evt) => `👋 Hi ${await displayName(evt.userId)}! Show us what you're drawing today ✨`,

  level: async (evt) => {
    const rec = await getRecord(evt.userId);
    const xp = rec?.xp ?? 0;
    const name = rec?.name ?? (await displayName(evt.userId));
    return `⭐ **${name}** is **Level ${levelFor(xp)}**\n${progressBar(xp)}`;
  },

  leaderboard: async () => {
    const top = (await allRecords()).sort((a, b) => b.xp - a.xp).slice(0, 10);
    if (top.length === 0) return "🏆 Nobody has XP yet. Start chatting!";
    const medals = ["🥇", "🥈", "🥉"];
    const lines = top.map(
      (r, i) => `${medals[i] ?? `${i + 1}.`} **${r.name}**: Level ${levelFor(r.xp)} (${r.xp} XP)`,
    );
    return `🏆 **Top artists**\n${lines.join("\n")}`;
  },

  setwelcome: async (evt) => {
    if (!(await isAdmin(evt.userId))) return "🔒 Only the community owner or admins can do that.";
    await setWelcomeChannel(evt.channelId);
    return "✅ New members will be welcomed in this channel.";
  },
};
COMMANDS.rank = COMMANDS.level;
COMMANDS.top = COMMANDS.leaderboard;

export function initializeCommands(): void {
  rootServer.community.channelMessages.on(ChannelMessageEvent.ChannelMessageCreated, onMessage);
}

async function onMessage(evt: ChannelMessageCreatedEvent): Promise<void> {
  if (evt.messageType === MessageType.System) return;
  if (String(evt.userId) === String(rootServer.appId)) return; // ignore the bot's own messages

  const text = evt.messageContent?.trim() ?? "";

  if (!text.startsWith("/")) {
    try {
      await awardXp(evt.userId, await displayName(evt.userId), evt.channelId);
    } catch (err) {
      console.error("XP failed:", err instanceof RootApiException ? err.errorCode : err);
    }
    return;
  }

  const name = text.slice(1).split(/\s+/)[0].toLowerCase();
  const handler = COMMANDS[name];
  if (!handler) return;

  try {
    const content = await handler(evt);
    await rootServer.community.channelMessages.create({ channelId: evt.channelId, content });
  } catch (err: unknown) {
    console.error(`/${name} failed:`, err instanceof RootApiException ? err.errorCode : err);
  }
}
