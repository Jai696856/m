extends RefCounted
## A small software synth. It writes each level's looping song and all sound effects
## into 16-bit WAV streams at start-up, so the project ships no audio files.

const RATE := 22050
const MENU := {"name": "Menu", "tier": 0, "bpm": 112, "root": 45, "scale": [0, 2, 3, 7, 10], "seed": 4242, "menu": true}

var buf := PackedFloat32Array()
var noise := PackedFloat32Array()


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	noise.resize(16384)
	for i in 16384:
		noise[i] = rng.randf_range(-1.0, 1.0)


static func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


static func deg(scale: Array, d: int) -> int:
	var n := scale.size()
	return int(scale[posmod(d, n)]) + 12 * int(floor(float(d) / n))


## wave: 0 square, 1 saw, 2 triangle, 3 sine, 4 noise, 5 bright noise.
## tau is the decay time constant; slide multiplies the pitch every sample; lp < 1 adds a low-pass.
func tone(t0: float, dur: float, freq: float, wave: int, vol: float, tau: float, slide := 1.0, lp := 1.0) -> void:
	var start := int(t0 * RATE)
	var end := mini(start + int(dur * RATE), buf.size())
	if start >= end:
		return
	var ph := 0.0
	var inc := freq / RATE
	var env := 1.0
	var k := exp(-1.0 / (tau * RATE))
	var y := 0.0
	for i in range(start, end):
		var v: float
		if wave == 0:
			v = 1.0 if ph < 0.5 else -1.0
		elif wave == 1:
			v = 2.0 * ph - 1.0
		elif wave == 2:
			v = 4.0 * absf(ph - 0.5) - 1.0
		elif wave == 3:
			v = sin(TAU * ph)
		elif wave == 4:
			v = noise[i & 16383]
		else:
			v = noise[i & 16383] - noise[(i + 7) & 16383]
		if lp < 1.0:
			y += (v - y) * lp
			v = y
		var a := env
		var j := i - start
		if j < 60:
			a *= j / 60.0
		var left := end - i
		if left < 200:
			a *= left / 200.0
		buf[i] += v * a * vol
		env *= k
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		inc *= slide


func to_wav(loop: bool, normalize: bool) -> AudioStreamWAV:
	var gain := 1.0
	if normalize:
		var peak := 0.001
		for v in buf:
			peak = maxf(peak, absf(v))
		gain = 0.85 / peak
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


## An 8-bar loop: drums, bass on the chord root, a seeded melody and (later bars) an arpeggio.
## Harder tiers get busier drums and octave-jumping bass.
func song(d: Dictionary) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.seed) * 31 + 5
	var bpm := float(d.bpm)
	var st := 60.0 / bpm / 4.0
	var bars := 8
	buf = PackedFloat32Array()
	buf.resize(int(bars * 16 * st * RATE))
	var scale: Array = d.scale
	var root := int(d.root)
	var tier := int(d.tier)
	var menu: bool = d.has("menu")
	var progs := [[0, 0, 3, 4], [0, 5, 3, 4], [0, 3, 4, 3], [0, 4, 5, 3], [0, 2, 3, 4], [0, 5, 2, 4]]
	var prog: Array = progs[rng.randi_range(0, progs.size() - 1)]
	var mel: Array = []
	var dg := 4
	for k in 16:
		if rng.randf() < 0.25:
			mel.append(-99)
		else:
			dg = clampi(dg + rng.randi_range(-2, 2), 0, 8)
			mel.append(dg)
	var kick_slide := pow(45.0 / 150.0, 1.0 / (0.1 * RATE))
	var lead_wave := 2 if (tier == 0 or menu) else 0
	for bar in bars:
		var t0 := bar * 16 * st
		var chord: int = prog[bar % 4]
		for k in 16:
			var tt := t0 + k * st
			var kick := k % 4 == 0
			if tier >= 3 and k == 14:
				kick = true
			if tier >= 4 and k == 7:
				kick = true
			if menu:
				kick = k == 0 or k == 6 or k == 10
			if kick:
				tone(tt, 0.18, 150.0, 3, 0.9, 0.08, kick_slide)
			if k == 4 or k == 12:
				tone(tt, 0.16, 0.0, 4, 0.32, 0.05, 1.0, 0.55)
				tone(tt, 0.08, 185.0, 2, 0.22, 0.04)
			var hat := k % 4 == 2
			if tier >= 2 and k % 2 == 1 and not menu:
				hat = true
			if hat:
				tone(tt, 0.04, 0.0, 5, 0.09, 0.012)
		for k in 8:
			if menu and k % 2 == 1:
				continue
			var note := root + deg(scale, chord)
			if tier >= 2 and k % 2 == 1:
				note += 12
			tone(t0 + k * 2 * st, st * 1.8, midi(note), 1, 0.3, 0.14, 1.0, 0.2)
		if bar >= 2 or menu:
			for k in 8:
				var md: int = mel[(bar % 2) * 8 + k]
				if md == -99:
					continue
				tone(t0 + k * 2 * st, st * 1.7, midi(root + 24 + deg(scale, md + chord)), lead_wave, 0.1 if lead_wave == 0 else 0.18, 0.2)
		if bar >= 4 and not menu:
			for k in 16:
				var a: int = [0, 2, 4, 2][k % 4]
				tone(t0 + k * st, st * 0.9, midi(root + 36 + deg(scale, chord + a)), 3, 0.06, 0.06)
	return to_wav(true, true)


func _fx(dur: float) -> void:
	buf = PackedFloat32Array()
	buf.resize(int(dur * RATE))


func effects() -> Dictionary:
	var out := {}
	_fx(0.12)
	tone(0.0, 0.1, 520.0, 2, 0.55, 0.06, pow(1.9, 1.0 / (0.08 * RATE)))
	out["flip_up"] = to_wav(false, false)
	_fx(0.12)
	tone(0.0, 0.1, 780.0, 2, 0.55, 0.06, pow(0.55, 1.0 / (0.08 * RATE)))
	out["flip_down"] = to_wav(false, false)
	_fx(0.5)
	tone(0.0, 0.45, 0.0, 4, 0.8, 0.12, 1.0, 0.25)
	tone(0.0, 0.35, 220.0, 1, 0.35, 0.12, pow(0.22, 1.0 / (0.3 * RATE)), 0.3)
	out["die"] = to_wav(false, false)
	_fx(1.5)
	var chord := [0, 4, 7, 12, 16]
	for i in chord.size():
		tone(i * 0.08, 1.1, midi(72 + chord[i]), 2, 0.3, 0.4)
		tone(i * 0.08, 0.5, midi(60 + chord[i]), 0, 0.06, 0.2)
	tone(0.0, 0.7, 0.0, 5, 0.12, 0.25)
	out["win"] = to_wav(false, false)
	_fx(0.06)
	tone(0.0, 0.05, 900.0, 3, 0.45, 0.02)
	out["click"] = to_wav(false, false)
	_fx(0.4)
	tone(0.0, 0.12, 660.0, 0, 0.2, 0.08)
	tone(0.1, 0.25, 990.0, 0, 0.2, 0.12)
	out["best"] = to_wav(false, false)
	_fx(0.6)
	var arp := [0, 3, 7, 12]
	for i in arp.size():
		tone(i * 0.06, 0.3, midi(76 + arp[i]), 0, 0.16, 0.12)
	out["unlock"] = to_wav(false, false)
	_fx(0.18)
	tone(0.0, 0.14, 170.0, 0, 0.25, 0.06, pow(0.7, 1.0 / (0.1 * RATE)), 0.3)
	out["deny"] = to_wav(false, false)
	_fx(0.35)
	tone(0.0, 0.3, 0.0, 4, 0.45, 0.07, 1.0, 0.5)
	tone(0.0, 0.12, 300.0, 3, 0.2, 0.05, pow(0.5, 1.0 / (0.1 * RATE)))
	out["pop"] = to_wav(false, false)
	return out
