import { rootServer, RootBotStartState } from "@rootsdk/server-bot";
import { initializeCommands } from "./commands";
import { initializeWelcome } from "./welcome";
import { initializeGiveaways } from "./giveaways";

async function onStarting(state: RootBotStartState) {
  initializeCommands();
  initializeWelcome();
  initializeGiveaways();
  console.log(`Claude Fan Art bot started in community ${state.communityId}`);
}

(async () => {
  await rootServer.lifecycle.start(onStarting);
})();
