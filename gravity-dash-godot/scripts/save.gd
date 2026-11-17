extends Node
## Autoload "Save": progress per level, lifetime statistics, the chosen skin and settings.
## Stored as JSON in user://gravity_dash_save.json.

const Levels = preload("res://scripts/levels.gd")
const Skins = preload("res://scripts/skins.gd")
const PATH := "user://gravity_dash_save.json"

var data: Dictionary = {}
var _dirty := false
var _since_save := 0.0


func _ready() -> void:
	data = _defaults()
	_load()


func _process(delta: float) -> void:
	_since_save += delta
	if _dirty and _since_save > 10.0:
		save_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_data()


func _defaults() -> Dictionary:
	var best := []
	var done := []
	var att := []
	var times := []
	for i in Levels.DEFS.size():
		best.append(0)
		done.append(false)
		att.append(0)
		times.append(0.0)
	return {
		"best": best, "done": done, "level_attempts": att, "best_time": times,
		"stats": {"attempts": 0, "flips": 0, "deaths": 0, "perfect": 0, "time": 0.0, "distance": 0.0, "clears": 0},
		"skin": {"icon": 0, "c1": 0, "c2": 1},
		"settings": {"music": true, "sfx": true},
	}


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var p = JSON.parse_string(f.get_as_text())
	if not (p is Dictionary):
		return
	for key in ["best", "done", "level_attempts", "best_time"]:
		if p.get(key) is Array:
			var src: Array = p[key]
			for i in mini(src.size(), data[key].size()):
				data[key][i] = src[i]
	for sect in ["stats", "skin", "settings"]:
		if p.get(sect) is Dictionary:
			for k in p[sect]:
				if data[sect].has(k):
					data[sect][k] = p[sect][k]


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	_dirty = false
	_since_save = 0.0


# ---------- Statistics ----------

func stat(name: String) -> float:
	match name:
		"completions":
			var n := 0
			for d in data.done:
				if d:
					n += 1
			return n
		"stars":
			var n := 0
			for i in data.done.size():
				if data.done[i]:
					n += int(Levels.DEFS[i].stars)
			return n
	return float(data.stats.get(name, 0))


func add_stat(name: String, v: float) -> void:
	data.stats[name] = float(data.stats.get(name, 0)) + v
	_dirty = true


func best(i: int) -> int:
	return int(data.best[i])


func is_done(i: int) -> bool:
	return bool(data.done[i])


func level_attempts(i: int) -> int:
	return int(data.level_attempts[i])


func best_time(i: int) -> float:
	return float(data.best_time[i])


func add_level_attempt(i: int) -> void:
	data.level_attempts[i] = level_attempts(i) + 1
	_dirty = true


func record_progress(i: int, pct: int) -> bool:
	if pct > best(i):
		data.best[i] = pct
		_dirty = true
		return true
	return false


func record_complete(i: int, flips: int, time: float) -> Dictionary:
	var before := unlocked_list()
	var first := not is_done(i)
	var perfect := first and level_attempts(i) <= 1
	data.best[i] = 100
	data.done[i] = true
	if best_time(i) <= 0.0 or time < best_time(i):
		data.best_time[i] = time
	add_stat("clears", 1)
	if perfect:
		add_stat("perfect", 1)
	var unlocks := []
	for n in unlocked_list():
		if not n in before:
			unlocks.append(n)
	save_data()
	return {"first": first, "stars": int(Levels.DEFS[i].stars) if first else 0, "perfect": perfect, "unlocks": unlocks, "flips": flips, "time": time}


# ---------- Unlocks and skin ----------

func unlocked(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	return stat(req.stat) >= float(req.n)


func req_text(req: Dictionary) -> String:
	if req.is_empty():
		return ""
	return "%s  (%d / %d)" % [req.text, mini(int(stat(req.stat)), int(req.n)), int(req.n)]


func unlocked_list() -> Array:
	var out := []
	for k in Skins.ICONS.size():
		if unlocked(Skins.ICONS[k].req):
			out.append("Icon: " + str(Skins.ICONS[k].name))
	for k in Skins.COLORS.size():
		if unlocked(Skins.COLORS[k].req):
			out.append("Colour %d" % (k + 1))
	return out


func count_unlocked(list: Array) -> int:
	var n := 0
	for item in list:
		if unlocked(item.req):
			n += 1
	return n


func icon() -> int:
	return int(data.skin.icon)


func c1() -> Color:
	return Color(Skins.COLORS[int(data.skin.c1)].hex)


func c2() -> Color:
	return Color(Skins.COLORS[int(data.skin.c2)].hex)


func set_skin(key: String, idx: int) -> void:
	data.skin[key] = idx
	save_data()


# ---------- Settings ----------

func setting(name: String) -> bool:
	return bool(data.settings.get(name, true))


func toggle(name: String) -> bool:
	data.settings[name] = not setting(name)
	save_data()
	return setting(name)
