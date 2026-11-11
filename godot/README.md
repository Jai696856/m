# Sakura Spirit Defense: Godot version

The same 3D anime tower defense game, rebuilt as a **Godot 4.3+** project in GDScript.
Everything (map, cel-shaded chibi heroes, spirits, effects, sounds and UI) is generated from code, so the
project has no imported art or audio assets.

## Opening it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build, not .NET).
2. In the Project Manager, click **Import** and select `godot/project.godot`.
3. Press **F5** (Run Project).

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

## Code layout

| File | What it does |
|---|---|
| `main.tscn` | One node running `scripts/main.gd` |
| `scripts/main.gd` | Game loop: path, map, spirits, heroes, projectiles, rounds, camera, input |
| `scripts/defs.gd` | All game data: spirit types, 7 heroes and their 3×4 upgrade trees, balance numbers |
| `scripts/models.gd` | Builds every 3D model from primitive meshes, with toon shading and ink outlines |
| `scripts/ui.gd` | HUD, hero shop (3D-rendered portraits), upgrade panel, boss bar, menus |
| `scripts/sfx.gd` | Synthesizes all sound effects in code at startup |

To rebalance or add upgrades, edit `scripts/defs.gd`. In each upgrade's effect dictionary, `"key": n` adds,
`"key*": n` multiplies and `"key=": v` sets. Dotted keys such as `"explode.r"` reach into nested stats.
