# Gravity Dash (Godot)

A one-button runner for **Godot 4.3+**. Your cube runs forward on its own. You can't jump: click, tap or press
Space to flip gravity, and the cube falls to the ceiling or back to the floor. Everything (levels, art, icons,
music and sound effects) is generated from code. The only asset file is the Fredoka font.

## Opening it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build, not .NET).
2. In the Project Manager, click **Import** and select `gravity-dash-godot/project.godot`.
3. Press **F5**.

It uses the Compatibility renderer, so it also exports to Web, Android and iOS.

## Playing in a browser

A web build is committed in `docs/gravity-dash/` (single-threaded, so it runs on GitHub Pages without special
headers). To rebuild it, install the Godot 4.3 export templates and run:

```
godot --headless --path gravity-dash-godot --export-release "Web" ../docs/gravity-dash/index.html
```

To play it online, turn on GitHub Pages for this repository (Settings, Pages, "Deploy from a branch", folder
`/docs`). The game is then at `https://<user>.github.io/<repo>/gravity-dash/`.

## Controls

| | |
|---|---|
| Flip gravity | Left click, tap, Space, W/S or Up/Down |
| Pause / resume | Esc or P, or the pause button |
| Restart the level | R |
| Practice checkpoints | Z to place, X to remove (or the on-screen buttons) |
| Level select | Left/Right arrows, Enter to play |

You can only flip while touching a surface. A press slightly early or just after leaving an edge still counts.

## What's in it

See [FEATURES.md](FEATURES.md) for the full numbered list. In short:

- **Main menu**: Icon Kit, Play and Explore in the middle. Bottom left: music, sound and settings. Bottom right:
  achievements, statistics and the Market. Top right: a lock that takes secret codes.
- **30 main levels** from Easy to Demon, each with 3 secret coins and 16 shards to collect, normal and practice
  progress, and a ghost of your best run.
- **Explore**: a grid of 15 tiles. Forge (build a level), Saved, Records, Quests, Ghost Race, Star Map, Daily,
  Weekly, Event, Trials, Featured, Chests, Paths, Packs and Search.
- **Objects**: spikes, saws, blocks, gravity orbs, gravity pads, gravity portals, speed portals, mini portals and
  dual portals (two mirrored cubes; one press flips both, and if either crashes you crash).
- **Currency**: shards (common) and prisms (rare). Earn them from levels, pickups, coins, quests, chests, paths,
  packs, trials, achievements and codes.
- **Four shops** that unlock as you play: Cube Bazaar, Trail Studio, Sound Shack and Prism Vault.
- **Icon kit**: 40 icons, 24 colours, 8 trails, 6 crash effects and 6 menu themes.
- **Music**: every level and menu theme has its own song, synthesised in code in one of six styles.
- **Win animation**: the cube spins into the gate, the screen flashes, fireworks go off, "LEVEL COMPLETE!" slams in
  letter by letter, then a results panel drops in with your rewards.

Progress is saved to `user://gravity_dash_save.json`.

## Difficulty

This version is **1.964739957393× harder** than the browser prototype. The constant `DIFFICULTY` in
`scripts/levels.gd` divides every reaction window (the gap between hazards) by that number, so you get about
half the time to react. Levels are also faster and longer as you go up the list.

Every level is built from a seed. When a level loads, a search bot plays it, and if it can't be finished the
layout is re-rolled. The bot's winning route is also where the secret coins and shards go.
`tools/check_levels.gd` runs the bot over every main, trial and featured level, a week of dailies, the weekly
and the event:

```
godot --headless --path gravity-dash-godot -s res://tools/check_levels.gd
```

`tools/tour.gd` erases the save, clicks through every screen, buys from a shop, opens a chest, enters a code,
plays a level to the end with the bot's inputs and saves screenshots (it needs a display, for example `xvfb-run`):

```
xvfb-run godot --path gravity-dash-godot -s res://tools/tour.gd -- /tmp/shots 4
```

## Files

| | |
|---|---|
| `scripts/main.gd` | Screen flow, main menu, level select, playing, pause, results, settings, codes |
| `scripts/screens_hub.gd` | The Explore grid and every screen behind it |
| `scripts/screens_shop.gd` | Icon kit, the Market and shops, jukebox, achievements, statistics |
| `scripts/world.gd` | Draws and runs a level: scenery, objects, coins, practice, ghost, trails, crash and win effects |
| `scripts/sim.gd` | Fixed-step physics (120 Hz) and the solver bot |
| `scripts/levels.gd` | Every level's parameters and the generator |
| `scripts/catalog.gd` | Items, shops, achievements, quests, paths and codes |
| `scripts/skins.gd` | Drawing for icons, difficulty faces and all symbols |
| `scripts/synth.gd`, `scripts/audio.gd` | Music and sound synthesis and playback |
| `scripts/save.gd` | Save data, wallet, stats, unlocks, quests and chests |
| `scripts/ui/` | Buttons, tiles, the logo, level card and small widgets |

The font is [Fredoka](https://fonts.google.com/specimen/Fredoka) under the SIL Open Font License (`fonts/FREDOKA-OFL.txt`).
