import { rootServer, ChannelGuid, UserGuid, RootApiException } from "@rootsdk/server-bot";
import { LEVEL_ROLE_PREFIX, LEVEL_UP } from "./content";

// How XP works: each message earns 15–25 XP, at most once per minute per person (stops spam farming).
// Messages with an image attached earn double, so sharing art counts for more than chatting.
const XP_MIN = 15;
const XP_MAX = 25;
const ART_MULTIPLIER = 2;
const COOLDOWN_MS = 60_000;

// /daily: 50 XP, plus 10 XP per day of streak (up to +100), and +150 every 7th day in a row.
const DAILY_BASE = 50;
const DAILY_PER_STREAK_DAY = 10;
const DAILY_STREAK_CAP = 100;
const WEEKLY_STREAK_BONUS = 150;

export type XpRecord = {
  userId: UserGuid;
  name: string;
  xp: number;
  lastAt: number;
  artPosts?: number;
  streak?: number;
  lastDaily?: string; // "2026-11-16" (UTC day)
};

const key = (userId: UserGuid) => `xp:${userId}`;
const store = () => rootServer.dataStore.appData;
const today = (offsetDays = 0) => new Date(Date.now() + offsetDays * 864e5).toISOString().slice(0, 10);

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
  return store().get<XpRecord>(key(userId));
}

export async function allRecords(): Promise<XpRecord[]> {
  return store().selectValue<XpRecord>("xp:%");
}

/** 1-based rank on the leaderboard, or undefined if they have no XP. */
export async function rankOf(userId: UserGuid): Promise<number | undefined> {
  const sorted = (await allRecords()).sort((a, b) => b.xp - a.xp);
  const i = sorted.findIndex((r) => r.userId === userId);
  return i === -1 ? undefined : i + 1;
}

const fresh = (userId: UserGuid, name: string): XpRecord => ({ userId, name, xp: 0, lastAt: 0 });

async function announceLevelUp(userId: UserGuid, name: string, channelId: ChannelGuid, before: number, after: number) {
  const newLevel = levelFor(after);
  if (newLevel <= levelFor(before)) return;
  await rootServer.community.channelMessages.create({
    channelId,
    content: LEVEL_UP.replace("{name}", name).replace("{level}", String(newLevel)),
  });
  await giveLevelRole(userId, newLevel);
}

/** Call on every member message. Announces a level-up in the same channel. */
export async function awardXp(userId: UserGuid, name: string, channelId: ChannelGuid, hasArt: boolean): Promise<void> {
  const now = Date.now();
  let before = 0;
  let after = 0;

  await store().update<XpRecord>(
    key(userId),
    (rec) => {
      before = after = rec.xp;
      const artPosts = (rec.artPosts ?? 0) + (hasArt ? 1 : 0);
      if (now - rec.lastAt < COOLDOWN_MS) return { ...rec, name, artPosts };
      const gain = (XP_MIN + Math.floor(Math.random() * (XP_MAX - XP_MIN + 1))) * (hasArt ? ART_MULTIPLIER : 1);
      after = rec.xp + gain;
      return { ...rec, name, xp: after, lastAt: now, artPosts };
    },
    fresh(userId, name),
  );

  await announceLevelUp(userId, name, channelId, before, after);
}

export type DailyResult =
  | { claimed: false; streak: number }
  | { claimed: true; gain: number; streak: number; weekBonus: boolean; xp: number };

/** /daily: once per UTC day. Missing a day resets the streak. */
export async function claimDaily(userId: UserGuid, name: string, channelId: ChannelGuid): Promise<DailyResult> {
  let result = { claimed: false, streak: 0 } as DailyResult;
  let before = 0;

  await store().update<XpRecord>(
    key(userId),
    (rec) => {
      before = rec.xp;
      if (rec.lastDaily === today()) {
        result = { claimed: false, streak: rec.streak ?? 1 };
        return rec;
      }
      const streak = rec.lastDaily === today(-1) ? (rec.streak ?? 0) + 1 : 1;
      const weekBonus = streak % 7 === 0;
      const gain =
        DAILY_BASE + Math.min(DAILY_STREAK_CAP, (streak - 1) * DAILY_PER_STREAK_DAY) + (weekBonus ? WEEKLY_STREAK_BONUS : 0);
      result = { claimed: true, gain, streak, weekBonus, xp: rec.xp + gain };
      return { ...rec, name, xp: rec.xp + gain, streak, lastDaily: today() };
    },
    fresh(userId, name),
  );

  if (result.claimed) await announceLevelUp(userId, name, channelId, before, result.xp);
  return result;
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
