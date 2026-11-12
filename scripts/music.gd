# Background music synthesized in code: a tiny step sequencer renders each
# song's 4-bar loop on a worker thread, so the project ships no audio files.
# Two songs: a calm one for the menus and a bouncier one for games.
extends AudioStreamPlayer

const RATE := 22050.0

## Each song: tempo, scale (semitones from the key), key frequency,
## chord roots per bar (scale degrees), a melody of 16 eighth-note steps per
## bar pattern (-1 = rest, otherwise a scale degree, +7 = an octave up),
## and whether a soft hi-hat plays.
const SONGS := {
	"menu": {
		"bpm": 84.0, "key": 220.0, "scale": [0, 2, 4, 7, 9],
		"chords": [0, 3, 4, 2],
		"melody": [
			[4, -1, 3, -1, 2, -1, -1, 1, 2, -1, -1, -1, -1, -1, -1, -1],
			[5, -1, 4, -1, 3, -1, 4, -1, 2, -1, -1, -1, 1, -1, -1, -1],
			[4, -1, 5, -1, 7, -1, -1, 6, 5, -1, -1, -1, 4, -1, -1, -1],
			[3, -1, 2, -1, 1, -1, 2, -1, 0, -1, -1, -1, -1, -1, -1, -1],
		],
		"hat": false,
	},
	"game": {
		"bpm": 118.0, "key": 196.0, "scale": [0, 2, 4, 7, 9],
		"chords": [0, 4, 3, 2],
		"melody": [
			[0, -1, 2, 3, 4, -1, 2, -1, 3, -1, 4, -1, 7, -1, -1, -1],
			[6, -1, 5, 4, 5, -1, 4, -1, 2, -1, 3, -1, 4, -1, -1, -1],
			[2, -1, 3, 4, 5, -1, 7, -1, 6, -1, 5, -1, 4, -1, 3, -1],
			[4, -1, 2, -1, 3, -1, 1, -1, 0, -1, -1, -1, 0, -1, 2, -1],
		],
		"hat": true,
	},
}

var song := ""
var enabled := true
var _cache := {}         # song id -> AudioStreamWAV
var _tasks := {}         # song id -> WorkerThreadPool task id
var _mutex := Mutex.new()

func _ready() -> void:
	volume_db = -14.0
	# Render both loops in the background so startup stays instant
	for id in SONGS:
		var sid: String = id
		_tasks[sid] = WorkerThreadPool.add_task(func() -> void: _render_task(sid))

func _exit_tree() -> void:
	for id in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[id])
	_tasks.clear()

func _render_task(id: String) -> void:
	var w := render(id)
	_mutex.lock()
	_cache[id] = w
	_mutex.unlock()

## Switch songs ("" stops the music). Starts as soon as the loop is rendered.
func play_song(id: String) -> void:
	if id == song and (playing or not enabled):
		return
	song = id
	_start()

func set_enabled(on: bool) -> void:
	if on == enabled and (playing or not on):
		return
	enabled = on
	_start()

func is_ready(id: String) -> bool:
	_mutex.lock()
	var ok := _cache.has(id)
	_mutex.unlock()
	return ok

func _start() -> void:
	stop()
	if song == "" or not enabled or not is_ready(song):
		return
	_mutex.lock()
	stream = _cache[song]
	_mutex.unlock()
	play()

func _process(_dt: float) -> void:
	# Pick up a loop that finished rendering after play_song was called
	if not playing and enabled and song != "" and is_ready(song):
		_start()

static func _freq(d: Dictionary, degree: int, octave: int) -> float:
	var sc: Array = d["scale"]
	var n := sc.size()
	var o := octave + int(floor(float(degree) / n))
	var semis: int = int(sc[posmod(degree, n)]) + 12 * o
	return float(d["key"]) * pow(2.0, semis / 12.0)

## Render one 4-bar loop of a song to a looping 16-bit WAV.
static func render(id: String) -> AudioStreamWAV:
	var d: Dictionary = SONGS[id]
	var step_len: float = 60.0 / float(d["bpm"]) / 2.0
	var steps := 64
	var n := int(steps * step_len * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Notes: [start_sample, freq, dur, vol, wave]
	var notes: Array = []
	for st in range(steps):
		var bar := st / 16
		var s := st % 16
		var t0 := int(st * step_len * RATE)
		var root: int = d["chords"][bar]
		if s % 8 == 0:
			notes.append([t0, _freq(d, root, -1), step_len * 3.5, 0.32, 0])
		if s == 0:
			for k in [0, 2, 4]:
				notes.append([t0, _freq(d, root + k, 0), step_len * 15.0, 0.06, 1])
		var m: int = d["melody"][bar][s]
		if m >= 0:
			notes.append([t0, _freq(d, m, 1), step_len * 1.8, 0.16, 0])
		if d["hat"] and s % 2 == 1:
			notes.append([t0, 0.0, 0.04, 0.05, 2])
	for nt in notes:
		var start: int = nt[0]
		var f: float = nt[1]
		var count := int(float(nt[2]) * RATE)
		var vol: float = nt[3]
		var wave: int = nt[4]
		var phase := 0.0
		var inc := f / RATE
		for i in range(count):
			var j := (start + i) % n   # tails wrap so the loop is seamless
			var k := float(i) / count
			var env := minf(1.0, i / 40.0) * (1.0 - k) * (1.0 - k) * vol
			phase += inc
			if phase >= 1.0:
				phase -= 1.0
			var w := 0.0
			if wave == 0:
				w = 1.0 - 4.0 * absf(phase - 0.5)
			elif wave == 1:
				w = sin(phase * TAU)
			else:
				w = rng.randf_range(-1.0, 1.0)
			buf[j] += w * env
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
