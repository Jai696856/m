import { rootServer, RootBotStartState } from "@rootsdk/server-bot";
import { initializeCommands } from "./commands";
import { initializeWelcome } from "./welcome";

async function onStarting(state: RootBotStartState) {
  initializeCommands();
  initializeWelcome();
  console.log(`Claude Fan Art bot started in community ${state.communityId}`);
}

(async () => {
  await rootServer.lifecycle.start(onStarting);
})();
