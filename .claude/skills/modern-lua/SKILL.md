---
name: modern-lua
description: When writing or editing Lua or Luau (Roblox) code, use current APIs and syntax instead of deprecated or legacy ones, which are buggier and less supported. Use for any .lua/.luau file, Roblox script, or when the user says "modern lua", "no deprecated code", or "/modern-lua".
---

# Modern Lua

Always write the newest supported form. When touching existing code, replace legacy calls in the lines you change (don't rewrite untouched files unless asked).

## 1. Identify the target first
- **Roblox / Luau** (`.luau`, `game:GetService`, `script.Parent`, `default.project.json`, `wally.toml`) → use sections 2–3.
- **Plain Lua** → check the version (`lua -v`, LÖVE = LuaJIT/5.1, Defold = LuaJIT, Neovim = LuaJIT) and use section 4 only as far as that version allows.
- If unsure about an API's status, check the official docs (create.roblox.com/docs, lua.org/manual) with one quick search instead of guessing.

## 2. Roblox: replace deprecated APIs

| Old (don't use) | New (use) |
|---|---|
| `wait()`, `spawn()`, `delay()` | `task.wait()`, `task.spawn()`, `task.delay()`, `task.defer()` |
| `:connect()`, `:wait()`, `:disconnect()` | `:Connect()`, `:Wait()`, `:Disconnect()`; `:Once()` for one-shot |
| `:findFirstChild`, `:children()`, `:Remove()` | `:FindFirstChild`, `:GetChildren()`, `:Destroy()` |
| `Instance.new("Part", parent)` | `Instance.new("Part")`, set properties, then set `.Parent` last |
| `Ray.new` + `FindPartOnRay*` | `workspace:Raycast(origin, dir, RaycastParams.new())` |
| `SetPrimaryPartCFrame` / `GetPrimaryPartCFrame` | `Model:PivotTo()` / `Model:GetPivot()` |
| `BodyVelocity`, `BodyGyro`, `BodyPosition`, `BodyAngularVelocity`, `BodyForce` | `LinearVelocity`, `AlignOrientation`, `AlignPosition`, `AngularVelocity`, `VectorForce` (with `Attachment`) |
| `Humanoid:LoadAnimation()` | `Humanoid.Animator:LoadAnimation()` |
| `Player:GetMouse()` / `Mouse` | `UserInputService`, `ContextActionService` |
| Manual lerp loops for UI/parts | `TweenService` |
| Legacy chat (`Chat`, `ChatService`) | `TextChatService` |
| `Message` / `Hint` instances | `ScreenGui` + `TextLabel` |
| `game.Players`, `game.Workspace` | `game:GetService("Players")`, `workspace` |
| `DataStore:SetAsync` for read-modify-write | `UpdateAsync`, wrapped in `pcall` |
| `RenderStepped` for non-camera logic | `Heartbeat` / `PreSimulation`; `BindToRenderStep` only for camera/input |
| `FilteringEnabled` assumptions, client trust | Validate everything server-side in `RemoteEvent` handlers |

## 3. Luau syntax to prefer
- `--!strict` at the top of new scripts, with type annotations: `local function f(x: number): string`.
- Compound assignment: `x += 1`, `s ..= "a"`.
- String interpolation: `` `Score: {score}` `` instead of `..` chains or `string.format` for simple cases.
- `continue` in loops instead of `goto`/nested ifs.
- Generalized iteration: `for k, v in t do` (no `pairs`/`ipairs` needed).
- `if a then b else c` expressions instead of `a and b or c` (which breaks when `b` is falsy).
- `table.clone`, `table.find`, `table.clear`, `table.freeze` instead of hand-written loops.
- `buffer` for binary data instead of string packing.
- `math.clamp`, `math.round`, `math.sign` instead of hand-rolled versions.

## 4. Plain Lua: legacy → modern

| Old | New |
|---|---|
| `table.getn(t)`, `table.setn` | `#t` |
| `unpack(t)` | `table.unpack(t)` (5.2+) |
| `math.pow(a, b)`, `math.mod` | `a ^ b`, `a % b` (5.0+); `a // b` integer division (5.3+) |
| `bit32.*` / LuaBitOp | `&`, `|`, `~`, `<<`, `>>` (5.3+) |
| `setfenv` / `getfenv` | `_ENV` (5.2+) |
| `module(...)` | `local M = {} ... return M` |
| `loadstring` | `load` (5.2+) |
| `string.gfind` | `string.gmatch` |
| Globals | `local` everywhere; `<const>` / `<close>` locals (5.4) |

## 5. Before finishing
- Grep your changes for old names: `grep -nE '\b(wait|spawn|delay)\(|:connect\(|Ray\.new|FindPartOnRay|SetPrimaryPartCFrame|Body(Velocity|Gyro|Position|Force)|table\.getn|loadstring|setfenv' <files>`. Treat hits as legacy unless they're clearly a method on your own object (e.g. `myThing:wait()`).
- Run any linter the project has (`selene`, `luau-lsp analyze`, `luacheck`, `stylua --check`) once.
- Report in one line which legacy calls were replaced.
