# Claude Fan Art bot (Root)

A small bot for the Claude Fan Art community on [Root](https://www.rootapp.com), built with the official `@rootsdk/server-bot` SDK.

## Commands

**Everyone**

| Command | What it does |
|---|---|
| `/prompt` | A random art prompt (subject + twist) |
| `/palette` | A random colour palette with hex codes |
| `/challenge` | This week's challenge |
| `/rules` / `/rule 3` | All rules, or one rule |
| `/level` (or `/rank`) | Your level, XP and a progress bar |
| `/leaderboard` (or `/top`) | Top 10 most active members |
| `/ticket <topic>` | Opens a private channel with the mods |
| `/close` | Closes your ticket (inside the ticket channel) |
| `/hi`, `/help` | Say hello, list commands |

**Mods** (owner, admins, or roles that can kick or ban). `/modhelp` lists these in chat.

| Command | What it does |
|---|---|
| `/warn @user reason` | Warns someone and keeps a record |
| `/warnings @user` / `/clearwarns @user` | Shows or clears someone's warnings |
| `/kick @user reason` / `/ban @user reason` | Kicks or bans someone |
| `/purge 10` | Deletes the last 1–50 messages in the channel |
| `/giveaway 1h Prize` | Starts a giveaway; people react to enter. Add `3w` for 3 winners: `/giveaway 2d 3w Prize` |
| `/gend` / `/greroll` | Ends the channel's giveaway now / picks a new winner |

Mods can't warn, kick or ban other mods or admins.

**Admin setup** (type each one in the channel you want)

| Command | What it does |
|---|---|
| `/setwelcome` | New members are welcomed here |
| `/setmodlog` | Mod actions and tickets are logged here (keep it private) |
| `/ticketsetup` | Ticket channels are created in this channel's category |
| `/postrules` | Posts the rules here and pins them |

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
