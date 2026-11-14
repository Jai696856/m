import {
  rootServer,
  MessageType,
  ChannelMessageEvent,
  ChannelMessageCreatedEvent,
  RootApiException,
  UserGuid,
} from "@rootsdk/server-bot";
import { CHALLENGE, HELP, PALETTES, RULES, SUBJECTS, TWISTS } from "./content";

function pick<T>(list: readonly T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}

async function displayName(userId: UserGuid): Promise<string> {
  try {
    const member = await rootServer.community.communityMembers.get({ userId });
    return member.nickname || "friend";
  } catch {
    return "friend";
  }
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
};

export function initializeCommands(): void {
  rootServer.community.channelMessages.on(ChannelMessageEvent.ChannelMessageCreated, onMessage);
}

async function onMessage(evt: ChannelMessageCreatedEvent): Promise<void> {
  if (evt.messageType === MessageType.System) return;

  const text = evt.messageContent?.trim() ?? "";
  if (!text.startsWith("/")) return;

  const name = text.slice(1).split(/\s+/)[0].toLowerCase();
  const handler = COMMANDS[name];
  if (!handler) return;

  try {
    const content = await handler(evt);
    await rootServer.community.channelMessages.create({ channelId: evt.channelId, content });
  } catch (err: unknown) {
    if (err instanceof RootApiException) {
      console.error(`/${name} failed, RootApiException:`, err.errorCode);
    } else {
      console.error(`/${name} failed:`, err);
    }
  }
}
