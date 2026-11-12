# Sakura Spirit Defense 🌸

A 3D anime-style tower defense game for the browser, built with [Three.js](https://threejs.org/).
Restless spirits are marching on an old mountain shrine. Recruit a squad of chibi heroes, upgrade them along
branching paths, and hold the gate for 40 rounds (then keep going in freeplay).

## Two versions

- **Repository root**: the Godot 4.3+ project (GDScript). Open `project.godot` in Godot or Xogot and press Play.
  See the [main README](../README.md).
- **`web/`** (this folder): the original browser version (Three.js), described below.

## Running the browser version

There's no build step. Three.js is vendored in `vendor/`, so the game works offline. Serve this `web/` folder with
any static file server and open it in a browser:

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

(Opening `index.html` straight from disk won't work, because browsers block ES modules on `file://` URLs.)

## How to play

- Pick a hero from the panel on the right (or press **1–7**), then click a grass tile to place them. Hold **Shift** to place several.
- Press **START** (or **Space**) to send the next round. Press it again during a round to cycle **x1 / x2 / x3** speed.
- **AUTO** starts the next round automatically.
- Click a hero to open its panel: buy upgrades, change targeting (**First / Last / Strong / Close**), or sell for 70% back.
- Keyboard shortcuts: **, . /** buy upgrades on paths 1/2/3, **Tab** cycles targeting, **Delete** sells, **Esc** cancels.
- Drag to rotate the camera, and use the wheel or a pinch to zoom.

### Upgrades

Each hero has 3 upgrade paths with 4 tiers. You can upgrade **two** paths, and only **one** of them past tier 2.

### Heroes

| # | Hero | Role | Notes |
|---|------|------|-------|
| 1 | Kaede | Kunoichi | Fast shuriken. Sees veiled spirits from the start. |
| 2 | Hana | Shrine Maiden | Long-range sacred arrows. Paths for damage, arrow rain, or stun/slow talismans. |
| 3 | Rin | Blast Mage | Exploding fireballs. Can't hurt **Shadow** wisps. Late upgrades shred bosses. |
| 4 | Yuki | Ice Princess | Freezes spirits around her. **Frost** wisps are immune until *Frostbreaker*. |
| 5 | Takeshi | Samurai | Close-range sweeping slashes, plus flying wind blades later. |
| 6 | Mika | Mecha Pilot | Rapid piercing energy beam, homing missiles, and map-wide range. |
| 7 | Aiko | Pop Idol | Earns cash each round and buffs nearby heroes. Can also attack with sound waves. |

### Spirits

Spirits are layered: popping one reveals the weaker spirit inside it.

Pink → Blue → Green → Gold → Violet → **Shadow** (blast-immune) / **Frost** (freeze-immune) → **Prism** → **Clay Mask** (10 HP)
→ **Oni Lord** boss (round 25+) → **Storm Dragon** boss (round 40).

Spirits with leafy markings are **veiled**. Only heroes with detection can target them. Any spirit that reaches the
shrine costs lives equal to every layer still inside it.

## Files

- `index.html`: page layout and HUD
- `style.css`: UI styling
- `game.js`: the whole game (map, models, enemies, heroes, upgrades, rounds, UI)
- `vendor/`: Three.js r160 and OrbitControls (MIT license, see `vendor/THREE_LICENSE`)
