import {
  rootServer,
  ChannelGuid,
  CommunityEvent,
  CommunityJoinedEvent,
  RootApiException,
} from "@rootsdk/server-bot";
import { WELCOME } from "./content";
import { displayName } from "./members";

const WELCOME_CHANNEL_KEY = "config:welcomeChannel";

export async function setWelcomeChannel(channelId: ChannelGuid): Promise<void> {
  await rootServer.dataStore.appData.set({ key: WELCOME_CHANNEL_KEY, value: channelId });
}

async function welcomeChannel(): Promise<ChannelGuid | undefined> {
  const saved = await rootServer.dataStore.appData.get<ChannelGuid>(WELCOME_CHANNEL_KEY);
  if (saved) return saved;
  // Not set yet: fall back to the community's default channel.
  return (await rootServer.community.communities.get()).defaultChannelId;
}

export function initializeWelcome(): void {
  rootServer.community.communities.on(CommunityEvent.CommunityJoined, onJoined);
}

async function onJoined(evt: CommunityJoinedEvent): Promise<void> {
  try {
    const channelId = await welcomeChannel();
    if (!channelId) {
      console.error("No welcome channel: type /setwelcome in the channel you want.");
      return;
    }
    const name = await displayName(evt.userId);
    await rootServer.community.channelMessages.create({ channelId, content: WELCOME.replace("{name}", name) });
  } catch (err) {
    console.error("Welcome failed:", err instanceof RootApiException ? err.errorCode : err);
  }
}
