extends RefCounted
## The level list and the chunk-based level generator.
## Each level is built from its seed, so its layout is identical on every run.
## tools/check_levels.gd proves with a search bot that every level can be finished.

## How much harder this version is than the browser prototype:
## every reaction window (the time you get between hazards) is divided by this number.
const DIFFICULTY := 1.964739957393

const CEIL := 40.0
const FLOOR := 360.0
const T := 40.0
const START_X := 720.0
const LONG := ["bar", "ride", "switch", "steps"]

## tier: 0 Easy, 1 Normal, 2 Hard, 3 Harder, 4 Insane, 5 Demon
const DEFS := [
	{"name": "Lift Off", "tier": 0, "stars": 1, "speed": 380.0, "chunks": 22, "m": 1.3, "seed": 7,
		"sky": ["1d1252", "43207a"], "accent": "ffc94d", "glow": "ff9e3d", "bpm": 120, "root": 45, "scale": [0, 3, 5, 7, 10]},
	{"name": "Double Back", "tier": 1, "stars": 2, "speed": 440.0, "chunks": 28, "m": 1.05, "seed": 23,
		"sky": ["0b2440", "0f5a6e"], "accent": "5ce1ff", "glow": "2fb7ff", "bpm": 132, "root": 38, "scale": [0, 2, 3, 7, 8]},
	{"name": "Hard Ceiling", "tier": 2, "stars": 3, "speed": 500.0, "chunks": 34, "m": 0.88, "seed": 101,
		"sky": ["2a0b22", "6e1638"], "accent": "ff5c8a", "glow": "ff2e6a", "bpm": 144, "root": 42, "scale": [0, 1, 3, 5, 7, 8, 10]},
	{"name": "Polar Shift", "tier": 0, "stars": 1, "speed": 390.0, "chunks": 24, "m": 1.25, "seed": 211,
		"sky": ["0e2a4a", "1f6f8b"], "accent": "9df0ff", "glow": "4fd0ff", "bpm": 118, "root": 43, "scale": [0, 2, 4, 7, 9]},
	{"name": "Upside Town", "tier": 1, "stars": 2, "speed": 420.0, "chunks": 26, "m": 1.12, "seed": 307,
		"sky": ["3a1430", "8a2c5c"], "accent": "ffd36e", "glow": "ffae3d", "bpm": 126, "root": 40, "scale": [0, 2, 4, 5, 7, 9, 11]},
	{"name": "Neon Gravity", "tier": 1, "stars": 2, "speed": 440.0, "chunks": 28, "m": 1.05, "seed": 419,
		"sky": ["101a3d", "2b3fa0"], "accent": "ff7bf2", "glow": "d94dff", "bpm": 128, "root": 45, "scale": [0, 2, 3, 5, 7, 9, 10]},
	{"name": "Saw Mill", "tier": 2, "stars": 3, "speed": 450.0, "chunks": 30, "m": 1.0, "seed": 523,
		"sky": ["2b1a0c", "6b3d12"], "accent": "ffb347", "glow": "ff7a1a", "bpm": 136, "root": 41, "scale": [0, 2, 3, 5, 7, 8, 10]},
	{"name": "Flipside", "tier": 2, "stars": 4, "speed": 470.0, "chunks": 30, "m": 0.95, "seed": 631,
		"sky": ["0b2e2a", "12645a"], "accent": "6dffd2", "glow": "1fe0a8", "bpm": 138, "root": 44, "scale": [0, 2, 3, 5, 7, 8, 11]},
	{"name": "Static Drift", "tier": 3, "stars": 5, "speed": 480.0, "chunks": 32, "m": 0.92, "seed": 733,
		"sky": ["1a1a2e", "3d3d6b"], "accent": "c8d0ff", "glow": "8a96ff", "bpm": 140, "root": 39, "scale": [0, 1, 3, 5, 7, 8, 10]},
	{"name": "Zero G", "tier": 3, "stars": 6, "speed": 490.0, "chunks": 34, "m": 0.9, "seed": 839,
		"sky": ["05202e", "0a4f73"], "accent": "4dfcff", "glow": "00c8ff", "bpm": 140, "root": 46, "scale": [0, 3, 5, 7, 10]},
	{"name": "Pendulum", "tier": 3, "stars": 6, "speed": 500.0, "chunks": 34, "m": 0.88, "seed": 941,
		"sky": ["2e0f0f", "7a1f1f"], "accent": "ffcf5c", "glow": "ff6a3d", "bpm": 142, "root": 40, "scale": [0, 2, 3, 5, 7, 8, 11]},
	{"name": "Overturn", "tier": 4, "stars": 7, "speed": 520.0, "chunks": 36, "m": 0.85, "seed": 1049,
		"sky": ["1f0b33", "5a1a8c"], "accent": "ff9cf5", "glow": "ff4fd8", "bpm": 146, "root": 43, "scale": [0, 2, 3, 5, 7, 9, 10]},
	{"name": "Magnetar", "tier": 4, "stars": 8, "speed": 530.0, "chunks": 38, "m": 0.82, "seed": 1153,
		"sky": ["0b1030", "1a2a8a"], "accent": "7aa2ff", "glow": "3d6bff", "bpm": 148, "root": 38, "scale": [0, 2, 3, 5, 7, 8, 10]},
	{"name": "Inversion", "tier": 4, "stars": 8, "speed": 540.0, "chunks": 38, "m": 0.8, "seed": 1259,
		"sky": ["0f2416", "1f6b35"], "accent": "b6ff7a", "glow": "5fe03d", "bpm": 150, "root": 45, "scale": [0, 1, 3, 5, 7, 8, 10]},
	{"name": "Event Horizon", "tier": 4, "stars": 9, "speed": 550.0, "chunks": 40, "m": 0.78, "seed": 1361,
		"sky": ["120808", "4a1010"], "accent": "ff8a3d", "glow": "ff3d1f", "bpm": 152, "root": 41, "scale": [0, 2, 3, 5, 7, 8, 11]},
	{"name": "Antimatter", "tier": 5, "stars": 10, "speed": 560.0, "chunks": 42, "m": 0.75, "seed": 1471,
		"sky": ["140a24", "3d1466"], "accent": "e07aff", "glow": "a64dff", "bpm": 155, "root": 44, "scale": [0, 1, 3, 5, 7, 8, 10]},
	{"name": "Singularity", "tier": 5, "stars": 10, "speed": 570.0, "chunks": 44, "m": 0.72, "seed": 1579,
		"sky": ["07070f", "1f1f3d"], "accent": "ffffff", "glow": "9aa0ff", "bpm": 158, "root": 39, "scale": [0, 2, 3, 5, 7, 8, 11]},
	{"name": "Gravity's End", "tier": 5, "stars": 10, "speed": 580.0, "chunks": 46, "m": 0.7, "seed": 1693,
		"sky": ["1a0510", "66102e"], "accent": "ffd23d", "glow": "ff2e6a", "bpm": 160, "root": 42, "scale": [0, 1, 3, 5, 7, 8, 10]},
]


static func total_stars() -> int:
	var n := 0
	for d in DEFS:
		n += int(d.stars)
	return n


static func build(i: int) -> Dictionary:
	var d: Dictionary = DEFS[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.seed)
	var v: float = d.speed
	var m: float = d.m
	var tier: int = d.tier
	var o: Array = []
	var x := START_X
	var last := ""
	var pool := _pool(tier)
	for c in int(d.chunks):
		var kind: String
		if c < 3:
			kind = ["floor", "ceil", "zig"][c]
		else:
			kind = pool[rng.randi_range(0, pool.size() - 1)]
			while kind == last and kind in LONG:
				kind = pool[rng.randi_range(0, pool.size() - 1)]
		last = kind
		x += _chunk(kind, x, o, rng, v, m, tier)
		x += _snap(v * 0.62 * m * (1.0 + rng.randf() * 0.3) / DIFFICULTY)
		if kind in LONG:
			x += T * 2.0
	o.sort_custom(func(a, b): return a.x < b.x)
	var mw := 0.0
	for ob in o:
		mw = maxf(mw, ob.w)
	return {"i": i, "def": d, "objs": o, "end": x + 300.0, "max_w": mw, "speed": v}


static func _pool(tier: int) -> Array:
	match tier:
		0:
			return ["floor", "ceil", "floor", "ceil", "zig", "pillar", "pillar", "bar"]
		1:
			return ["floor", "ceil", "zig", "zig", "pillar", "pillar", "bar", "ride", "steps"]
		2:
			return ["floor", "ceil", "zig", "zig", "pillar", "bar", "ride", "steps", "sawzig", "sawzig"]
		3:
			return ["ceil", "zig", "zig", "pillar", "bar", "ride", "steps", "sawzig", "sawzig", "switch"]
	return ["floor", "zig", "zig", "zig", "pillar", "bar", "ride", "steps", "sawzig", "sawzig", "switch", "switch"]


static func _snap(n: float) -> float:
	return ceilf(n / T) * T


static func _spike(o: Array, x: float, y: float, up: bool) -> void:
	o.append({"k": 1, "x": x, "y": y, "w": T, "h": T, "up": up})


static func _block(o: Array, x: float, y: float, w: float, h: float) -> void:
	o.append({"k": 0, "x": x, "y": y, "w": w, "h": h})


static func _saw(o: Array, cx: float, cy: float, r: float) -> void:
	o.append({"k": 2, "x": cx - r, "y": cy - r, "w": r * 2.0, "h": r * 2.0, "r": r, "cx": cx, "cy": cy})


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
