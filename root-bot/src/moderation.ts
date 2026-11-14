import {
  rootServer,
  ChannelGuid,
  ChannelMessageCreatedEvent,
  MessageDirectionTake,
  RootApiException,
  UserGuid,
} from "@rootsdk/server-bot";
import { displayName, isAdmin, isMod, mention, mentionedUsers, say, withoutMentions } from "./members";

type Warning = { reason: string; by: UserGuid; at: number };

const MODLOG_KEY = "config:modLogChannel";
const warnKey = (userId: string) => `warn:${userId}`;
const store = () => rootServer.dataStore.appData;

/** Post to the mod-log channel, if one has been set with /setmodlog. */
export async function modLog(text: string): Promise<void> {
  const channelId = await store().get<ChannelGuid>(MODLOG_KEY);
  if (!channelId) return;
  try {
    await say(channelId, `🛡️ ${text}`);
  } catch (err) {
    console.error("Mod log failed:", err instanceof RootApiException ? err.errorCode : err);
  }
}

type Target = { userId: UserGuid; name: string; reason: string };

/** Checks the caller is a mod and finds the @mentioned member. Returns an error message or the target. */
async function target(evt: ChannelMessageCreatedEvent, usage: string): Promise<string | Target> {
  if (!(await isMod(evt.userId))) return "🔒 Only mods can do that.";
  const [userId] = mentionedUsers(evt);
  if (!userId) return `Usage: \`${usage}\` (tap the person's name to @mention them)`;
  if (userId === evt.userId) return "You can't use that on yourself 🙂";
  if (await isMod(userId)) return "🛡️ You can't use mod commands on other mods or admins.";
  const reason = withoutMentions(evt.messageContent.replace(/^\/\S+/, "")) || "No reason given";
  return { userId, name: await displayName(userId), reason };
}

function failed(action: string, err: unknown): string {
  const code = err instanceof RootApiException ? ` (${err.errorCode})` : "";
  console.error(`${action} failed:`, err);
  return `⚠️ I couldn't ${action}${code}. Check that my role has that permission and is above theirs.`;
}

export const MOD_COMMANDS = {
  warn: async (evt: ChannelMessageCreatedEvent) => {
    const t = await target(evt, "/warn @user reason");
    if (typeof t === "string") return t;
    const list = await store().update<Warning[]>(
      warnKey(t.userId), (w) => [...w, { reason: t.reason, by: evt.userId, at: Date.now() }], []);
    await modLog(`${mention(t.userId, t.name)} was warned by ${mention(evt.userId, await displayName(evt.userId))}: ${t.reason} (warning #${list.length})`);
    return `⚠️ ${mention(t.userId, t.name)} has been warned: ${t.reason}\nThat's warning #${list.length}.`;
  },

  warnings: async (evt: ChannelMessageCreatedEvent) => {
    if (!(await isMod(evt.userId))) return "🔒 Only mods can see warnings.";
    const [userId] = mentionedUsers(evt);
    if (!userId) return "Usage: `/warnings @user`";
    const list = (await store().get<Warning[]>(warnKey(userId))) ?? [];
    const name = await displayName(userId);
    if (list.length === 0) return `✅ ${name} has no warnings.`;
    const lines = list.map((w, i) => `${i + 1}. ${w.reason} (${new Date(w.at).toISOString().slice(0, 10)})`);
    return `📋 **Warnings for ${name}** (${list.length})\n${lines.join("\n")}`;
  },

  clearwarns: async (evt: ChannelMessageCreatedEvent) => {
    if (!(await isMod(evt.userId))) return "🔒 Only mods can clear warnings.";
    const [userId] = mentionedUsers(evt);
    if (!userId) return "Usage: `/clearwarns @user`";
    await store().delete(warnKey(userId));
    const name = await displayName(userId);
    await modLog(`Warnings for ${name} were cleared by ${await displayName(evt.userId)}.`);
    return `🧹 Cleared all warnings for ${name}.`;
  },

  kick: async (evt: ChannelMessageCreatedEvent) => {
    const t = await target(evt, "/kick @user reason");
    if (typeof t === "string") return t;
    try {
      await rootServer.community.communityMemberBans.kick({ userId: t.userId });
    } catch (err) {
      return failed("kick them", err);
    }
    await modLog(`${t.name} was kicked by ${await displayName(evt.userId)}: ${t.reason}`);
    return `👢 ${t.name} has been kicked. Reason: ${t.reason}`;
  },

  ban: async (evt: ChannelMessageCreatedEvent) => {
    const t = await target(evt, "/ban @user reason");
    if (typeof t === "string") return t;
    try {
      await rootServer.community.communityMemberBans.create({ userId: t.userId, reason: t.reason });
    } catch (err) {
      return failed("ban them", err);
    }
    await modLog(`${t.name} was banned by ${await displayName(evt.userId)}: ${t.reason}`);
    return `🔨 ${t.name} has been banned. Reason: ${t.reason}`;
  },

  /** /purge 20: delete the last 20 messages in this channel (max 50). */
  purge: async (evt: ChannelMessageCreatedEvent, args: string) => {
    if (!(await isMod(evt.userId))) return "🔒 Only mods can purge messages.";
    const count = parseInt(args, 10);
    if (!count || count < 1 || count > 50) return "Usage: `/purge <1-50>`";
    try {
      const res = await rootServer.community.channelMessages.list({
        channelId: evt.channelId, messageDirectionTake: MessageDirectionTake.Older, dateAt: new Date(), limit: count + 1,
      });
      // The newest message is the /purge command itself, so it gets deleted too.
      for (const m of res.messages) {
        await rootServer.community.channelMessages.delete({ channelId: evt.channelId, id: m.id });
      }
      await modLog(`${await displayName(evt.userId)} purged ${Math.max(0, res.messages.length - 1)} messages.`);
    } catch (err) {
      return failed("delete those messages", err);
    }
    return undefined;
  },

  setmodlog: async (evt: ChannelMessageCreatedEvent) => {
    if (!(await isAdmin(evt.userId))) return "🔒 Only the owner or admins can do that.";
    await store().set({ key: MODLOG_KEY, value: evt.channelId });
    return "✅ Mod actions will be logged in this channel. Keep it private to mods!";
  },
};
