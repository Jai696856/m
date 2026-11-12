# Tiny synthesizer: every sound effect is generated in code at startup,
# so the project ships with no audio files.
extends Node

const RATE := 22050

var muted := false
## True while the menu demo runs, so the title screen stays quiet.
var suppressed := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}

const GAPS := {"pop": 28, "boom": 70, "throw": 45, "beam": 60, "slash": 60, "cast": 60, "freeze": 80, "wave": 80}

func _ready() -> void:
	for i in range(14):
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	# Each tone: [start_freq, end_freq (0 = constant), duration, wave, volume, delay]
	_streams["pop"] = _make([[700.0, 1500.0, 0.07, "sine", 0.5, 0.0]])
	_streams["boom"] = _make([[160.0, 40.0, 0.25, "square", 0.35, 0.0]])
	_streams["throw"] = _make([[1200.0, 600.0, 0.05, "tri", 0.25, 0.0]])
	_streams["cast"] = _make([[300.0, 700.0, 0.15, "saw", 0.25, 0.0]])
	_streams["slash"] = _make([[2000.0, 300.0, 0.08, "saw", 0.2, 0.0]])
	_streams["beam"] = _make([[900.0, 1600.0, 0.06, "square", 0.12, 0.0]])
	_streams["freeze"] = _make([[1800.0, 2600.0, 0.25, "sine", 0.3, 0.0]])
	_streams["wave"] = _make([[440.0, 880.0, 0.2, "tri", 0.35, 0.0]])
	_streams["place"] = _make([[660.0, 0.0, 0.1, "tri", 0.45, 0.0], [990.0, 0.0, 0.14, "tri", 0.45, 0.08]])
	_streams["upgrade"] = _make([[523.0, 0.0, 0.12, "tri", 0.4, 0.0], [659.0, 0.0, 0.12, "tri", 0.4, 0.06], [784.0, 0.0, 0.12, "tri", 0.4, 0.12], [1047.0, 0.0, 0.14, "tri", 0.4, 0.18]])
	_streams["sell"] = _make([[880.0, 440.0, 0.1, "sine", 0.45, 0.0]])
	_streams["leak"] = _make([[140.0, 70.0, 0.3, "saw", 0.4, 0.0]])
	_streams["round"] = _make([[392.0, 0.0, 0.18, "tri", 0.4, 0.0], [523.0, 0.0, 0.18, "tri", 0.4, 0.1], [659.0, 0.0, 0.2, "tri", 0.4, 0.2]])
	_streams["win"] = _make([[523.0, 0.0, 0.25, "tri", 0.4, 0.0], [659.0, 0.0, 0.25, "tri", 0.4, 0.12], [784.0, 0.0, 0.25, "tri", 0.4, 0.24], [1047.0, 0.0, 0.25, "tri", 0.4, 0.36], [1319.0, 0.0, 0.4, "tri", 0.4, 0.48]])
	_streams["lose"] = _make([[392.0, 0.0, 0.3, "saw", 0.3, 0.0], [330.0, 0.0, 0.3, "saw", 0.3, 0.18], [262.0, 0.0, 0.3, "saw", 0.3, 0.36], [196.0, 0.0, 0.5, "saw", 0.3, 0.54]])
	_streams["boss"] = _make([[80.0, 50.0, 0.8, "saw", 0.45, 0.0]])
	_streams["error"] = _make([[200.0, 0.0, 0.12, "square", 0.2, 0.0]])

func play(id: String) -> void:
	if muted or suppressed or not _streams.has(id):
		return
	var now := Time.get_ticks_msec()
	var gap: int = GAPS.get(id, 0)
	if gap > 0 and now - int(_last.get(id, -100000)) < gap:
		return
	_last[id] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	if id == "pop":
		p.pitch_scale = randf_range(0.75, 1.35)
	else:
		p.pitch_scale = 1.0
	p.play()

func _make(tones: Array) -> AudioStreamWAV:
	var total := 0.0
	for t in tones:
		total = maxf(total, float(t[2]) + float(t[5]))
	var n := int(total * RATE) + 64
	var buf := PackedFloat32Array()
	buf.resize(n)
	for t in tones:
		var f0: float = t[0]
		var f1: float = t[1]
		var dur: float = t[2]
		var wave: String = t[3]
		var vol: float = t[4]
		var start := int(float(t[5]) * RATE)
		var count := int(dur * RATE)
		var phase := 0.0
		for i in range(count):
			var k := float(i) / float(count)
			var f := f0 if f1 <= 0.0 else f0 * pow(f1 / f0, k)
			phase += f / RATE
			var x := fmod(phase, 1.0)
			var v := 0.0
			match wave:
				"sine": v = sin(x * TAU)
				"square": v = 1.0 if x < 0.5 else -1.0
				"saw": v = x * 2.0 - 1.0
				_: v = 1.0 - 4.0 * absf(x - 0.5)
			var env := vol * pow(0.001, k) * minf(1.0, float(i) / 40.0)
			var j := start + i
			if j < n:
				buf[j] += v * env
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
