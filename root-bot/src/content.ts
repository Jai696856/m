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

export const HELP =
  "✨ **Claude Fan Art bot**\n" +
  "🎨 `/prompt` art idea · `/palette` colour palette · `/challenge` weekly challenge\n" +
  "⭐ `/level` your level · `/leaderboard` top artists\n" +
  "📜 `/rules` all rules · `/rule 3` one rule\n" +
  "🎫 `/ticket <topic>` private help from the mods · `/close` close your ticket\n" +
  "🎉 React to a giveaway message to enter\n" +
  "Mods: type `/modhelp`";

export const MOD_HELP =
  "🛡️ **Mod commands**\n" +
  "`/warn @user reason` · `/warnings @user` · `/clearwarns @user`\n" +
  "`/kick @user reason` · `/ban @user reason` · `/purge 10`\n" +
  "🎉 `/giveaway 1h Prize` · `/giveaway 2d 3w Prize` (3 winners) · `/gend` end now · `/greroll` new winner\n" +
  "**Admin setup:** `/setwelcome` · `/setmodlog` · `/ticketsetup` · `/postrules` (run each in the channel you want)";
