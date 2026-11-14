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
| `/help` | Lists the commands |

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
