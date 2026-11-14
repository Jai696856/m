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

export const RULES =
  "📜 **Claude Fan Art rules**\n" +
  "1. Be kind. Critique the art, never the artist.\n" +
  "2. Credit original creators. No art theft or tracing passed off as your own.\n" +
  "3. Keep it SFW.\n" +
  "4. Label AI-assisted work and post it in #ai-assisted.\n" +
  "5. Post in the right channel.\n" +
  "6. No spam or unsolicited DMs.\n" +
  "7. This is a fan community, not affiliated with Anthropic.\n" +
  "8. Mods have the final say.";

export const WELCOME =
  "🌸 Welcome to **Claude Fan Art**, {name}! ✨\n" +
  "👉 Read #rules, grab roles in #roles and say hi in #introductions.\n" +
  "Type `/help` to see what I can do. We can't wait to see your art! 🎨";

// {name} and {level} are filled in automatically.
export const LEVEL_UP = "🎉 **{name}** reached **Level {level}**! Keep creating ✨";

// Make roles named "Level 5", "Level 10", ... and the bot hands them out automatically.
export const LEVEL_ROLE_PREFIX = "Level";

export const HELP =
  "✨ **Claude Fan Art bot commands**\n" +
  "`/prompt` → a random art prompt\n" +
  "`/palette` → a random colour palette\n" +
  "`/challenge` → this week's challenge\n" +
  "`/rules` → community rules\n" +
  "`/level` → your level and XP\n" +
  "`/leaderboard` → top 10 most active artists\n" +
  "`/hi` → say hello\n" +
  "`/help` → this list\n" +
  "Admins: `/setwelcome` in a channel to welcome new members there.";
