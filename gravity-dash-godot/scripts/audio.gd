extends Node
## Autoload "Audio": plays the generated music and sound effects.
## Songs are synthesised on a background thread so the game starts instantly.

const Synth = preload("res://scripts/synth.gd")
const Levels = preload("res://scripts/levels.gd")

var music: AudioStreamPlayer
var players: Array = []
var effects: Dictionary = {}
var songs: Dictionary = {}
var queue: Array = []
var mutex := Mutex.new()
var thread: Thread
var quitting := false
var current = null
var bpm := 112.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.volume_db = -5.0
	add_child(music)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		players.append(p)
	effects = Synth.new().effects()
	queue.append("menu")
	for i in Levels.DEFS.size():
		queue.append(i)
	thread = Thread.new()
	thread.start(_worker)


func _exit_tree() -> void:
	quitting = true
	if thread and thread.is_started():
		thread.wait_to_finish()


func _worker() -> void:
	while not quitting:
		mutex.lock()
		var key = null
		if not queue.is_empty():
			key = queue.pop_front()
		mutex.unlock()
		if key == null:
			return
		_song(key)


func _song(key) -> AudioStreamWAV:
	mutex.lock()
	var have = songs.get(key)
	mutex.unlock()
	if have:
		return have
	var d: Dictionary = Synth.MENU if key is String else Levels.DEFS[key]
	var w: AudioStreamWAV = Synth.new().song(d)
	mutex.lock()
	if not songs.has(key):
		songs[key] = w
	w = songs[key]
	queue.erase(key)
	mutex.unlock()
	return w


## Moves a song to the front of the background queue (for example when its level is shown).
func prefetch(key) -> void:
	mutex.lock()
	if not songs.has(key) and queue.has(key):
		queue.erase(key)
		queue.push_front(key)
	mutex.unlock()


func _play(key, restart: bool) -> void:
	if str(current) == str(key) and music.playing and not restart:
		return
	current = key
	bpm = float(Synth.MENU.bpm if key is String else Levels.DEFS[key].bpm)
	music.stream_paused = false
	if not Save.setting("music"):
		music.stop()
		return
	music.stream = _song(key)
	music.play()


func play_menu() -> void:
	_play("menu", false)


func play_level(i: int) -> void:
	_play(i, true)


func stop_music() -> void:
	music.stop()


func pause_music(p: bool) -> void:
	music.stream_paused = p


func music_setting_changed() -> void:
	if Save.setting("music") and current != null:
		var key = current
		current = null
		_play(key, true)
	else:
		music.stop()


func sfx(name: String) -> void:
	if not Save.setting("sfx") or not effects.has(name):
		return
	var pick: AudioStreamPlayer = players[0]
	for p in players:
		if not p.playing:
			pick = p
			break
	pick.stream = effects[name]
	pick.play()


## 1.0 right on the beat, fading to 0 before the next one. Used to pulse the scenery.
func beat_pulse() -> float:
	var pos: float
	if music.playing and not music.stream_paused:
		pos = music.get_playback_position() + AudioServer.get_time_since_last_mix()
	else:
		pos = Time.get_ticks_msec() / 1000.0
	return exp(-fposmod(pos * bpm / 60.0, 1.0) * 6.0)
