extends Node
## Autoload "Audio": plays the generated music and sound effects.
## On desktop, songs are synthesised on a background thread. The browser build is single-threaded, so there
## songs are rendered one bar per frame while you are in the menus (and finished on the spot if needed).

const Synth = preload("res://scripts/synth.gd")
const Levels = preload("res://scripts/levels.gd")
const Catalog = preload("res://scripts/catalog.gd")

var music: AudioStreamPlayer
var players: Array = []
var effects: Dictionary = {}
var effects_retro: Dictionary = {}
var songs: Dictionary = {}
var params: Dictionary = {}
var queue: Array = []
var mutex := Mutex.new()
var thread: Thread
var quitting := false
var current = null
var bpm := 112.0
var web := false
var job = null
var job_key = null
var busy_frame := false
var unlocked := false  # browsers only allow audio after the first click, tap or key press  # the game sets this while a level is running so the web build doesn't render songs then


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	web = OS.has_feature("web")
	unlocked = not web
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	var syn = Synth.new()
	effects = syn.effects(false)
	effects_retro = syn.effects(true)
	apply_volume()
	for i in Catalog.THEMES.size():
		register("theme:%d" % i, theme_params(i))
	for i in Levels.main_count():
		var p: Dictionary = Levels.main_params(i)
		register(p.key, p)
	if not web:
		thread = Thread.new()
		thread.start(_worker)


func _input(e: InputEvent) -> void:
	if unlocked:
		return
	if (e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventKey) and e.is_pressed():
		unlocked = true
		_restart_current.call_deferred()


func _restart_current() -> void:
	if current != null and Save.setting("music"):
		var key: String = str(current)
		current = null
		play(key, true)


func _exit_tree() -> void:
	quitting = true
	if thread and thread.is_started():
		thread.wait_to_finish()


static func theme_params(i: int) -> Dictionary:
	var t: Dictionary = Catalog.THEMES[i]
	return {"seed": 4242 + i * 17, "genre": t.genre, "bpm": t.bpm, "root": t.root, "scale": [0, 2, 3, 7, 10], "tier": 1}


## Makes a song known so it can be prefetched or played later.
func register(key: String, p: Dictionary) -> void:
	mutex.lock()
	if not params.has(key):
		params[key] = p
		if not songs.has(key) and not queue.has(key):
			queue.append(key)
	mutex.unlock()


func prefetch(key: String) -> void:
	mutex.lock()
	if not songs.has(key) and params.has(key):
		queue.erase(key)
		queue.push_front(key)
	mutex.unlock()


func _worker() -> void:
	while not quitting:
		mutex.lock()
		var key = null
		if not queue.is_empty():
			key = queue.pop_front()
		mutex.unlock()
		if key == null:
			OS.delay_msec(100)
			continue
		_song(key)


func _process(_delta: float) -> void:
	if not web or busy_frame:
		return
	# Web: render one bar of the next queued song per frame.
	if job == null:
		mutex.lock()
		while not queue.is_empty() and songs.has(queue[0]):
			queue.pop_front()
		if not queue.is_empty():
			job_key = queue.pop_front()
			job = Synth.new()
			job.begin_song(params[job_key])
		mutex.unlock()
		return
	job.render_bar()
	if job.done():
		songs[job_key] = job.finish()
		job = null
		job_key = null


func _song(key: String) -> AudioStreamWAV:
	mutex.lock()
	var have = songs.get(key)
	var p = params.get(key)
	mutex.unlock()
	if have:
		return have
	if p == null:
		return null
	var w: AudioStreamWAV
	if web and job_key == key:
		while not job.done():
			job.render_bar()
		w = job.finish()
		job = null
		job_key = null
	else:
		w = Synth.new().song(p)
	mutex.lock()
	if not songs.has(key):
		songs[key] = w
	w = songs[key]
	queue.erase(key)
	mutex.unlock()
	return w


func has_song(key: String) -> bool:
	return songs.has(key)


func play(key: String, restart: bool) -> void:
	if str(current) == key and music.playing and not restart:
		return
	current = key
	mutex.lock()
	var p = params.get(key, {})
	mutex.unlock()
	bpm = float(p.get("bpm", 112))
	music.stream_paused = false
	if not Save.setting("music"):
		music.stop()
		return
	if web and not unlocked:
		return  # started on the first click instead (see _input)
	var s := _song(key)
	if s == null:
		music.stop()
		return
	music.stream = s
	music.play()


func play_menu() -> void:
	var key := "theme:%d" % Save.skin("theme")
	play(key, false)


func play_level(p: Dictionary) -> void:
	register(p.key, p)
	play(p.key, true)


func stop_music() -> void:
	music.stop()


func pause_music(p: bool) -> void:
	music.stream_paused = p


func apply_volume() -> void:
	music.volume_db = linear_to_db(maxf(0.001, float(Save.setting("music_vol")))) - 4.0
	for p in players:
		p.volume_db = linear_to_db(maxf(0.001, float(Save.setting("sfx_vol")))) - 3.0


func music_setting_changed() -> void:
	if Save.setting("music") and current != null:
		var key = current
		current = null
		play(key, true)
	else:
		music.stop()


func sfx(name: String) -> void:
	if not Save.setting("sfx") or (web and not unlocked):
		return
	var bank: Dictionary = effects_retro if Save.has_extra("sfx_retro") else effects
	if not bank.has(name):
		return
	var pick: AudioStreamPlayer = players[0]
	for p in players:
		if not p.playing:
			pick = p
			break
	pick.stream = bank[name]
	pick.play()


## 1.0 right on the beat, fading to 0 before the next one. Used to pulse the scenery.
func beat_pulse() -> float:
	var pos: float
	if music.playing and not music.stream_paused:
		pos = music.get_playback_position() + AudioServer.get_time_since_last_mix()
	else:
		pos = Time.get_ticks_msec() / 1000.0
	return exp(-fposmod(pos * bpm / 60.0, 1.0) * 6.0)
