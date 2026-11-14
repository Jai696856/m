# Claude Fan Art bot (Root)

A small bot for the Claude Fan Art community on [Root](https://www.rootapp.com), built with the official `@rootsdk/server-bot` SDK.

## Commands

| Command | What it does |
|---|---|
| `/prompt` | A random art prompt (subject + twist) |
| `/palette` | A random colour palette with hex codes |
| `/challenge` | This week's challenge |
| `/rules` | Community rules |
| `/hi` | Greets you by nickname |
| `/level` (or `/rank`) | Your level, XP and a progress bar |
| `/leaderboard` (or `/top`) | Top 10 most active members |
| `/setwelcome` | Admins only: welcome new members in this channel |
| `/help` | Lists the commands |

## Welcome messages

When someone joins, the bot greets them by name. By default it posts in the community's default channel.
To choose a channel, the owner or an admin types `/setwelcome` in that channel.

## Levels

- Every message earns 15–25 XP, at most once a minute per person, so spamming doesn't help.
- Levels need 100, 300, 600, 1000, 1500… total XP (each level takes 100 XP more than the last).
- Level-ups are announced in the channel where they happened.
- **Level roles:** create roles named `Level 5`, `Level 10` and so on, and the bot gives them out automatically.
  The bot needs the Manage Roles permission, and its role must be above those roles.

## Editing what it says

All text, prompts, palettes and the weekly challenge are in [`src/content.ts`](src/content.ts).
You can edit that file in the GitHub app or website, even from a phone.

## Building

```bash
npm install
npm run build
```

Before packaging, replace `your-bot-id` in `root-manifest.json` with the bot ID from the Root Developer Portal.
Docs: https://docs.rootapp.com
