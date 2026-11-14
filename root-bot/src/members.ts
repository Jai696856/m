import {
  rootServer,
  ChannelGuid,
  ChannelMessageCreatedEvent,
  CommunityRole,
  UserGuid,
} from "@rootsdk/server-bot";

export async function displayName(userId: UserGuid): Promise<string> {
  try {
    const member = await rootServer.community.communityMembers.get({ userId });
    return member.nickname || "friend";
  } catch {
    return "friend";
  }
}

/** A clickable @mention for a user. */
export function mention(userId: UserGuid, name: string): string {
  return `[@${name.replace(/[\[\]]/g, "")}](root://user/${userId})`;
}

/** A clickable #channel link. */
export function channelLink(channelId: ChannelGuid, name: string): string {
  return `[#${name.replace(/[\[\]]/g, "")}](root://channel/${channelId})`;
}

/** Users @mentioned in a message, in the order they appear. */
export function mentionedUsers(evt: ChannelMessageCreatedEvent): UserGuid[] {
  const ids = [...(evt.messageContent ?? "").matchAll(/root:\/\/user\/([A-Za-z0-9_-]+)/g)].map((m) => m[1]);
  return [...new Set(ids)] as unknown as UserGuid[];
}

/** The message text with all @mentions removed. */
export function withoutMentions(text: string): string {
  return text.replace(/\[[^\]]*\]\(root:\/\/[^)]*\)/g, "").replace(/\s+/g, " ").trim();
}

function isAdminRole(r: CommunityRole): boolean {
  return r.communityPermission.communityFullControl || r.communityPermission.communityManageCommunity;
}

function isModRole(r: CommunityRole): boolean {
  const p = r.communityPermission;
  return isAdminRole(r) || p.communityKick || p.communityCreateBan || p.communityManageBans;
}

async function hasRole(userId: UserGuid, test: (r: CommunityRole) => boolean): Promise<boolean> {
  try {
    const community = await rootServer.community.communities.get();
    if (community.ownerUserId === userId) return true;
    const member = await rootServer.community.communityMembers.get({ userId });
    const roles = await rootServer.community.communityRoles.list();
    return roles.some((r) => member.communityRoleIds.includes(r.id) && test(r));
  } catch {
    return false;
  }
}

/** Community owner, or anyone with a role that can manage the community. */
export const isAdmin = (userId: UserGuid) => hasRole(userId, isAdminRole);

/** Admins, plus anyone with a role that can kick or ban. */
export const isMod = (userId: UserGuid) => hasRole(userId, isModRole);

/** Roles that count as moderators (used to give mods access to tickets). */
export async function modRoles(): Promise<CommunityRole[]> {
  return (await rootServer.community.communityRoles.list()).filter(isModRole);
}

export async function say(channelId: ChannelGuid, content: string): Promise<void> {
  await rootServer.community.channelMessages.create({ channelId, content });
}
