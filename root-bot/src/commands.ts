import {
  rootServer,
  MessageType,
  ChannelMessageEvent,
  ChannelMessageCreatedEvent,
  RootApiException,
} from "@rootsdk/server-bot";
import { CHALLENGE, HELP, MOD_HELP, PALETTES, RULE_LIST, RULES, SUBJECTS, TWISTS } from "./content";
import { displayName, isAdmin, isMod } from "./members";
import { allRecords, awardXp, getRecord, levelFor, progressBar } from "./levels";
import { setWelcomeChannel } from "./welcome";
import { GIVEAWAY_COMMANDS } from "./giveaways";
import { MOD_COMMANDS } from "./moderation";
import { TICKET_COMMANDS } from "./tickets";

function pick<T>(list: readonly T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}

/** A command gets the message and the text after the command name. Return text to reply, or nothing. */
type Handler = (evt: ChannelMessageCreatedEvent, args: string) => Promise<string | undefined> | string | undefined;

const COMMANDS: Record<string, Handler> = {
  help: () => HELP,
  modhelp: async (evt) => ((await isMod(evt.userId)) ? MOD_HELP : "🔒 That list is for mods."),
  prompt: () => `🖌️ **Your prompt:** ${pick(SUBJECTS)}, ${pick(TWISTS)}.`,
  palette: () => {
    const p = pick(PALETTES);
    return `🎨 **${p.name}**\n${p.colors.map((c) => `\`${c}\``).join("  ")}`;
  },
  challenge: () => CHALLENGE,
  rules: () => RULES,
  rule: (_evt, args) => {
    const n = parseInt(args, 10);
    if (!n || n < 1 || n > RULE_LIST.length) return `Usage: \`/rule <1-${RULE_LIST.length}>\``;
    return `📜 **Rule ${n}:** ${RULE_LIST[n - 1]}`;
  },
  postrules: async (evt) => {
    if (!(await isAdmin(evt.userId))) return "🔒 Only the owner or admins can do that.";
    const msg = await rootServer.community.channelMessages.create({ channelId: evt.channelId, content: RULES });
    try {
      await rootServer.community.channelMessages.pinCreate({ channelId: evt.channelId, messageId: msg.id });
    } catch {
      return "📌 Posted the rules, but I couldn't pin them. Pin the message by hand, or give me pin permission.";
    }
    return undefined;
  },
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
    if (!(await isAdmin(evt.userId))) return "🔒 Only the owner or admins can do that.";
    await setWelcomeChannel(evt.channelId);
    return "✅ New members will be welcomed in this channel.";
  },

  ...GIVEAWAY_COMMANDS,
  ...MOD_COMMANDS,
  ...TICKET_COMMANDS,
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

  const match = text.match(/^\/(\S+)\s*([\s\S]*)$/);
  if (!match) return;
  const name = match[1].toLowerCase();
  const handler = COMMANDS[name];
  if (!handler) return;

  try {
    const content = await handler(evt, match[2]);
    if (content) await rootServer.community.channelMessages.create({ channelId: evt.channelId, content });
  } catch (err: unknown) {
    console.error(`/${name} failed:`, err instanceof RootApiException ? err.errorCode : err);
    try {
      await rootServer.community.channelMessages.create({
        channelId: evt.channelId,
        content: "⚠️ Something went wrong with that command. A mod can check the bot's logs.",
      });
    } catch {}
  }
}
