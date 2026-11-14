import { rootServer, ChannelGuid, UserGuid, RootApiException } from "@rootsdk/server-bot";
import { LEVEL_ROLE_PREFIX, LEVEL_UP } from "./content";

// How XP works: each message earns 15–25 XP, at most once per minute per person (stops spam farming).
const XP_MIN = 15;
const XP_MAX = 25;
const COOLDOWN_MS = 60_000;

export type XpRecord = { userId: UserGuid; name: string; xp: number; lastAt: number };

const key = (userId: UserGuid) => `xp:${userId}`;

/** Total XP needed to reach a level: 100, 300, 600, 1000, 1500, ... */
export function xpForLevel(level: number): number {
  return 50 * level * (level + 1);
}

export function levelFor(xp: number): number {
  let level = 0;
  while (xp >= xpForLevel(level + 1)) level++;
  return level;
}

export function progressBar(xp: number): string {
  const level = levelFor(xp);
  const start = xpForLevel(level);
  const end = xpForLevel(level + 1);
  const filled = Math.floor(((xp - start) / (end - start)) * 10);
  return "▰".repeat(filled) + "▱".repeat(10 - filled) + ` ${xp - start}/${end - start} XP`;
}

export async function getRecord(userId: UserGuid): Promise<XpRecord | undefined> {
  return rootServer.dataStore.appData.get<XpRecord>(key(userId));
}

export async function allRecords(): Promise<XpRecord[]> {
  return rootServer.dataStore.appData.selectValue<XpRecord>("xp:%");
}

/** Call on every member message. Announces a level-up in the same channel. */
export async function awardXp(userId: UserGuid, name: string, channelId: ChannelGuid): Promise<void> {
  const now = Date.now();
  let before = 0;
  let after = 0;
  let skipped = false;

  await rootServer.dataStore.appData.update<XpRecord>(
    key(userId),
    (rec) => {
      before = rec.xp;
      if (now - rec.lastAt < COOLDOWN_MS) {
        skipped = true;
        after = rec.xp;
        return { ...rec, name };
      }
      after = rec.xp + XP_MIN + Math.floor(Math.random() * (XP_MAX - XP_MIN + 1));
      return { userId, name, xp: after, lastAt: now };
    },
    { userId, name, xp: 0, lastAt: 0 },
  );

  if (skipped) return;
  const oldLevel = levelFor(before);
  const newLevel = levelFor(after);
  if (newLevel <= oldLevel) return;

  await rootServer.community.channelMessages.create({
    channelId,
    content: LEVEL_UP.replace("{name}", name).replace("{level}", String(newLevel)),
  });
  await giveLevelRole(userId, newLevel);
}

/** If the community has a role called e.g. "Level 5", give it to people who reach level 5. */
async function giveLevelRole(userId: UserGuid, level: number): Promise<void> {
  try {
    const roles = await rootServer.community.communityRoles.list();
    const role = roles.find((r) => r.name.trim().toLowerCase() === `${LEVEL_ROLE_PREFIX} ${level}`.toLowerCase());
    if (!role) return;
    await rootServer.community.communityMemberRoles.add({ communityRoleId: role.id, userIds: [userId] });
  } catch (err) {
    const code = err instanceof RootApiException ? err.errorCode : err;
    console.error("Could not give level role (does the bot have Manage Roles?):", code);
  }
}
