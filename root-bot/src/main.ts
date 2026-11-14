import { rootServer, RootBotStartState } from "@rootsdk/server-bot";
import { initializeCommands } from "./commands";

async function onStarting(state: RootBotStartState) {
  initializeCommands();
  console.log(`Claude Fan Art bot started in community ${state.communityId}`);
}

(async () => {
  await rootServer.lifecycle.start(onStarting);
})();
