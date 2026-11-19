# Sunset Shores

An original open-world driving and action sandbox for **Godot 4.3+**, written entirely in GDScript.
Everything is generated from code: the city, cars, people, sky, ocean, sound effects and the radio music.
There are no image, model or audio files.

You arrive in Sunset Shores, a palm-lined coastal city, with $500 and a pistol. Steal cars, run jobs for
three local contacts, and keep one step ahead of the police.

## Opening it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build, not .NET).
2. In the Project Manager, click **Import** and pick `sunset_shores/project.godot`.
3. Press **F5**.

It uses the **Forward+** renderer for shadows, fog, glow and SSAO, so it needs a GPU with Vulkan support.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / drive | WASD or arrow keys | Left stick, RT/LT for throttle and brake |
| Look | Mouse | Right stick |
| Sprint | Shift | Left stick click |
| Jump / handbrake | Space | A |
| Enter, exit or steal a car | F | Y |
| Shoot (also from a car) | Left click | RB |
| Aim | Right click | LB |
| Switch weapon | Q or mouse wheel | D-pad right |
| Flip car upright | R | D-pad up |
| Horn | H | Right stick click |
| Radio on/off | T | D-pad left |
| Full map | M | Back |
| Pause | Esc or P | Start |

## What's in it

- **The city:** an 8×8 grid of blocks about 650 m across. Downtown glass towers sit in the middle,
  with midtown shops and neon signs around them, pastel houses with pools and palms in the residential
  streets, and a strip of beachfront hotels. There are also two parks with fountains, two parking lots,
  a hospital and a police station. The west side has a beach with umbrellas, lifeguard towers and
  stunt ramps, and an animated ocean.
- **Day and night:** a full day lasts 16 minutes. Sunsets happen over the ocean. After dark, windows
  light up at random, neon signs and street lamps glow, and car headlights come on.
- **Cars:** eight vehicle types (Corsa sedan, Pip compact, Marlin GT sports car, Ranger SUV, Duna pickup,
  Mule van, Cab taxi and the police Cruiser), each with its own speed, grip, weight and toughness. The
  handling is arcade-style, with raycast suspension, grip that runs out (hold the handbrake to drift),
  and damage. A damaged car smokes, then catches fire, then explodes.
- **Traffic:** cars drive their lanes on the right, turn at intersections, queue behind each other,
  stop for pedestrians and honk if you stand in the road. A car becomes a real physics object when
  you steal it or ram it.
- **Pedestrians** walk the sidewalks and cross the streets. They run from gunfire and can be knocked
  down.
- **Wanted level (1 to 5 stars):** crimes seen by witnesses or police raise your heat. Police cars chase
  you along the roads and ram you, officers get out and shoot (from 2 stars), and they bust you if they
  catch you standing still. To lose them, stay out of sight until the stars stop flashing, or pay $250 at
  the **Respray** garage.
- **Wasted / Busted:** you wake up at the hospital or the police station, minus some cash.
- **Missions:** six story jobs from Rosa, Dex and Lena:
  1. *First Wheels*: steal a car and deliver it against the clock.
  2. *Sunset Sprint*: an 8-checkpoint street race.
  3. *Hot Package*: pick up a package, lose the cops, then deliver it.
  4. *Scrap Run*: wreck three vans.
  5. *The Collector*: take out a target who has bodyguards.
  6. *Night Run*: a harder 12-checkpoint race.

  After the story, freelance jobs keep coming, with rising rewards.
- **Pickups:** cash, health, body armour and an SMG.
- **HUD:** a rotating minimap that zooms out as you speed up, a full map, money, clock, stars, health
  and armour, speedometer, and mission timers.
- **Audio:** gunshots, crashes, explosions, horn, sirens, a live engine note that follows your speed,
  and *Palm FM*, an original synthwave loop that plays while you drive.

## Code layout

| File | What it does |
|---|---|
| `scripts/game.gd` | Entry point. Builds the world and owns money, time of day, crime, explosions, wasted/busted and the respray |
| `scripts/city.gd` | City generator: roads, districts, buildings, beach, ocean, props, street lights, spawn points |
| `scripts/car.gd` | Vehicle physics (raycast suspension, tyre grip, drift, damage, fire, explosions) and models |
| `scripts/traffic.gd` | Lane-following traffic on rails, parked cars, carjacking |
| `scripts/ped.gd`, `scripts/peds.gd` | Pedestrians, officers and bodyguards, plus spawning and being hit by cars |
| `scripts/player.gd` | On-foot movement, curb step-up, weapons, getting in and out of cars |
| `scripts/police.gd` | Wanted level, police AI on the road grid, busting, losing the cops |
| `scripts/missions.gd` | Mission contacts, story missions and freelance jobs |
| `scripts/hud.gd` | HUD, minimap, full map, pause menu and title screen |
| `scripts/sfx.gd` | Synthesised sound effects, engine sound and the radio loop |
| `scripts/camera_rig.gd` | Third-person orbit and chase camera |
| `scripts/humanoid.gd` | Blocky animated people |
| `scripts/fx.gd`, `scripts/pickups.gd`, `scripts/util.gd` | Effects and markers, pickups, mesh and material helpers |
| `shaders/` | Building windows, ocean, and the sky with sun, clouds and stars |

## Tests

```bash
godot --headless --path . -s tests/smoke_test.gd                     # 53 checks: driving, police, missions...
xvfb-run godot --path . -s tests/screenshots.gd -- /tmp/shots [shot] # real screenshots
```

The smoke test plays the game headlessly. It walks onto curbs, steals and drives cars, shoots,
gets a wanted level, chases and dies, completes two missions, blows up cars, and runs a minute of
traffic.
