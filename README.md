# Sakura Spirit Defense

A browser version of the original game (Three.js) lives in [`web/`](web/README.md).

A 3D anime tower defense game built as a **Godot 4.3+** project in GDScript (also runs on Godot 4.4 and Xogot).
Everything (map, cel-shaded chibi heroes, spirits, effects, sounds and UI) is generated from code, so the
project has no imported art or audio assets.

## Opening it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build, not .NET).
2. In the Project Manager, click **Import** and select `project.godot` at the root of this repository.
3. Press **F5** (Run Project).

The look is a bright, top-down cartoon style: an island in the sea with a beach, palms and round leafy
trees, a cobblestone path, chunky outlined HUD numbers, and round play / fast-forward buttons.
The UI uses the rounded [Fredoka](https://fonts.google.com/specimen/Fredoka) font (SIL Open Font License) and
[Phosphor Icons](https://phosphoricons.com) (MIT). Both licences are in `licenses/`.

It uses the **Compatibility** renderer, so it can also be exported to Web, Android and iOS from
**Project → Export**.

## Playing on iPad / iPhone with Xogot

[Xogot](https://apps.apple.com/us/app/xogot-godot-for-ipad-iphone/id6469385251) is Godot 4.4 for iPad and iPhone.
This project is tested on Godot 4.3 and 4.4.1, and the Godot 4.4 `.uid` files are included, so it opens cleanly.

1. Get the project folder onto the device using one of the routes Xogot supports:
   - **iCloud Drive / Files:** unzip the project into iCloud Drive, then open that folder from Xogot.
   - **GitHub:** clone this repository with Working Copy, then open the cloned folder in Xogot (`project.godot` is at the root).
   - **USB drive:** copy the unzipped folder to a USB drive and open it from Xogot.
2. Open `project.godot` and press Play.

Touch controls:

| Action | Touch |
|---|---|
| Pick a hero | Tap a portrait (the class tabs 1-5 are along the top of the shop) |
| Place it | Tap on grass. The red **X** button cancels |
| Rotate / zoom / pan | One-finger drag / pinch / two-finger drag |
| Pause | The **II** button |
| Abilities, upgrades, selling | Tap the on-screen buttons |

The game locks to landscape on phones and tablets and keeps its UI inside the screen's safe area.
It uses the **Compatibility** renderer. If your device or Xogot version only offers the Mobile renderer, switch
it in *Project Settings → Rendering → Renderer*. Nothing in the game depends on a specific renderer.

## Controls

| Action | Mouse / keys | Touch |
|---|---|---|
| Pick a hero | Click a portrait, or **1–5** for a class then **Z X C V B** | Tap a portrait |
| Collect a farm's coin bundle | Click it | Tap it |
| Use a power | Power bar on the left, or **F G H J K L** | Tap the power bar |
| Place it | Click on grass (**Shift**-click places another) | Tap on grass |
| Select a placed hero | Click it | Tap it |
| Upgrade paths 1/2/3 | Panel buttons, or **, . /** | Panel buttons |
| Change targeting | Target button, or **Tab** | Target button |
| Sell | Sell button, or **Delete** | Sell button |
| Start round / change speed | **START** button, or **Space** | START button |
| Cancel | **Esc** or right-click | |
| Camera | Left-drag rotates, right-drag pans, wheel zooms | Drag rotates |

## Maps, modes and features

- **46 maps** (the original and 45 new ones) in four tiers. Track length sets the difficulty: Beginner maps
  average about 200 units of track and Expert maps about 120, so spirits reach the shrine much sooner.
  There are six themes (meadow, autumn, snow, desert, sakura, dusk). Each map has its own sea side, its own
  village layout and its own lighting. Routes are generated and validated by `tools/mapgen.py` into
  `scripts/maps.gd`.
- **Map select** with minimap previews, a medal for each difficulty, best-round tracking, and a medal counter.
- **Difficulties:** Easy, Normal, Hard and **Nightmare** (one life, prices 20% higher, its own purple medal).
- **Game modes:** Standard, Half Cash, Fortified (every spirit has double health), Deflation (start with
  $20,000 and earn nothing more), Rush (rounds back to back, spirits 25% faster), **One Class** (your first
  hero picks the class; the others close), **Boss Rush** (a boss every 5th round from round 10, bosses have 25%
  more health) and Sandbox (unlimited money and lives, no medals).
- **15 spirit types**, including the **Fox Spirit** (two hits, three tails), the **Paper Crane** (very fast,
  carries a fox), the **Lantern Ghost** (sharp attacks can't pierce it) and the boss **Shadow Shogun**
  (rounds 32 and 36, and in freeplay).
- **Shrine Blessings** (star button on the home screen): 15 permanent perks, such as extra starting money and
  lives, cheaper heroes, more range or speed, richer farms, faster abilities, an extra power slot and more
  gems. You earn one point per player level, and you can reset them for free. They don't apply in Sandbox.
- **Hero Charms:** reward items, each a recruited hero with upgrades already bought (for example Kaede
  3-1-0). Place one for free from the gold charm button in a game. Every win drops one (two on Hard and
  Nightmare), and the Store sells them for 60 gems.
- **Daily gift:** a 7-day login streak (gems, then a Hero Charm on days 6 and 7). Missing a day restarts it.
- **Player titles** that change as you level up (Shrine Novice, Spirit Warden, Gate Guardian, ...), and
  lifetime pops for each hero on the Heroes screen.
- **Continue:** the game saves at the end of every round. If you leave, a **CONTINUE** button on the home
  screen resumes it with the same heroes, upgrades, targeting, money and lives.
- **Spirit Almanac** (ghost button on the home screen): a 3D portrait, stats and tips for every spirit,
  filled in as you pop each kind.
- **Spirit modifiers:** *fortified* spirits have double health and a steel band; *regrowing* spirits have
  a pink halo and grow back a layer if left alone for 2.5 seconds. Both appear in later rounds.
- **Hero abilities:** every hero unlocks a special ability when any of its upgrade paths reaches tier 3.
  Use it from the ability bar or with **Q W E R T Y U I**.
- **21 heroes in 5 classes**, including **Komugi the rice farmer** (Support). Her paddy grows coin bundles
  during each round; tap them to collect, or buy *Farm Hand* to collect them automatically. Her paths are
  Harvest (bigger, faster bundles), Market (auto-collect, income, interest) and Scarecrow (a damaging pulse,
  lives and a speed buff). Her ability, *Bumper Crop*, grows 8 bundles worth double.
- **Spirit Gems** are earned from wins (more on Hard and Expert maps), achievements, level-ups, the daily
  challenge and daily quests.
- **Store** with six one-shot **powers** bought with gems: Time Stop, Shrine Bomb, Cash Drop, Healing Charm,
  Battle Cry and Golden Touch. Owned powers appear down the left edge in a game (up to 3 per game).
- **Daily quests:** three new goals every day on the home screen, each claimable for gems and XP.
- **Hero skins:** four colour styles per hero (Classic, Sakura, Midnight, Golden), bought with gems and
  picked in the upgrade tree.
- **Music:** a calm menu theme and a bouncier battle theme, synthesized in code. It renders on a worker
  thread at startup and can be switched off in Settings.
- **Tutorial:** a six-step coach in your first game (replay it from *How to play*).
- **Custom icons:** an app icon, class tab icons, and icons for gems, powers, quests, skins and upgrades,
  all from the shared SVG set in `scripts/icons.gd`.
- **Pause menu** (**Esc** or **P**) with Resume, Restart, Maps and Sound.
- The **save file** (`user://save.cfg`) stores best rounds, medals and settings.
- The **upgrade panel** shows the hero's live stats. The end screen shows spirits popped and money earned.

## Tests

```bash
godot --headless --path . -s tests/smoke_test.gd   # all maps, modes, modifiers, abilities, a full game
xvfb-run godot --path . -s tests/screenshot.gd -- /tmp/shots   # real screenshots of menu and themes
xvfb-run godot --path . -s tests/store_shots.gd -- /tmp/shots  # quests, store, skins, a farm game
xvfb-run godot --path . -s tests/ui_tour.gd -- /tmp/shots      # every screen, for visual review
xvfb-run godot --path . -s tests/model_shots.gd -- /tmp/shots  # line-ups of every hero and spirit
```

## Level and track

The level is a grid-based stone track on a grassy coast. `scenes/level/level.tscn` builds the terrain,
with sea and a curved beach along the top-left and left edges. It also places the windmill, four wooden
cottages, trees and decorations.

| Scene | Contents |
|---|---|
| `scenes/track/track.tscn` | Main Track: lays tiles on a 4×4-unit grid from the waypoint list in `scripts/track/track.gd`, validates the route, and batches every stone into two draw calls |
| `scenes/track/track_straight.tscn` / `track_corner.tscn` | Reusable track tiles: chunky bevelled stones over dark grout, a floor collider, and barriers on the closed sides. Corners also get a post at the inner corner |
| `scenes/track/stone_barrier.tscn` | Low stone wall segment with its own collider |
| `scenes/props/*.tscn` | House (4 variants), windmill (turning sails), tree, palm, bush, rock, decoration (lantern / crates / hay / fence), each with a collider |

Each map's route lives in `scripts/maps.gd` (the Track default is `ROUTE` in `scripts/track/track.gd`). Consecutive waypoints must share a row or a
column, and the first and last points are the entry and exit just outside the tiled area.
`validate()` reports any route that leaves a gap, reuses a cell, or runs two separate stretches side by side.
Spirits follow the centre line with slightly rounded 90° corners.

## Code layout

| File | What it does |
|---|---|
| `main.tscn` | One node running `scripts/main.gd` (instances the Level) |
| `scripts/main.gd` | Game loop: path, map, spirits, heroes, projectiles, rounds, camera, input |
| `scripts/defs.gd` | All game data: spirit types, 21 heroes in 5 classes and their 3×4 upgrade trees, balance numbers |
| `scripts/models.gd` | Builds every 3D model from primitive meshes, with toon shading and ink outlines |
| `scripts/ui.gd` | HUD, hero shop (3D-rendered portraits), upgrade panel, boss bar, menus |
| `scripts/sfx.gd` | Synthesizes all sound effects in code at startup |
| `scripts/music.gd` | Step-sequencer music, rendered to looping WAVs on a worker thread |
| `scripts/progress.gd` | XP, levels, achievements, daily challenge and quests, hero XP and unlocks, gems, powers, skins |
| `scripts/main_menu.gd` | Village-hub home, quest board, heroes and upgrade tree, store, achievements, stats, settings |
| `scripts/icons.gd` | SVG icon set (matches the Figma kit) |

To rebalance or add upgrades, edit `scripts/defs.gd`. In each upgrade's effect dictionary, `"key": n` adds,
`"key*": n` multiplies and `"key=": v` sets. Dotted keys such as `"explode.r"` reach into nested stats.
