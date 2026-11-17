# Gravity Dash (Godot)

A one-button runner for **Godot 4.3+**. Your cube runs forward on its own. You can't jump: click, tap or press
Space to flip gravity, and the cube falls to the ceiling or back to the floor. Everything (levels, art, icons,
music and sound effects) is generated from code. The only asset file is the Fredoka font.

## Opening it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build, not .NET).
2. In the Project Manager, click **Import** and select `gravity-dash-godot/project.godot`.
3. Press **F5**.

It uses the Compatibility renderer, so it also exports to Web, Android and iOS.

## Controls

| | |
|---|---|
| Flip gravity | Left click, tap, Space, W/S or Up/Down |
| Pause / resume | Esc or P, or the pause button |
| Restart the level | R |
| Level select | Left/Right arrows, Enter to play |

You can only flip while touching a surface. A press slightly early or just after leaving an edge still counts.

## What's in it

- **Main menu**: Icon Kit on the left, a big Play button in the middle and Stats on the right, with a cube
  flipping along the floor behind them and the colours slowly cycling. Music and sound toggles sit bottom left.
- **Level select**: one big card per level with a difficulty face (Easy, Normal, Hard, Harder, Insane, Demon),
  stars, your best % on a Normal Mode bar, attempts and best time. Use the arrows to flip between levels.
- **18 levels**: the 3 from the browser version plus 15 new ones. New hazards are spinning saws, staircases and
  "switch" sections where you ride a block on the floor and then one on the ceiling.
- **Level complete**: the camera stops, the cube spins into the finish gate and bursts, the screen flashes,
  fireworks go off and **LEVEL COMPLETE!** slams in letter by letter. A results panel then drops in with your
  attempts, flips, time, stars earned and anything you unlocked.
- **Music**: every level has its own looping song, synthesised at start-up from the level's tempo, key and
  scale. Harder levels get busier drums. The scenery pulses on the beat. The song restarts on every attempt.
- **Skins**: 16 cube icons and 16 colours, each usable as the main or second colour. Most are unlocked by
  playing: flips, attempts, crashes, stars, levels completed, or beating a level on its first attempt.
- **Statistics**: attempts, flips, crashes, levels and stars, first-try clears, time played, distance,
  flips per attempt and unlocks, plus a per-level list of best %, tries and completion.

Progress is saved to `user://gravity_dash_save.json`.

## Difficulty

This version is **1.964739957393× harder** than the browser prototype. The constant `DIFFICULTY` in
`scripts/levels.gd` divides every reaction window (the gap between hazards) by that number, so you get about
half the time to react. Levels are also faster and longer as you go up the list.

Every level is built from a seed, and `tools/check_levels.gd` runs a search bot over each one to prove it
can be finished:

```
godot --headless --path gravity-dash-godot -s res://tools/check_levels.gd
```

`tools/tour.gd` clicks through every screen, plays a level to the end with the bot's recorded inputs and
saves screenshots (it needs a display, for example `xvfb-run`):

```
xvfb-run godot --path gravity-dash-godot -s res://tools/tour.gd -- /tmp/shots 0
```

## Files

| | |
|---|---|
| `scripts/main.gd` | Screens: menu, level select, icon kit, stats, pause and results |
| `scripts/world.gd` | Draws and runs a level, the death burst and the win animation |
| `scripts/sim.gd` | Fixed-step physics (120 Hz) and the solver bot |
| `scripts/levels.gd` | Level list and the chunk-based generator |
| `scripts/skins.gd` | Icons, colours, unlock rules and difficulty faces |
| `scripts/synth.gd`, `scripts/audio.gd` | Music and sound synthesis and playback |
| `scripts/save.gd` | Save data and statistics |
| `scripts/ui/` | Buttons, the logo, level card, icon tiles and small widgets |

The font is [Fredoka](https://fonts.google.com/specimen/Fredoka) under the SIL Open Font License (`fonts/FREDOKA-OFL.txt`).
