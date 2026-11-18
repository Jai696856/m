extends RefCounted
## Level definitions and the chunk-based generator.
## Every level is described by a small parameter dictionary and built from its seed, so a level is identical
## on every run. build_verified() also runs the solver bot, re-rolls the layout until it can be finished,
## and places the secret coins and shards on the bot's winning route.

const Sim = preload("res://scripts/sim.gd")

## How much harder this game is than the browser prototype:
## every reaction window (the time you get between hazards) is divided by this number.
const DIFFICULTY := 1.964739957393

const CEIL := 40.0
const FLOOR := 360.0
const T := 40.0
const START_X := 720.0
const LONG := ["bar", "ride", "switch", "steps", "orbrun", "squeeze"]
const ALL_MECH := ["saw", "orb", "pad", "portal", "speed", "mini"]

const TIER_SPEED := [390.0, 430.0, 470.0, 500.0, 530.0, 560.0]
const TIER_M := [1.25, 1.05, 0.92, 0.86, 0.8, 0.74]
const TIER_CHUNKS := [22, 26, 30, 34, 38, 42]
const TIER_BPM := [118, 126, 134, 142, 148, 156]
const TIER_STARS := [1, 2, 3, 5, 7, 10]
const SCALES := [[0, 3, 5, 7, 10], [0, 2, 4, 7, 9], [0, 2, 3, 5, 7, 8, 10], [0, 2, 3, 5, 7, 9, 10],
	[0, 1, 3, 5, 7, 8, 10], [0, 2, 3, 5, 7, 8, 11], [0, 2, 4, 5, 7, 9, 11]]

## name, tier, stars, speed, chunks, m, seed, hue, bpm, root, scale, mechanics
const MAIN := [
	["Lift Off", 0, 1, 380, 22, 1.3, 7, 0.72, 120, 45, 0, ""],
	["Polar Shift", 0, 1, 390, 24, 1.25, 211, 0.58, 118, 43, 1, ""],
	["Double Back", 1, 2, 440, 28, 1.05, 23, 0.55, 132, 38, 2, "pad"],
	["Upside Town", 1, 2, 420, 26, 1.12, 307, 0.9, 126, 40, 6, "pad"],
	["Orb Garden", 1, 2, 420, 26, 1.1, 1801, 0.33, 124, 43, 1, "orb"],
	["Neon Gravity", 1, 2, 440, 28, 1.05, 419, 0.78, 128, 45, 3, "portal"],
	["Bounce Castle", 1, 3, 430, 28, 1.05, 1907, 0.12, 130, 40, 6, "pad,portal"],
	["Hard Ceiling", 2, 3, 500, 34, 0.88, 101, 0.95, 144, 42, 4, "saw"],
	["Saw Mill", 2, 3, 450, 30, 1.0, 523, 0.08, 136, 41, 2, "saw"],
	["Tiny Planet", 2, 3, 450, 28, 1.0, 2003, 0.5, 134, 45, 0, "mini,saw"],
	["Flipside", 2, 4, 470, 30, 0.95, 631, 0.45, 138, 44, 5, "saw,portal"],
	["Turbo Lane", 2, 4, 470, 30, 0.95, 2111, 0.15, 150, 42, 3, "speed,pad"],
	["Static Drift", 3, 5, 480, 32, 0.92, 733, 0.66, 140, 39, 4, "saw,pad,speed"],
	["Copper Sky", 3, 5, 480, 32, 0.92, 2213, 0.07, 138, 41, 2, "saw,orb,mini"],
	["Zero G", 3, 6, 490, 34, 0.9, 839, 0.53, 140, 46, 0, "orb,saw"],
	["Pendulum", 3, 6, 500, 34, 0.88, 941, 0.02, 142, 40, 5, "orb,pad,portal"],
	["Glass Reactor", 3, 6, 500, 34, 0.88, 2309, 0.48, 144, 44, 5, "orb,portal,speed"],
	["Overturn", 4, 7, 520, 36, 0.85, 1049, 0.8, 146, 43, 3, "saw,orb,portal,speed"],
	["Midnight Signal", 4, 7, 520, 36, 0.85, 2417, 0.7, 146, 39, 4, "saw,pad,mini,speed"],
	["Magnetar", 4, 8, 530, 38, 0.82, 1153, 0.63, 148, 38, 2, "orb,pad,speed"],
	["Inversion", 4, 8, 540, 38, 0.8, 1259, 0.35, 150, 45, 4, "saw,orb,portal,mini"],
	["Hyperloop", 4, 8, 540, 38, 0.8, 2521, 0.56, 156, 46, 3, "speed,orb,portal"],
	["Event Horizon", 4, 9, 550, 40, 0.78, 1361, 0.04, 152, 41, 5, "saw,orb,pad,portal,speed"],
	["Pixel Storm", 4, 9, 550, 40, 0.78, 2633, 0.86, 150, 43, 0, "all"],
	["Antimatter", 5, 10, 560, 42, 0.75, 1471, 0.76, 155, 44, 4, "saw,orb,pad,portal,speed,mini"],
	["Singularity", 5, 10, 570, 44, 0.72, 1579, 0.68, 158, 39, 5, "all"],
	["Nullspace", 5, 10, 565, 42, 0.74, 2729, 0.74, 154, 40, 4, "all"],
	["Gravity's End", 5, 10, 580, 46, 0.7, 1693, 0.97, 160, 42, 4, "all"],
	["Apex Inverter", 5, 10, 575, 44, 0.72, 2833, 0.92, 158, 38, 5, "all"],
	["Final Fall", 5, 10, 590, 48, 0.68, 2939, 0.0, 162, 42, 4, "all"],
]

const TRIALS := [
	{"name": "Saw Trial", "mech": "saw", "hue": 0.04, "tier": 3, "stars": 25, "levels": ["Rust Teeth", "Grinder", "Red Cut"]},
	{"name": "Orb Trial", "mech": "orb", "hue": 0.6, "tier": 3, "stars": 45, "levels": ["Bubble Run", "Orbit Lock", "Halo"]},
	{"name": "Speed Trial", "mech": "speed,pad", "hue": 0.13, "tier": 4, "stars": 70, "levels": ["Afterburn", "Redline", "Overdrive"]},
	{"name": "Tiny Trial", "mech": "mini,saw,orb", "hue": 0.84, "tier": 4, "stars": 100, "levels": ["Small Talk", "Needle", "Micro Fall"]},
]

const FEATURED := [
	["Sugar Rush", 1, 0.93, "pad"], ["Deep Freeze", 2, 0.55, "saw,orb"], ["Brass Engine", 2, 0.09, "speed,saw"],
	["Night Market", 3, 0.75, "pad,portal"], ["Coral Drift", 3, 0.47, "orb,mini"], ["Thunderhead", 4, 0.62, "all"],
	["Lantern Path", 1, 0.1, "orb"], ["Black Hole Sun", 5, 0.02, "all"],
]

## Packs of main levels. Beat every level in a pack for its reward.
const PACKS := [
	{"name": "Starter Pack", "levels": [0, 1, 2, 3], "shards": 150, "hue": 0.55},
	{"name": "Bounce Pack", "levels": [4, 5, 6], "shards": 200, "hue": 0.12},
	{"name": "Blade Pack", "levels": [7, 8, 10], "shards": 300, "hue": 0.02},
	{"name": "Velocity Pack", "levels": [11, 12, 16], "shards": 400, "hue": 0.15},
	{"name": "Orbit Pack", "levels": [14, 15, 19], "shards": 500, "hue": 0.6},
	{"name": "Dark Pack", "levels": [24, 25, 26], "shards": 900, "hue": 0.78},
]

## The first layout attempt that the solver can finish, per fixed level (filled in by tools/check_levels.gd --offsets).
## Only a speed-up: build_verified() still checks and keeps searching if a layout changes.
const OFFSETS := {"main:antimatter": 1, "main:final-fall": 1, "trial:2:2": 1}

const WORDS_A := ["Neon", "Pulse", "Hyper", "Velvet", "Echo", "Prism", "Quantum", "Lunar", "Solar", "Crystal",
	"Shadow", "Nova", "Glitch", "Cobalt", "Ember", "Frost", "Zenith", "Orbit", "Paper", "Rocket"]
const WORDS_B := ["Drift", "Rush", "Spiral", "Circuit", "Cascade", "Riot", "Tunnel", "Mirage", "Vortex", "Garden",
	"Highway", "Reactor", "Canyon", "Skyline", "Engine", "Fever", "Breaker", "Run", "Shift", "Storm"]


# ---------- Parameters for each kind of level ----------

static func slug(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	return out


static func hash_seed(s: String) -> int:
	return absi(hash(s)) % 9000000 + 1000


static func make(key: String, name: String, tier: int, seed: int, hue: float, mech: String, extra := {}) -> Dictionary:
	var p := {
		"key": key, "name": name, "tier": tier, "stars": TIER_STARS[tier], "speed": TIER_SPEED[tier],
		"chunks": TIER_CHUNKS[tier], "m": TIER_M[tier], "seed": seed, "hue": hue, "bpm": TIER_BPM[tier],
		"root": 38 + seed % 9, "scale": SCALES[seed % SCALES.size()], "mech": mech, "genre": seed % 6,
	}
	p.merge(extra, true)
	return p


static func main_count() -> int:
	return MAIN.size()


static func main_params(i: int) -> Dictionary:
	var r: Array = MAIN[i]
	return make("main:" + slug(r[0]), r[0], r[1], r[6], r[7], r[11], {
		"stars": r[2], "speed": float(r[3]), "chunks": r[4], "m": r[5], "bpm": r[8], "root": r[9],
		"scale": SCALES[r[10]], "genre": (i * 7 + r[1]) % 6, "index": i})


static func total_stars() -> int:
	var n := 0
	for r in MAIN:
		n += int(r[2])
	return n


static func word_name(seed: int) -> String:
	return WORDS_A[seed % WORDS_A.size()] + " " + WORDS_B[(seed / 7) % WORDS_B.size()]


static func daily_params(date: String) -> Dictionary:
	var sd := hash_seed("daily" + date)
	var tier := 1 + sd % 4
	return make("daily:" + date, word_name(sd), tier, sd, fposmod(sd * 0.137, 1.0), ",".join(ALL_MECH.slice(0, 2 + sd % 4)), {"kind": "daily"})


static func weekly_params(week: String) -> Dictionary:
	var sd := hash_seed("weekly" + week)
	return make("weekly:" + week, word_name(sd), 4 + sd % 2, sd, fposmod(sd * 0.071, 1.0), "all", {"kind": "weekly"})


static func event_params(week: String) -> Dictionary:
	var sd := hash_seed("event" + week)
	return make("event:" + week, "Gravity Rush", 3, sd, fposmod(sd * 0.29, 1.0), "speed,pad,orb,portal",
		{"chunks": 60, "kind": "event", "rush": true})


static func trial_params(t: int, j: int) -> Dictionary:
	var tr: Dictionary = TRIALS[t]
	var name: String = tr.levels[j]
	return make("trial:%d:%d" % [t, j], name, int(tr.tier) + (1 if j == 2 else 0), hash_seed(name), float(tr.hue) + j * 0.03, tr.mech,
		{"kind": "trial", "chunks": 24 + j * 4})


static func featured_params(i: int) -> Dictionary:
	var r: Array = FEATURED[i]
	return make("featured:" + slug(r[0]), r[0], r[1], hash_seed(r[0]), r[2], r[3], {"kind": "featured"})


static func search_params(text: String, tier: int) -> Dictionary:
	var sd := hash_seed(text.to_lower().strip_edges() + str(tier))
	return make("search:%s:%d" % [slug(text), tier], text.strip_edges().capitalize(), tier, sd, fposmod(sd * 0.113, 1.0),
		",".join(ALL_MECH.slice(0, mini(6, tier + 1))), {"kind": "search"})


## The Forge: a level built from settings the player picks.
static func forge_params(f: Dictionary) -> Dictionary:
	var tier := int(f.tier)
	var lengths := [0.6, 1.0, 1.5]
	var speeds := [0.88, 1.0, 1.12]
	return make("forge:%d" % int(f.seed), str(f.name), tier, int(f.seed), fposmod(int(f.seed) * 0.0917, 1.0), ",".join(f.mech), {
		"chunks": int(TIER_CHUNKS[tier] * float(lengths[int(f.length)])), "speed": TIER_SPEED[tier] * float(speeds[int(f.pace)]),
		"kind": "forge"})


static func palette(hue: float, shift := 0.0) -> Dictionary:
	var h := fposmod(hue + shift, 1.0)
	return {
		"sky_a": Color.from_hsv(h, 0.72, 0.2), "sky_b": Color.from_hsv(fposmod(h + 0.05, 1.0), 0.62, 0.42),
		"accent": Color.from_hsv(fposmod(h + 0.48, 1.0), 0.5, 1.0), "glow": Color.from_hsv(fposmod(h + 0.48, 1.0), 0.8, 1.0),
		"ground": Color.from_hsv(h, 0.6, 0.12), "hill": Color.from_hsv(fposmod(h + 0.03, 1.0), 0.55, 0.28),
	}


static func length_name(seconds: float) -> String:
	if seconds < 20.0:
		return "Short"
	if seconds < 35.0:
		return "Medium"
	if seconds < 55.0:
		return "Long"
	return "XL"


# ---------- Generator ----------

static func _mech(p: Dictionary) -> Array:
	var s: String = p.mech
	if s == "all":
		return ALL_MECH.duplicate()
	var out := []
	for part in s.split(",", false):
		out.append(part.strip_edges())
	return out


static func build(p: Dictionary, seed_offset := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) + seed_offset * 7919
	var base_v: float = p.speed
	var v := base_v
	var m: float = p.m
	var tier: int = p.tier
	var mech := _mech(p)
	var o: Array = []
	var colors: Array = []
	var x := START_X
	var last := ""
	var pool := _pool(tier, mech)
	var mini := false
	var rush: bool = p.get("rush", false)
	for c in int(p.chunks):
		if rush and c > 0 and c % 10 == 0:
			v = base_v * (1.0 + c / 100.0)
			_special(o, x, 6, {"mul": v / base_v})
			x += T * 2.0
		elif c >= 3 and "speed" in mech and rng.randf() < 0.16:
			var muls := [0.85, 1.0, 1.15, 1.3]
			var mul: float = muls[rng.randi_range(0, mini(3, 1 + tier / 2))]
			if absf(mul * base_v - v) > 1.0:
				_special(o, x, 6, {"mul": mul})
				v = base_v * mul
				x += T * 2.0
		if c >= 3 and "mini" in mech and rng.randf() < 0.14:
			mini = not mini
			_special(o, x, 7, {"mini": mini})
			x += T * 2.0
		if c > 0 and c % 7 == 0:
			colors.append({"x": x, "shift": rng.randf_range(-0.14, 0.14)})
		var kind: String
		if c < 3:
			kind = ["floor", "ceil", "zig"][c]
		elif mini and rng.randf() < 0.3:
			kind = "squeeze"
		else:
			kind = pool[rng.randi_range(0, pool.size() - 1)]
			while kind == last and kind in LONG:
				kind = pool[rng.randi_range(0, pool.size() - 1)]
		last = kind
		x += _chunk(kind, x, o, rng, v, m, tier)
		x += _snap(v * 0.62 * m * (1.0 + rng.randf() * 0.3) / DIFFICULTY)
		if kind in LONG:
			x += T * 2.0
	if mini:
		_special(o, x, 7, {"mini": false})
		x += T * 2.0
	o.sort_custom(func(a, b): return a.x < b.x)
	var mw := 0.0
	for i in o.size():
		o[i]["id"] = i
		mw = maxf(mw, o[i].w)
	return {"key": p.key, "p": p, "objs": o, "colors": colors, "end": x + 300.0, "max_w": mw, "speed": base_v,
		"coins": [], "shards": [], "solution": []}


## Builds a level the solver can finish (re-rolling the layout if needed) and places coins and shards on the winning route.
static func build_verified(p: Dictionary) -> Dictionary:
	var lv: Dictionary = {}
	var first: int = OFFSETS.get(p.key, 0)
	for attempt in range(first, first + 12):
		lv = build(p, attempt)
		var r: Dictionary = Sim.solve(lv, 1500000)
		if r.ok:
			lv.solution = r.path
			lv["attempt"] = attempt
			_place_pickups(lv)
			lv["verified"] = true
			return lv
	lv["verified"] = false
	return lv


static func _place_pickups(lv: Dictionary) -> void:
	var press := {}
	for f in lv.solution:
		press[f] = true
	var s = Sim.State.new()
	var trace: Array = []
	while not s.won and not s.dead:
		Sim.step(s, lv, press.has(s.f))
		trace.append(Vector3(s.x + s.ps * 0.5, s.y + s.ps * 0.5, 0.0 if s.ground else 1.0))
	var n := trace.size()
	var coins: Array = []
	for frac in [0.28, 0.58, 0.86]:
		var i := int(n * float(frac))
		while i < n - 1 and trace[i].z < 0.5:
			i += 1
		coins.append(Vector2(trace[i].x, trace[i].y))
	var shards: Array = []
	for k in 16:
		var t: Vector3 = trace[int(n * (k + 0.5) / 16.0)]
		shards.append(Vector2(t.x, t.y))
	lv.coins = coins
	lv.shards = shards


static func _pool(tier: int, mech: Array) -> Array:
	var pool: Array
	match tier:
		0:
			pool = ["floor", "ceil", "floor", "ceil", "zig", "pillar", "pillar", "bar"]
		1:
			pool = ["floor", "ceil", "zig", "zig", "pillar", "pillar", "bar", "ride", "steps"]
		2:
			pool = ["floor", "ceil", "zig", "zig", "pillar", "bar", "ride", "steps"]
		3:
			pool = ["ceil", "zig", "zig", "pillar", "bar", "ride", "steps", "switch"]
		_:
			pool = ["floor", "zig", "zig", "zig", "pillar", "bar", "ride", "steps", "switch", "switch"]
	if "saw" in mech:
		pool.append_array(["sawzig", "sawzig"])
	if "orb" in mech:
		pool.append_array(["orbrun", "orbrun"])
	if "pad" in mech:
		pool.append_array(["padflip", "padflip"])
	if "portal" in mech:
		pool.append_array(["gportal", "gportal"])
	return pool


static func _snap(n: float) -> float:
	return ceilf(n / T) * T


static func _spike(o: Array, x: float, y: float, up: bool) -> void:
	o.append({"k": 1, "x": x, "y": y, "w": T, "h": T, "up": up})


static func _block(o: Array, x: float, y: float, w: float, h: float) -> void:
	o.append({"k": 0, "x": x, "y": y, "w": w, "h": h})


static func _saw(o: Array, cx: float, cy: float, r: float) -> void:
	o.append({"k": 2, "x": cx - r, "y": cy - r, "w": r * 2.0, "h": r * 2.0, "r": r, "cx": cx, "cy": cy})


static func _orb(o: Array, cx: float, cy: float) -> void:
	o.append({"k": 3, "x": cx - 14.0, "y": cy - 14.0, "w": 28.0, "h": 28.0, "r": 14.0, "cx": cx, "cy": cy})


static func _pad(o: Array, x: float, up: bool) -> void:
	o.append({"k": 4, "x": x, "y": (FLOOR - 6.0) if up else CEIL, "w": T, "h": 6.0, "up": up})


static func _special(o: Array, x: float, k: int, extra: Dictionary) -> void:
	var d := {"k": k, "x": x, "y": CEIL, "w": 16.0, "h": FLOOR - CEIL}
	d.merge(extra, true)
	o.append(d)


static func _chunk(kind: String, x: float, o: Array, rng: RandomNumberGenerator, v: float, m: float, tier: int) -> float:
	var inner := _snap(v * 0.55 * m / DIFFICULTY)
	var lead := _snap(v * 0.6 * maxf(1.0, m) / DIFFICULTY)
	match kind:
		"floor", "ceil":
			var n := rng.randi_range(1, mini(4, 2 + tier / 2))
			for i in n:
				if kind == "floor":
					_spike(o, x + i * T, FLOOR - T, true)
				else:
					_spike(o, x + i * T, CEIL, false)
			return n * T
		"zig", "sawzig":
			var groups := rng.randi_range(2, mini(7, 2 + tier))
			var n := rng.randi_range(1, mini(3, 1 + (tier + 1) / 2))
			var side := rng.randf() < 0.5
			var cx := 0.0
			for g in groups:
				for i in n:
					if side:
						_spike(o, x + cx + i * T, FLOOR - T, true)
					else:
						_spike(o, x + cx + i * T, CEIL, false)
				cx += n * T
				if g < groups - 1:
					var gap := inner
					if kind == "sawzig":
						gap += T
						_saw(o, x + cx + gap * 0.5, 200.0 + rng.randf_range(-30.0, 30.0), 20.0 + tier * 1.5)
					cx += gap
				side = not side
			return cx
		"pillar":
			var fl := rng.randf() < 0.5
			var h := rng.randi_range(2, 4)
			var w := rng.randi_range(1, mini(3, 1 + tier / 2))
			var top := tier >= 1 and rng.randf() < 0.5
			if fl:
				_block(o, x, FLOOR - h * T, w * T, h * T)
				if top:
					for i in w:
						_spike(o, x + i * T, FLOOR - h * T - T, true)
			else:
				_block(o, x, CEIL, w * T, h * T)
				if top:
					for i in w:
						_spike(o, x + i * T, CEIL + h * T, false)
			return w * T
		"steps":
			var fl := rng.randf() < 0.5
			var rising := rng.randf() < 0.5
			for i in 3:
				var h: int = (i + 1) if rising else (3 - i)
				if fl:
					_block(o, x + i * 2 * T, FLOOR - h * T, 2 * T, h * T)
				else:
					_block(o, x + i * 2 * T, CEIL, 2 * T, h * T)
			return 6 * T
		"bar":
			var length := lead + _snap(rng.randi_range(3, 6) * T) + T
			_block(o, x, 180.0, length, 40.0)
			var sx := x + lead
			while sx + T <= x + length - T:
				_spike(o, sx, FLOOR - T, true)
				_spike(o, sx, CEIL, false)
				sx += T
			return length
		"ride":
			return _ride(o, x, rng.randf() < 0.5, lead, rng)
		"switch":
			var fl := rng.randf() < 0.5
			var a := _ride(o, x, fl, lead, rng)
			var gap := _snap(v * 0.7 * m / DIFFICULTY) + T
			var b := _ride(o, x + a + gap, not fl, lead, rng)
			return a + gap + b
		"orbrun":
			# Both lanes are spiked: bounce through mid-air on the orbs. Orb positions come from simulating the bounce.
			var sx := x + lead + _snap(v * 0.3)
			var px := sx - v * 0.07
			var y := FLOOR - Sim.PS
			var g := -1.0
			var vy := g * Sim.KICK
			var placed := 0
			var want := rng.randi_range(2, mini(4, 2 + tier / 2))
			var hi := 120.0 + rng.randf_range(-10.0, 10.0)
			var lo := 280.0 + rng.randf_range(-10.0, 10.0)
			var land := sx
			for step in 600:
				vy = clampf(vy + g * Sim.G * Sim.DT, -Sim.VMAX, Sim.VMAX)
				y += vy * Sim.DT
				px += v * Sim.DT
				var cy := y + Sim.PS * 0.5
				if placed < want and ((g < 0.0 and cy <= hi) or (g > 0.0 and cy >= lo)):
					_orb(o, px + Sim.PS * 0.5, cy)
					placed += 1
					g = -g
					vy = g * Sim.KICK * 1.6
				if y <= CEIL or y + Sim.PS >= FLOOR:
					land = px
					break
			var cx := sx
			while cx + T <= land - T:
				_spike(o, cx, FLOOR - T, true)
				_spike(o, cx, CEIL, false)
				cx += T
			return land - x
		"padflip":
			# Pads on both lanes throw you over a short stretch spiked on both sides.
			_pad(o, x, true)
			_pad(o, x, false)
			var first := x + v * 0.08
			var count := 1 + int(maxf(0.0, (0.29 * v - 60.0 - 0.08 * v) / T))
			for i in count:
				_spike(o, first + i * T, FLOOR - T, true)
				_spike(o, first + i * T, CEIL, false)
			return first - x + count * T
		"gportal":
			var dir := 1 if rng.randf() < 0.5 else -1
			_special(o, x, 5, {"dir": dir})
			var sx := x + _snap(v * 0.3)
			var n := rng.randi_range(2, 4)
			for i in n:
				if dir > 0:
					_spike(o, sx + i * T, CEIL, false)
				else:
					_spike(o, sx + i * T, FLOOR - T, true)
			return sx - x + n * T
		"squeeze":
			# Only a mini cube fits under (or over) this wall.
			var fl := rng.randf() < 0.5
			var length := 4 * T
			if fl:
				_block(o, x, CEIL, length, FLOOR - 18.0 - CEIL)
			else:
				_block(o, x, CEIL + 18.0, length, FLOOR - CEIL - 18.0)
			return length
	return 0.0


static func _ride(o: Array, x: float, fl: bool, lead: float, rng: RandomNumberGenerator) -> float:
	var length := lead + _snap(rng.randi_range(3, 6) * T) + T
	if fl:
		_block(o, x, FLOOR - 4 * T, length, 4 * T)
	else:
		_block(o, x, CEIL, length, 4 * T)
	var sx := x + lead
	while sx + T <= x + length - T:
		if fl:
			_spike(o, sx, CEIL, false)
		else:
			_spike(o, sx, FLOOR - T, true)
		sx += T
	return length
