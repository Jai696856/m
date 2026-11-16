// Everything the bot says lives here, so it's easy to edit (even from a phone, on GitHub).

export const SUBJECTS = [
  "Claude as a wizard casting spells made of words",
  "Claude as a cozy café barista",
  "Claude exploring a sakura forest",
  "Claude as a space explorer",
  "Claude reading in a giant library",
  "Claude as a knight guarding a castle of books",
  "Claude in a rainy cyberpunk city",
  "Claude painting a self-portrait",
  "Claude as a gentle sea creature",
  "Claude teaching a class of tiny robots",
  "Claude as a lighthouse keeper",
  "Claude in your favourite anime's art style",
  "Claude as a garden spirit",
  "Claude on a picnic with friends",
  "Claude as a detective solving a mystery",
];

export const TWISTS = [
  "using only three colours",
  "in a chibi style",
  "as a pixel-art sprite",
  "drawn in under 15 minutes",
  "at sunset",
  "in a stained-glass style",
  "with a winter theme",
  "as a trading card",
  "drawn with your non-dominant hand",
  "in a retro 90s anime style",
  "in black and white ink",
  "as a sticker design",
];

// /prompt game: a genre, a core mechanic and a twist. Everything should be small enough for a game jam.
export const GAME_GENRES = [
  "a cozy farming game", "a tiny platformer", "a puzzle game", "a tower defense game", "a visual novel",
  "a rhythm game", "a roguelike", "a point-and-click adventure", "a racing game", "a card game",
  "a pet simulator", "an idle/clicker game", "a stealth game", "a fishing game", "a cooking game",
];
export const GAME_MECHANICS = [
  "where Claude helps players by answering riddles", "where every level is solved by rearranging words",
  "where you can only move when the music plays", "where you swap places with your shadow",
  "where gravity flips every 10 seconds", "where you build the level as you play it",
  "where enemies become friends when you compliment them", "where time only moves when you move",
  "where your inventory is a tiny backpack you must pack like Tetris", "with a one-button control scheme",
  "where you paint platforms into existence", "where every choice changes the art style",
];
export const GAME_TWISTS = [
  "and it must be finishable in 5 minutes", "and it's set inside a giant library",
  "and the whole game fits on one screen", "and it uses only 4 colours", "and the main character can't jump",
  "and it's set during a rainy night in a sakura village", "and the title screen is part of the game",
  "and it has to work on a phone", "and the villain is a misunderstood robot", "and there is no text at all",
];

// /prompt video: a format, a subject and a twist.
export const VIDEO_FORMATS = [
  "a 30-second animation", "a speedpaint timelapse", "a short comic dub", "a stop-motion clip",
  "a fake movie trailer", "a 'day in the life' vlog", "a music video", "a tutorial",
  "a reaction-style skit", "a lo-fi study stream intro", "a before/after redraw video", "a cooking-show parody",
];
export const VIDEO_SUBJECTS = [
  "Claude learning to draw", "Claude's first day at art school", "Claude as a tour guide in a fantasy city",
  "Claude and a cat trying to bake a cake", "Claude reviewing the community's art", "Claude exploring the deep sea",
  "Claude running a tiny café", "Claude building a robot friend", "Claude getting lost in a museum",
  "Claude teaching a dragon to read",
];
export const VIDEO_TWISTS = [
  "told without any dialogue", "in a retro 90s anime style", "in one continuous shot", "made only with paper cut-outs",
  "with a surprise ending", "in under 60 seconds", "narrated like a nature documentary", "in pixel art",
  "using only sound effects you make yourself", "as a split-screen story",
];

export const PALETTES = [
  { name: "Warm Clay", colors: ["#D97757", "#F0E6DC", "#3D3929", "#C6A48A", "#8A9A5B"] },
  { name: "Sakura Dusk", colors: ["#F7C6D0", "#E58FA5", "#6B4E71", "#2E2A4F", "#FFF4E6"] },
  { name: "Ocean Glass", colors: ["#0B3954", "#087E8B", "#BFD7EA", "#FF5A5F", "#F5F5F5"] },
  { name: "Forest Lantern", colors: ["#1B4332", "#40916C", "#95D5B2", "#F4A261", "#FFE8D6"] },
  { name: "Neon Night", colors: ["#0D0221", "#541388", "#F706CF", "#2DE2E6", "#F6F930"] },
  { name: "Paper Sketch", colors: ["#FAF7F0", "#CDBBA7", "#7D6E57", "#3B3024", "#B85C38"] },
];

export const CHALLENGE =
  "🎨 **This week's challenge:** Claude in a cozy autumn scene 🍂\n" +
  "Post your entry in #weekly-challenge before Sunday! Any medium welcome.";

// Edit the rules here. /rules shows them all, /rule 3 shows one, /postrules posts and pins them.
export const RULE_LIST = [
  "Be kind. Critique the art, never the artist.",
  "Credit original creators. No art theft or tracing passed off as your own.",
  "Keep it SFW. No NSFW, gore or hateful content.",
  "Label AI-assisted work and post it in #ai-assisted.",
  "Post in the right channel.",
  "No spam, self-promo floods or unsolicited DMs.",
  "This is a fan community and isn't affiliated with Anthropic.",
  "Mods have the final say. Need help? Type /ticket.",
];

export const RULES =
  "📜 **Claude Fan Art rules**\n" + RULE_LIST.map((r, i) => `${i + 1}. ${r}`).join("\n");

export const WELCOME =
  "🌸 Welcome to **Claude Fan Art**, {name}! ✨\n" +
  "👉 Read #rules, grab roles in #roles and say hi in #introductions.\n" +
  "Type `/help` to see what I can do. We can't wait to see your art! 🎨";

// {name} and {level} are filled in automatically.
export const LEVEL_UP = "🎉 **{name}** reached **Level {level}**! Keep creating ✨";

// Make roles named "Level 5", "Level 10", ... and the bot hands them out automatically.
export const LEVEL_ROLE_PREFIX = "Level";

export const EIGHT_BALL = [
  "Yes, definitely! ✨", "It is certain.", "Without a doubt.", "Most likely.", "Signs point to yes.",
  "Ask again after a coffee break ☕", "Better not tell you now.", "Cannot predict now. Keep sketching!",
  "Don't count on it.", "My sources say no.", "Very doubtful.", "The paint isn't dry on that one yet 🎨",
];

export const HELP =
  "✨ **Claude Fan Art bot**\n" +
  "🎨 `/prompt` art idea · `/prompt game` · `/prompt video` · `/palette` palette · `/colors 3` colour challenge · `/challenge` weekly challenge\n" +
  "🤝 `/trade` art trade with someone · `/trade cancel` to leave the queue\n" +
  "⭐ `/level` · `/profile` · `/daily` bonus XP · `/leaderboard` (posting art earns double XP!)\n" +
  "🎲 `/8ball question` · `/coinflip` · `/roll 2d6` · `/poll Question | A | B`\n" +
  "⏰ `/remind 30m finish sketch` · 📈 `/stats`\n" +
  "📜 `/rules` · `/rule 3` · 🎫 `/ticket <topic>` private help from mods\n" +
  "🎉 React to a giveaway message to enter · Mods: `/modhelp`";

export const MOD_HELP =
  "🛡️ **Mod commands**\n" +
  "`/warn @user reason` · `/warnings @user` · `/clearwarns @user`\n" +
  "`/kick @user reason` · `/ban @user reason` · `/purge 10`\n" +
  "🎉 `/giveaway 1h Prize` · `/giveaway 2d 3w Prize` (3 winners) · `/gend` end now · `/greroll` new winner\n" +
  "**Admin setup:** `/setwelcome` · `/setmodlog` · `/ticketsetup` · `/postrules` (run each in the channel you want)";
