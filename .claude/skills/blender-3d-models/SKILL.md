---
name: blender-3d-models
description: For 3D games, research modeling guides online, then build the models in Blender (headless, via Python/bpy), render previews to check them, and export to the game engine. Use automatically whenever a 3D game needs a model, prop, character, environment, or asset, instead of placeholder primitives.
---

# Blender 3D Models

Goal: learn how the asset is usually modeled, build it in Blender with a script, look at it, fix it, and export it game-ready. Keep it cheap.

## 1. Pin the asset
One line: what it is, style (low-poly, stylized, realistic), and target engine. Detect the engine from the repo (`project.godot` = Godot → glTF `.glb`; Roblox → `.fbx`/`.obj`; Unity → `.fbx`; three.js/web → `.glb`). Check the repo for existing art (palette, scale, poly style) and match it.

## 2. Research (2–4 searches, one batch)
Use WebSearch `mode: "standard"`:
- `how to model <thing> in blender low poly` (or the chosen style)
- `blender python bpy <technique>` (e.g. bevel, array, curve, boolean, UV unwrap)
- `<thing> game asset topology` / `<engine> import blender glb best practices`
Open at most 2 pages. Note the modeling steps (blockout → shapes → modifiers → materials) and the right real-world proportions. Don't copy assets or recreate a specific existing game's models.

## 3. Get Blender (once per session)
Check: `which blender || python3 -c "import bpy"`. If missing, try in order and stop at the first that works:
1. `pip install bpy` (needs a Python version bpy supports; use `uv`/a venv with that Python if needed)
2. `apt-get install -y blender`
3. Download the Linux tarball from download.blender.org, extract to the scratchpad, run `./blender -b`
If all fail, say so and fall back to writing the bpy script for the user to run in their Blender (Scripting tab).

## 4. Build with a script
Write `tools/blender/<asset>.py` (or the scratchpad if the user doesn't want it in the repo) and run headless:
`blender -b -P tools/blender/<asset>.py` (or `python3 tools/blender/<asset>.py` with the bpy module).

Script rules:
- Start from an empty scene: `bpy.ops.wm.read_factory_settings(use_empty=True)`.
- Use real scale: 1 unit = 1 m; origin at the base/pivot point; facing -Y (Blender front) so it imports facing forward.
- Build from primitives + modifiers (Mirror, Bevel, Array, Solidify, Subdivision for stylized), then apply modifiers before export.
- Name objects and materials clearly. Use simple Principled BSDF materials or vertex colors; keep texture count low.
- Keep poly count sensible (props: a few hundred to ~5k tris; characters: ~5–20k). Recalculate normals; shade flat for low-poly, smooth + auto smooth otherwise.
- Make functions with parameters (size, color, segments) so variants are cheap.

## 5. Check it (required)
Render preview PNGs from 2–3 angles with Eevee/Workbench at low resolution (e.g. 512×512), then look at them with Read. Fix proportions, gaps, flipped normals, or floating parts, and re-render. Max 3 iterations unless the user wants more. Also print stats: object count, tri count, dimensions.

## 6. Export
- Godot / web: `bpy.ops.export_scene.gltf(filepath=".../<asset>.glb", export_format='GLB', export_apply=True)`.
- Unity / Roblox: `bpy.ops.export_scene.fbx(..., apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)`; use `.obj` if FBX is a problem in Roblox.
Put it in the project's art folder (e.g. `art/models/`). For Godot, place it in a scene only if the user asked.

## 7. Report briefly
Preview image (send with SendUserFile), file paths, tri count, and one line on what you learned from the guides. Ask if they want changes. Commit the script with the model so it can be regenerated.

## Token discipline
- ≤4 searches, ≤2 page reads, ≤3 render-fix loops.
- Render small previews; don't read huge logs (pipe Blender output through `tail -20`).
- Follow the `lean-code` skill for the scripts.
