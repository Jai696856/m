---
name: idea-research
description: Before building something the user asks for, research how similar things are made to gather ideas, then propose a short plan. Use when the user asks to make a feature, game mechanic, scene, UI, tool, or system and says "research", "get ideas", "look at examples", or "/idea-research <thing>".
---

# Idea Research

Goal: spend a little effort learning how others solve the request, then turn that into concrete ideas for *this* project. Keep it cheap and fast.

## Steps

1. **Pin the request.** Restate in one line what to make. If one detail would change everything (e.g. 2D vs 3D), ask once; otherwise pick the sensible default.

2. **Check the project first (cheap).** Grep the repo for related code, scenes, scripts, assets, and docs so ideas fit what exists (engine, language, style, folder layout). Note anything reusable.

3. **Search the web (3–5 searches, one batch).** Send searches in the same turn with `mode: "standard"`. Use "extended" only if results are thin. Good queries:
   - `how to make <thing> in <engine/language>`
   - `<thing> tutorial` / `<thing> best practices`
   - `<thing> examples` / `games with <mechanic>` / `<thing> design ideas`
   - `<thing> common mistakes`
   Open at most 2–3 of the most useful pages for detail (use the web-fetch agent if there's no WebFetch tool).

4. **Extract ideas, not copies.** Pull out patterns, mechanics, and techniques. Do not recreate a specific existing game or product (names, characters, art, levels). Never paste large chunks of code from sources; adapt the approach.

5. **Report briefly** (no long essay):
   - **Ideas** — 4–8 bullets, each one line, marked *core* or *optional/stretch*.
   - **How to build it here** — 3–6 steps mapped to this project's files/engine.
   - **Pitfalls** — 1–3 bullets.
   - **Sources** — links used.
   - **Recommendation** — which ideas to build first.

6. **Then stop and ask** which ideas to build, unless the user already said to go ahead. If they did, build the recommended core ideas and follow the `lean-code` skill.

## Token discipline

- Max ~5 searches and ~3 page reads unless the user asks for deeper research.
- Don't spawn research subagents unless asked.
- Summarize sources; don't quote them at length.
