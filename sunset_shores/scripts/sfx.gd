extends Node
## All sound is synthesised at startup: gunshots, crashes, explosions, horn,
## siren, pickup chimes, a live engine for the player's car, and "Palm FM",
## an original synth loop rendered on a worker thread that plays while driving.

const RATE := 22050
const RADIO_RATE := 16000

var game
var streams := {}
var pool3d: Array[AudioStreamPlayer3D] = []
var pool2d: Array[AudioStreamPlayer] = []
var next3d := 0
var next2d := 0
var engine: AudioStreamPlayer
var engine_pb: AudioStreamGeneratorPlayback
var eng_phase := 0.0
var eng_lp := 0.0
var eng_vol := 0.0
var eng_freq := 30.0
var radio: AudioStreamPlayer
var radio_on := true
var radio_ready := false
var _thread: Thread


func setup(g) -> void:
	game = g
	name = "Sfx"
	streams["pistol"] = _shot(0.28, 1.0, 160.0)
	streams["smg"] = _shot(0.14, 0.8, 210.0)
	streams["thud"] = _thud(0.18, 90.0)
	streams["door"] = _thud(0.12, 160.0)
	streams["crash"] = _crash()
	streams["explosion"] = _explosion()
	streams["pickup"] = _chime([880.0, 1320.0], 0.08)
	streams["pass"] = _chime([523.0, 659.0, 784.0, 1046.0], 0.13)
	streams["fail"] = _chime([392.0, 330.0, 262.0], 0.2)
	streams["click"] = _chime([1200.0], 0.03)
	streams["horn"] = _horn()
	streams["siren"] = _siren()
	for i in 16:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 12.0
		p.max_distance = 220.0
		add_child(p)
		pool3d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool2d.append(p)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	engine = AudioStreamPlayer.new()
	engine.stream = gen
	engine.volume_db = -12.0
	add_child(engine)
	engine.play()
	engine_pb = engine.get_stream_playback() as AudioStreamGeneratorPlayback
	radio = AudioStreamPlayer.new()
	radio.volume_db = -11.0
	add_child(radio)
	if not game.headless:
		_thread = Thread.new()
		_thread.start(_render_radio)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func play(sname: String, pos = null, vol := 0.0, pitch := 1.0) -> void:
	if not streams.has(sname):
		return
	if pos == null:
		var p := pool2d[next2d]
		next2d = (next2d + 1) % pool2d.size()
		p.stream = streams[sname]
		p.volume_db = vol
		p.pitch_scale = pitch
		p.play()
	else:
		var p := pool3d[next3d]
		next3d = (next3d + 1) % pool3d.size()
		p.stream = streams[sname]
		p.volume_db = vol
		p.pitch_scale = pitch
		p.global_position = pos
		p.play()


# --- synthesis helpers -------------------------------------------------------------

func _wav(samples: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _shot(length: float, bright: float, thump: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * (0.35 * bright)
		var body := sin(TAU * thump * t * (1.0 - t * 2.0)) * exp(-t * 28.0)
		s[i] = (lp * exp(-t * 22.0) * 1.2 + body * 0.9 + noise * exp(-t * 90.0) * 0.5) * 0.8
	return _wav(s)


func _thud(length: float, f: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.08
		s[i] = (sin(TAU * f * t) * 0.7 + lp * 1.5) * exp(-t * 25.0)
	return _wav(s)


func _crash() -> AudioStreamWAV:
	var n := int(0.6 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.2
		var ring := (sin(TAU * 610.0 * t) + sin(TAU * 937.0 * t) * 0.7 + sin(TAU * 1490.0 * t) * 0.4) * exp(-t * 9.0) * 0.25
		s[i] = lp * 1.6 * exp(-t * 7.0) + ring + sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.6
	return _wav(s)


func _explosion() -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.07
		lp2 += (lp - lp2) * 0.1
		var rumble := sin(TAU * (45.0 - t * 10.0) * t) * exp(-t * 2.5)
		s[i] = clampf((lp * 3.0 + lp2 * 6.0) * exp(-t * 1.8) + rumble * 0.8, -1.0, 1.0)
	return _wav(s)


func _chime(notes: Array, step: float) -> AudioStreamWAV:
	var n := int((step * notes.size() + 0.35) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var t0 := t - k * step
			if t0 >= 0.0:
				var f: float = notes[k]
				v += (sin(TAU * f * t0) + sin(TAU * f * 2.0 * t0) * 0.25) * exp(-t0 * 7.0) * 0.35
		s[i] = v
	return _wav(s)


func _horn() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 40.0) * minf(1.0, (0.5 - t) * 30.0)
		var v := 0.0
		for f in [392.0, 494.0]:
			for h in [1.0, 2.0, 3.0]:
				v += sin(TAU * f * h * t) / (h * h)
		s[i] = clampf(v * 0.35, -0.8, 0.8) * env
	return _wav(s)


func _siren() -> AudioStreamWAV:
	# a two-second wail; the frequency sweep integrates to a whole number of cycles so it loops cleanly
	var period := 2.0
	var n := int(period * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 950.0 - 300.0 * cos(TAU * t / period)
		phase += f / RATE
		s[i] = (sin(TAU * phase) * 0.6 + sin(TAU * phase * 3.0) * 0.12) * 0.7
	return _wav(s, RATE, true)


# --- engine and radio --------------------------------------------------------------------

func _process(delta: float) -> void:
	var p = game.player
	var car = p.in_car if p else null
	var target_vol := 0.0
	if car != null and not car.dead and game.state == "play":
		var spd: float = absf(car.forward_speed())
		var gear := mini(int(spd / 11.0), 4)
		var frac := (spd - gear * 11.0) / 11.0
		var target_f := 34.0 + gear * 6.0 + frac * 55.0 + absf(car.accel) * 10.0
		eng_freq = lerpf(eng_freq, target_f, minf(1.0, delta * 8.0))
		target_vol = 0.55 + absf(car.accel) * 0.45
	eng_vol = move_toward(eng_vol, target_vol, delta * 2.5)
	if engine_pb and eng_vol > 0.001:
		var frames := engine_pb.get_frames_available()
		for i in frames:
			eng_phase += eng_freq / RATE
			if eng_phase >= 1.0:
				eng_phase -= 1.0
			var x := (eng_phase * 2.0 - 1.0) * 0.5 + sin(eng_phase * TAU * 2.0) * 0.3 + (randf() * 2.0 - 1.0) * 0.06
			eng_lp += (x - eng_lp) * 0.22
			var v := eng_lp * eng_vol * 0.6
			engine_pb.push_frame(Vector2(v, v))
	var want_radio: bool = radio_ready and radio_on and car != null and not car.dead and game.state == "play"
	if want_radio and not radio.playing:
		radio.play()
	radio.stream_paused = not want_radio


func toggle_radio() -> void:
	radio_on = not radio_on
	game.hud.notice("Palm FM " + ("on" if radio_on else "off"))


func _radio_done(w: AudioStreamWAV) -> void:
	radio.stream = w
	radio_ready = true


func _render_radio() -> void:
	# Palm FM: an original 8-bar synth loop (A minor - F - C - G) at 102 bpm.
	var bpm := 102.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4 * beat * RADIO_RATE)
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	var freqs := []
	for ch in chords:
		var f := []
		for m in ch:
			f.append(440.0 * pow(2.0, (m - 69) / 12.0))
		freqs.append(f)
	var arp_order := [0, 1, 2, 1, 2, 0, 1, 2]
	var s := PackedFloat32Array()
	s.resize(n)
	var seed_v := 1234567
	var hp := 0.0
	for i in n:
		var t := float(i) / RADIO_RATE
		var b := t / beat
		var bar := int(b / 4.0)
		var f: Array = freqs[(bar / 2) % 4]
		var e := b * 2.0
		var ei := int(e)
		var ef := e - ei
		var root: float = f[0] * 0.25 * (2.0 if ei % 2 == 1 else 1.0)
		var bass := (sin(TAU * root * t) + 0.45 * sin(TAU * root * 2.0 * t) + 0.2 * sin(TAU * root * 3.0 * t)) * exp(-ef * 2.5) * 0.32
		var pad := 0.0
		for k in 3:
			var pf: float = f[k]
			pad += sin(TAU * pf * t) + 0.5 * sin(TAU * pf * 1.003 * t)
		pad *= 0.045 * (0.75 + 0.25 * sin(TAU * t * 0.25))
		var sx := b * 4.0
		var si := int(sx)
		var sf := sx - si
		var af: float = f[arp_order[si % 8] % 3] * 2.0
		var ph := fmod(af * t, 1.0)
		var tri := 4.0 * absf(ph - 0.5) - 1.0
		var arp := tri * exp(-sf * 5.0) * 0.12
		var kt := fmod(b, 1.0) * beat
		var kick := sin(TAU * (48.0 + 110.0 * exp(-kt * 32.0)) * kt) * exp(-kt * 9.0) * 0.6
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed_v) / 1073741823.5 - 1.0
		hp = noise - hp * 0.6
		var snare := 0.0
		if int(b) % 2 == 1:
			snare = noise * exp(-kt * 16.0) * 0.32 + sin(TAU * 190.0 * kt) * exp(-kt * 20.0) * 0.2
		var hat := hp * exp(-ef * beat * 0.5 * 70.0) * 0.07
		var v := bass + pad + arp + kick + snare + hat
		s[i] = v / (1.0 + absf(v))
	var w := _wav(s, RADIO_RATE, true)
	call_deferred("_radio_done", w)
