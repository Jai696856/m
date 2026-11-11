# Sakura Spirit Defense: Godot version

The same 3D anime tower defense game, rebuilt as a **Godot 4.3+** project in GDScript.
Everything (map, cel-shaded chibi heroes, spirits, effects, sounds and UI) is generated from code, so the
project has no imported art or audio assets.

## Opening it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build, not .NET).
2. In the Project Manager, click **Import** and select `godot/project.godot`.
3. Press **F5** (Run Project).

The look is a bright, top-down cartoon style: an island in the sea with a beach, palms and round leafy
trees, a cobblestone path, chunky outlined HUD numbers, and round play / fast-forward buttons.
The UI font is [Luckiest Guy](https://fonts.google.com/specimen/Luckiest+Guy) (Apache 2.0, see `fonts/`).

It uses the **Compatibility** renderer, so it can also be exported to Web, Android and iOS from
**Project → Export**.

## Controls

| Action | Mouse / keys | Touch |
|---|---|---|
| Pick a hero | Click a portrait, or **1–7** | Tap a portrait |
| Place it | Click on grass (**Shift**-click places another) | Tap on grass |
| Select a placed hero | Click it | Tap it |
| Upgrade paths 1/2/3 | Panel buttons, or **, . /** | Panel buttons |
| Change targeting | Target button, or **Tab** | Target button |
| Sell | Sell button, or **Delete** | Sell button |
| Start round / change speed | **START** button, or **Space** | START button |
| Cancel | **Esc** or right-click | |
| Camera | Left-drag rotates, right-drag pans, wheel zooms | Drag rotates |

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

To change the route, edit `ROUTE` in `scripts/track/track.gd`. Consecutive waypoints must share a row or a
column, and the first and last points are the entry and exit just outside the tiled area.
`validate()` reports any route that leaves a gap, reuses a cell, or runs two separate stretches side by side.
Spirits follow the centre line with slightly rounded 90° corners.

## Code layout

| File | What it does |
|---|---|
| `main.tscn` | One node running `scripts/main.gd` (instances the Level) |
| `scripts/main.gd` | Game loop: path, map, spirits, heroes, projectiles, rounds, camera, input |
| `scripts/defs.gd` | All game data: spirit types, 7 heroes and their 3×4 upgrade trees, balance numbers |
| `scripts/models.gd` | Builds every 3D model from primitive meshes, with toon shading and ink outlines |
| `scripts/ui.gd` | HUD, hero shop (3D-rendered portraits), upgrade panel, boss bar, menus |
| `scripts/sfx.gd` | Synthesizes all sound effects in code at startup |

To rebalance or add upgrades, edit `scripts/defs.gd`. In each upgrade's effect dictionary, `"key": n` adds,
`"key*": n` multiplies and `"key=": v` sets. Dotted keys such as `"explode.r"` reach into nested stats.
