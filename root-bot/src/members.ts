import { rootServer, UserGuid } from "@rootsdk/server-bot";

export async function displayName(userId: UserGuid): Promise<string> {
  try {
    const member = await rootServer.community.communityMembers.get({ userId });
    return member.nickname || "friend";
  } catch {
    return "friend";
  }
}

/** Community owner, or anyone with a role that can manage the community. */
export async function isAdmin(userId: UserGuid): Promise<boolean> {
  try {
    const community = await rootServer.community.communities.get();
    if (community.ownerUserId === userId) return true;
    const member = await rootServer.community.communityMembers.get({ userId });
    const roles = await rootServer.community.communityRoles.list();
    return roles.some(
      (r) =>
        member.communityRoleIds.includes(r.id) &&
        (r.communityPermission.communityFullControl || r.communityPermission.communityManageCommunity),
    );
  } catch {
    return false;
  }
}
