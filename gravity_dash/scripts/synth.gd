extends RefCounted

const RATE:= 22050
const GENRE_NAMES:= ["Chiptune", "Synthwave", "Breakbeat", "House", "Half-time", "Ambient"]

var buf:= PackedFloat32Array()
var noise:= PackedFloat32Array()

var d: Dictionary
var bars:= 12
var bar:= 0
var st:= 0.125
var scale: Array
var root:= 45
var genre:= 0
var tier:= 0
var prog: Array
var mel_a: Array
var mel_b: Array
var kick_slide:= 1.0

func _init() -> void:
	var rng:= RandomNumberGenerator.new()
	rng.seed = 12345
	noise.resize(16384)
	for i in 16384:
		noise[i] = rng.randf_range(-1.0, 1.0)

static func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

static func deg(sc: Array, x: int) -> int:
	var n:= sc.size()
	return int(sc[posmod(x, n)]) + 12 * int(floor(float(x) / n))

func tone(t0: float, dur: float, freq: float, wave: int, vol: float, tau: float, slide:= 1.0, lp:= 1.0, attack:= 60, vib:= 0.0) -> void:
	var start:= int(t0 * RATE)
	var end:= mini(start + int(dur * RATE), buf.size())
	if start >= end:
		return
	var ph:= 0.0
	var inc:= freq / RATE
	var env:= 1.0
	var k:= exp(-1.0 / (tau * RATE))
	var y:= 0.0
	var vph:= 0.0
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
		elif wave == 5:
			v = noise[i & 16383] - noise[(i + 7) & 16383]
		else:
			v = 1.0 if ph < 0.25 else -1.0
		if lp < 1.0:
			y += (v - y) * lp
			v = y
		var a:= env
		var j:= i - start
		if j < attack:
			a *= float(j) / attack
		var left:= end - i
		if left < 200:
			a *= left / 200.0
		buf[i] += v * a * vol
		env *= k
		if vib > 0.0:
			vph += 5.5 / RATE
			ph += inc * (1.0 + sin(TAU * vph) * vib)
		else:
			ph += inc
		if ph >= 1.0:
			ph -= 1.0
		inc *= slide

func to_wav(loop: bool, normalize: bool) -> AudioStreamWAV:
	var gain:= 1.0
	if normalize:
		var peak:= 0.001
		for v in buf:
			peak = maxf(peak, absf(v))
		gain = 0.85 / peak
	var n:= buf.size()
	var bytes:= PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w:= AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func begin_song(p: Dictionary) -> void:
	d = p
	var rng:= RandomNumberGenerator.new()
	rng.seed = int(p.seed) * 31 + 5
	genre = int(p.get("genre", 0))
	tier = int(p.get("tier", 0))
	scale = p.scale
	root = int(p.root)
	st = 60.0 / float(p.bpm) / 4.0
	bars = 12
	bar = 0
	buf = PackedFloat32Array()
	buf.resize(int(bars * 16 * st * RATE))
	var progs:= [[0, 0, 3, 4], [0, 5, 3, 4], [0, 3, 4, 3], [0, 4, 5, 3], [0, 2, 3, 4], [0, 5, 2, 4], [0, 3, 5, 4]]
	prog = progs[rng.randi_range(0, progs.size() - 1)]
	mel_a = _melody(rng)
	mel_b = _melody(rng)
	kick_slide = pow(45.0 / 150.0, 1.0 / (0.1 * RATE))

func _melody(rng: RandomNumberGenerator) -> Array:
	var mel: Array = []
	var dg:= 4
	for k in 16:
		if rng.randf() < 0.25:
			mel.append(-99)
		else:
			dg = clampi(dg + rng.randi_range(-2, 2), 0, 9)
			mel.append(dg)
	return mel

func done() -> bool:
	return bar >= bars

func render_bar() -> void:
	if done():
		return
	var b:= bar
	bar += 1
	var t0:= b * 16 * st
	var chord: int = prog[b % 4]
	var intro:= b < 2
	var section_b:= b >= 6 and b < 10
	var turn:= b >= 10
	_drums(b, t0, intro, turn)

	if not (intro and genre == 5):
		var steps:= [0, 2, 4, 6, 8, 10, 12, 14]
		if genre == 3:
			steps = [2, 6, 10, 14]
		elif genre == 4:
			steps = [0, 7, 10]
		elif genre == 5:
			steps = [0, 8]
		for k in steps:
			var note:= root + deg(scale, chord)
			if genre in [1, 2] and k % 4 == 2:
				note += 12
			var wave:= 0 if genre == 0 else 1
			tone(t0 + k * st, st * (3.6 if genre == 5 else 1.8), midi(note), wave, 0.3, 0.16 if genre != 5 else 0.8, 1.0, 0.2 if wave == 1 else 0.5)

	if genre in [1, 3, 5] and not intro:
		for a in [0, 2, 4]:
			var n:= midi(root + 12 + deg(scale, chord + a))
			if genre == 3:
				for k in [2, 6, 10, 14]:
					tone(t0 + k * st, st * 0.9, n, 1, 0.05, 0.08, 1.0, 0.35)
			else:
				tone(t0, 16 * st, n, 2, 0.045, 1.6, 1.0, 1.0, 2000)

	if not intro:
		var mel: Array = mel_b if section_b else mel_a
		var lead_wave: int = [0, 1, 6, 0, 1, 2][genre]
		var vib:= 0.006 if genre in [1, 5] else 0.0
		for k in 8:
			var md: int = mel[(b % 2) * 8 + k]
			if md == -99 or (genre == 5 and k % 2 == 1):
				continue
			var len:= st * (3.4 if genre == 5 else 1.7)
			var vol:= 0.09 if lead_wave in [0, 1, 6] else 0.16
			tone(t0 + k * 2 * st, len, midi(root + 24 + deg(scale, md + chord)), lead_wave, vol, 0.25, 1.0, 0.45 if lead_wave == 1 else 1.0, 60, vib)

	if section_b or turn:
		for k in 16:
			var a: int = [0, 2, 4, 2][k % 4]
			tone(t0 + k * st, st * 0.9, midi(root + 36 + deg(scale, chord + a)), 3, 0.055, 0.06)

func _drums(b: int, t0: float, intro: bool, turn: bool) -> void:
	var kicks: Array
	var snares: Array
	var hats: Array
	match genre:
		0:
			kicks = [0, 8]
			snares = [4, 12]
			hats = [2, 6, 10, 14]
		1:
			kicks = [0, 4, 8, 12]
			snares = [4, 12]
			hats = [2, 6, 10, 14]
		2:
			kicks = [0, 6, 10]
			snares = [4, 12, 15]
			hats = range(0, 16, 2)
		3:
			kicks = [0, 4, 8, 12]
			snares = [4, 12]
			hats = [2, 6, 10, 14, 3, 11]
		4:
			kicks = [0, 3, 10]
			snares = [8]
			hats = range(0, 16)
		_:
			kicks = [0]
			snares = []
			hats = [4, 12]
	if tier >= 3 and genre != 5:
		kicks = kicks + [14]
	if intro:
		snares = []
		if genre != 5:
			kicks = [0, 8]
	for k in kicks:
		tone(t0 + k * st, 0.18, 150.0, 3, 0.9, 0.08, kick_slide)
	for k in snares:
		tone(t0 + k * st, 0.16, 0.0, 4, 0.3, 0.05, 1.0, 0.55)
		tone(t0 + k * st, 0.08, 185.0, 2, 0.2, 0.04)
	for k in hats:
		tone(t0 + k * st, 0.04, 0.0, 5, 0.08 if k % 2 == 0 else 0.05, 0.012)
	if turn and b == 11:
		for k in [12, 13, 14, 15]:
			tone(t0 + k * st, 0.1, 0.0, 4, 0.25, 0.04, 1.0, 0.6)
	if b == 2 or b == 6:
		tone(t0, 0.9, 0.0, 5, 0.12, 0.35)

func finish() -> AudioStreamWAV:
	return to_wav(true, true)

func song(p: Dictionary) -> AudioStreamWAV:
	begin_song(p)
	while not done():
		render_bar()
	return finish()

func _fx(dur: float) -> void:
	buf = PackedFloat32Array()
	buf.resize(int(dur * RATE))

func effects(retro:= false) -> Dictionary:
	var out:= {}
	var w:= 0 if retro else 2
	_fx(0.12)
	tone(0.0, 0.1, 520.0, w, 0.45 if retro else 0.55, 0.06, pow(1.9, 1.0 / (0.08 * RATE)))
	out["flip_up"] = to_wav(false, false)
	_fx(0.12)
	tone(0.0, 0.1, 780.0, w, 0.45 if retro else 0.55, 0.06, pow(0.55, 1.0 / (0.08 * RATE)))
	out["flip_down"] = to_wav(false, false)
	_fx(0.18)
	tone(0.0, 0.16, 660.0, w, 0.4, 0.08, pow(2.2, 1.0 / (0.12 * RATE)))
	tone(0.0, 0.16, 990.0, 3, 0.2, 0.06)
	out["orb"] = to_wav(false, false)
	_fx(0.16)
	tone(0.0, 0.14, 300.0, w, 0.45, 0.06, pow(3.0, 1.0 / (0.1 * RATE)))
	out["pad"] = to_wav(false, false)
	_fx(0.4)
	tone(0.0, 0.35, 220.0, 3, 0.35, 0.15, pow(2.5, 1.0 / (0.3 * RATE)))
	tone(0.0, 0.3, 0.0, 5, 0.1, 0.12)
	out["portal"] = to_wav(false, false)
	_fx(0.25)
	tone(0.0, 0.2, 1320.0, 3, 0.3, 0.08)
	tone(0.05, 0.18, 1760.0, 3, 0.3, 0.08)
	out["coin"] = to_wav(false, false)
	_fx(0.08)
	tone(0.0, 0.06, 1480.0, 3, 0.18, 0.03)
	out["shard"] = to_wav(false, false)
	_fx(0.5)
	tone(0.0, 0.45, 0.0, 4, 0.8, 0.12, 1.0, 0.25)
	tone(0.0, 0.35, 220.0, 0 if retro else 1, 0.35, 0.12, pow(0.22, 1.0 / (0.3 * RATE)), 0.3)
	out["die"] = to_wav(false, false)
	_fx(1.5)
	var chord:= [0, 4, 7, 12, 16]
	for i in chord.size():
		tone(i * 0.08, 1.1, midi(72 + chord[i]), w, 0.3, 0.4)
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
	var arp:= [0, 3, 7, 12]
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
	_fx(0.3)
	tone(0.0, 0.25, 880.0, 2, 0.3, 0.1)
	tone(0.08, 0.2, 1175.0, 2, 0.25, 0.1)
	out["checkpoint"] = to_wav(false, false)
	_fx(0.6)
	for i in 3:
		tone(i * 0.07, 0.4, midi(79 + [0, 4, 7][i]), 3, 0.3, 0.2)
	out["buy"] = to_wav(false, false)
	_fx(0.9)
	tone(0.0, 0.25, 0.0, 4, 0.5, 0.08, 1.0, 0.4)
	for i in 4:
		tone(0.2 + i * 0.07, 0.6, midi(72 + [0, 4, 7, 12][i]), 2, 0.25, 0.3)
	out["chest"] = to_wav(false, false)
	return out
