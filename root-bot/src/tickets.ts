import {
  rootServer,
  ChannelGroupGuid,
  ChannelGuid,
  ChannelMessageCreatedEvent,
  ChannelOverlayPermission,
  ChannelType,
  RoleOrMemberGuid,
  RootApiException,
  UserGuid,
} from "@rootsdk/server-bot";
import { channelLink, displayName, isAdmin, isMod, mention, modRoles, say } from "./members";
import { modLog } from "./moderation";

type Ticket = { channelId: ChannelGuid; openerId: UserGuid; topic: string; number: number; openedAt: number };

const GROUP_KEY = "config:ticketGroup";
const COUNTER_KEY = "ticket-counter";
const OPEN_KEY = (userId: string) => `ticket-open:${userId}`;
const ticketKey = (channelId: string) => `ticket:${channelId}`;
const store = () => rootServer.dataStore.appData;

// What the ticket opener and mods can do inside a ticket channel.
const ACCESS: ChannelOverlayPermission = {
  channelView: true,
  channelCreateMessage: true,
  channelViewMessageHistory: true,
  channelCreateMessageAttachment: true,
  channelCreateMessageReaction: true,
};

function slug(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 20) || "member";
}

export const TICKET_COMMANDS = {
  /** Admin: run in any channel inside the category where ticket channels should be created. */
  ticketsetup: async (evt: ChannelMessageCreatedEvent) => {
    if (!(await isAdmin(evt.userId))) return "🔒 Only the owner or admins can do that.";
    const channel = await rootServer.community.channels.get({ id: evt.channelId });
    await store().set({ key: GROUP_KEY, value: channel.channelGroupId });
    return "✅ Tickets will be created in this channel's category. Members can now type `/ticket <what you need help with>`.";
  },

  ticket: async (evt: ChannelMessageCreatedEvent, args: string) => {
    const groupId = await store().get<ChannelGroupGuid>(GROUP_KEY);
    if (!groupId) return "🎫 Tickets aren't set up yet. An admin needs to type `/ticketsetup` first.";

    const existing = await store().get<ChannelGuid>(OPEN_KEY(evt.userId));
    if (existing && (await store().get<Ticket>(ticketKey(existing))))
      return "🎫 You already have an open ticket. Please use that one, or close it with `/close`.";

    const topic = args.trim() || "No topic given";
    const name = await displayName(evt.userId);
    const number = await store().update<number>(COUNTER_KEY, (n) => n + 1, 0);
    const mods = await modRoles();

    let channelId: ChannelGuid;
    try {
      const channel = await rootServer.community.channels.create({
        channelGroupId: groupId,
        name: `ticket-${number}-${slug(name)}`,
        description: `Ticket #${number}: ${topic}`.slice(0, 200),
        channelType: ChannelType.Text,
        useChannelGroupPermission: false,
        accessRuleCreates: [
          { roleOrMemberId: evt.userId as unknown as RoleOrMemberGuid, overlay: ACCESS },
          ...mods.map((r) => ({ roleOrMemberId: r.id as unknown as RoleOrMemberGuid, overlay: ACCESS })),
        ],
      });
      channelId = channel.id;
    } catch (err) {
      console.error("Ticket create failed:", err);
      const code = err instanceof RootApiException ? ` (${err.errorCode})` : "";
      return `⚠️ I couldn't create a ticket channel${code}. An admin should check my permissions in that category.`;
    }

    const ticket: Ticket = { channelId, openerId: evt.userId, topic, number, openedAt: Date.now() };
    await store().set({ key: ticketKey(channelId), value: ticket });
    await store().set({ key: OPEN_KEY(evt.userId), value: channelId });

    const modPing = mods.map((r) => `[@${r.name}](root://role/${r.id})`).join(" ");
    await say(channelId,
      `🎫 **Ticket #${number}** opened by ${mention(evt.userId, name)}\n` +
      `**Topic:** ${topic}\n\n` +
      `Only you and the mods can see this channel. Tell us what's going on and a mod will reply soon. ${modPing}\n` +
      `When you're done, type \`/close\`.`);
    await modLog(`Ticket #${number} opened by ${name}: ${topic}`);
    return `🎫 Your ticket is open: ${channelLink(channelId, `ticket-${number}-${slug(name)}`)}`;
  },

  /** Run inside a ticket channel: the opener or any mod can close it. */
  close: async (evt: ChannelMessageCreatedEvent, args: string) => {
    const ticket = await store().get<Ticket>(ticketKey(evt.channelId));
    if (!ticket) return "This isn't a ticket channel.";
    if (ticket.openerId !== evt.userId && !(await isMod(evt.userId)))
      return "🔒 Only the person who opened this ticket or a mod can close it.";

    try {
      await rootServer.community.channels.delete({ id: evt.channelId });
    } catch (err) {
      console.error("Ticket close failed:", err);
      return "⚠️ I couldn't delete this channel. An admin should check my permissions.";
    }
    await store().delete(ticketKey(evt.channelId));
    await store().delete(OPEN_KEY(ticket.openerId));
    const closer = await displayName(evt.userId);
    await modLog(`Ticket #${ticket.number} (${ticket.topic}) closed by ${closer}${args.trim() ? `: ${args.trim()}` : ""}.`);
    return undefined; // the channel is gone, nothing to reply in
  },
};
