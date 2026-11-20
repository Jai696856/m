extends Node

signal changed
signal toast(title: String, text: String)

const Levels = preload("res://scripts/levels.gd")
const Catalog = preload("res://scripts/catalog.gd")
const PATH:= "user://gravity_dash_save.json"
const OLD_ORDER:= ["Lift Off", "Double Back", "Hard Ceiling", "Polar Shift", "Upside Town", "Neon Gravity", "Saw Mill",
	"Flipside", "Static Drift", "Zero G", "Pendulum", "Overturn", "Magnetar", "Inversion", "Event Horizon",
	"Antimatter", "Singularity", "Gravity's End"]

var data: Dictionary = {}
var _dirty:= false
var _since_save:= 0.0
var _ach_check:= 0.0

func _ready() -> void:
	data = _defaults()
	_load()
	_ensure_quests()

func _process(delta: float) -> void:
	_since_save += delta
	_ach_check += delta
	if _ach_check > 1.0:
		_ach_check = 0.0
		check_achievements()
	if _dirty and _since_save > 10.0:
		save_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_data()

func _defaults() -> Dictionary:
	return {
		"version": 2,
		"levels": {},
		"stats": {},
		"wallet": { "shards": 0, "prisms": 0 },
		"owned": {},
		"claimed": {},
		"skin": { "icon": 0, "c1": 0, "c2": 1, "trail": 1, "death": 0, "theme": 0, "glow": false },
		"settings": { "music": true, "sfx": true, "music_vol": 0.8, "sfx_vol": 0.9, "percent": true, "shake": true,
			"flash": true, "ghost": true, "low_detail": false, "auto_cp": true, "attempt_text": true },
		"quests": [],
		"chests": { "small": 0, "big": 0 },
		"forge": [],
	}

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f:= FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var p = JSON.parse_string(f.get_as_text())
	if not (p is Dictionary):
		return
	if int(p.get("version", 1)) < 2:
		_migrate(p)
		return
	for sect in ["levels", "stats", "wallet", "owned", "claimed", "chests"]:
		if p.get(sect) is Dictionary:
			data[sect].merge(p[sect], true)
	for sect in ["skin", "settings"]:
		if p.get(sect) is Dictionary:
			for k in p[sect]:
				if data[sect].has(k):
					data[sect][k] = p[sect][k]
	for sect in ["quests", "forge"]:
		if p.get(sect) is Array:
			data[sect] = p[sect]

func _migrate(p: Dictionary) -> void:
	for i in OLD_ORDER.size():
		var key:= "main:" + Levels.slug(OLD_ORDER[i])
		var rec:= level(key)
		if p.get("best") is Array and i < p.best.size():
			rec.best = int(p.best[i])
		if p.get("done") is Array and i < p.done.size() and p.done[i]:
			rec.done = true
		if p.get("level_attempts") is Array and i < p.level_attempts.size():
			rec.attempts = int(p.level_attempts[i])
		if p.get("best_time") is Array and i < p.best_time.size():
			rec.time = float(p.best_time[i])
	if p.get("stats") is Dictionary:
		data.stats.merge(p.stats, true)
	if p.get("settings") is Dictionary:
		for k in p.settings:
			if data.settings.has(k):
				data.settings[k] = p.settings[k]
	if p.get("skin") is Dictionary:
		for k in p.skin:
			if data.skin.has(k):
				data.skin[k] = p.skin[k]
	_dirty = true

func save_data() -> void:
	var f:= FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	_dirty = false
	_since_save = 0.0

func reset_all() -> void:
	data = _defaults()
	_ensure_quests()
	save_data()
	changed.emit()

func level(key: String) -> Dictionary:
	if not data.levels.has(key):
		data.levels[key] = { "best": 0, "practice": 0, "attempts": 0, "done": false, "time": 0.0, "coins": [false, false, false], "stars": 0 }
	return data.levels[key]

func has_level(key: String) -> bool:
	return data.levels.has(key)

func best(key: String) -> int:
	return int(level(key).best) if has_level(key) else 0

func is_done(key: String) -> bool:
	return has_level(key) and bool(level(key).done)

func coins_of(key: String) -> Array:
	return level(key).coins if has_level(key) else [false, false, false]

func stat(name: String) -> float:
	match name:
		"completions":
			var n:= 0
			for i in Levels.main_count():
				if is_done(Levels.main_params(i).key):
					n += 1
			return n
		"stars":
			var n:= 0
			for k in data.levels:
				if data.levels[k].done:
					n += int(data.levels[k].get("stars", 0))
			return n
		"coins":
			var n:= 0
			for k in data.levels:
				for c in data.levels[k].get("coins", []):
					if c:
						n += 1
			return n
	return float(data.stats.get(name, 0))

func add_stat(name: String, v: float) -> void:
	data.stats[name] = float(data.stats.get(name, 0)) + v
	_dirty = true

func shards() -> int:
	return int(data.wallet.shards)

func prisms() -> int:
	return int(data.wallet.prisms)

func give(cur: String, n: int) -> void:
	if n <= 0:
		return
	data.wallet[cur] = int(data.wallet[cur]) + n
	add_stat(cur + "_earned", n)
	changed.emit()

func spend(cur: String, n: int) -> bool:
	if int(data.wallet[cur]) < n:
		return false
	data.wallet[cur] = int(data.wallet[cur]) - n
	save_data()
	changed.emit()
	return true

func record_attempt(key: String) -> void:
	level(key).attempts = int(level(key).attempts) + 1
	add_stat("attempts", 1)

func record_progress(key: String, pct: int, practice: bool) -> bool:
	var rec:= level(key)
	var field:= "practice" if practice else "best"
	if pct > int(rec[field]):
		rec[field] = pct
		_dirty = true
		return true
	return false

func record_complete(p: Dictionary, flips: int, time: float, coins: Array, shards_picked: int, practice: bool) -> Dictionary:
	var key: String = p.key
	var rec:= level(key)
	var kind: String = p.get("kind", "main")
	var res:= { "first": false, "stars": 0, "perfect": false, "shards": 0, "prisms": 0, "unlocks": [], "new_coins": 0, "practice": practice }
	var before:= unlocked_names()
	if practice:
		rec.practice = 100
		add_stat("practice", 1)
	else:
		var first:= not bool(rec.done)
		res.first = first
		res.perfect = first and int(rec.attempts) <= 1
		rec.best = 100
		rec.done = true
		rec.stars = int(p.stars)
		if float(rec.time) <= 0.0 or time < float(rec.time):
			rec.time = time
		add_stat("clears", 1)
		if res.perfect:
			add_stat("perfect", 1)
		var earned:= shards_picked + (int(p.stars) * 25 if first else 5)
		for i in 3:
			if i < coins.size() and coins[i] and not rec.coins[i]:
				rec.coins[i] = true
				res.new_coins += 1
		if first:
			res.stars = int(p.stars)
			match kind:
				"daily":
					add_stat("dailies", 1)
					earned += 100
					res.prisms += 2
				"weekly":
					add_stat("weeklies", 1)
					earned += 300
					res.prisms += 5
				"event":
					add_stat("events", 1)
					earned += 250
		res.prisms += res.new_coins
		res.shards = earned
		give("shards", earned)
		give("prisms", res.prisms)
	for n in unlocked_names():
		if not n in before:
			res.unlocks.append(n)
	save_data()
	changed.emit()
	return res

func save_ghost(key: String, pts: PackedVector2Array) -> void:
	level(key)["ghost"] = Marshalls.raw_to_base64(pts.to_byte_array())
	_dirty = true

func ghost(key: String) -> PackedVector2Array:
	if not has_level(key) or not level(key).has("ghost"):
		return PackedVector2Array()
	return _ghost_decode(str(level(key).ghost))

func _ghost_decode(b64: String) -> PackedVector2Array:
	var f:= Marshalls.base64_to_raw(b64).to_float32_array()
	var out:= PackedVector2Array()
	for i in range(0, f.size() - 1, 2):
		out.append(Vector2(f[i], f[i + 1]))
	return out

func item_src(kind: String, idx: int) -> Dictionary:
	return Catalog.list(kind)[idx].src

func owns(kind: String, idx: int) -> bool:
	var src:= item_src(kind, idx)
	if src.is_empty():
		return true
	if src.has("req"):
		return stat(src.req) >= float(src.n)
	if src.has("shop"):
		return data.owned.has("%s:%d" % [kind, idx])
	if src.has("trial"):
		return data.claimed.has("trial:%d" % int(src.trial))
	if src.has("path"):
		return data.claimed.has("path:%s:4" % src.path)
	if src.has("code"):
		return data.claimed.has("code:" + str(src.code))
	return false

func how_to_get(kind: String, idx: int) -> String:
	var src:= item_src(kind, idx)
	if src.has("req"):
		return "%s  (%d / %d)" % [src.text, mini(int(stat(src.req)), int(src.n)), int(src.n)]
	if src.has("shop"):
		return "Sold in the %s for %d %s" % [Catalog.shop(src.shop).name, int(src.price), src.cur]
	if src.has("trial"):
		return "Finish the %s" % Levels.TRIALS[int(src.trial)].name
	if src.has("path"):
		for p in Catalog.PATHS:
			if p.id == src.path:
				return "Reach the end of the %s" % p.name
	if src.has("code"):
		return "Unlocked by a secret code"
	return ""

func buy(kind: String, idx: int) -> bool:
	var src:= item_src(kind, idx)
	if owns(kind, idx) or not src.has("shop"):
		return false
	if not spend(str(src.cur), int(src.price)):
		return false
	data.owned["%s:%d" % [kind, idx]] = true
	add_stat("purchases", 1)
	save_data()
	return true

func shop_open(shop: Dictionary) -> bool:
	var u: Dictionary = shop.unlock
	return u.is_empty() or stat(u.req) >= float(u.n)

func unlocked_names() -> Array:
	var out:= []
	for kind in ["icon", "color", "trail", "death", "theme"]:
		var l: Array = Catalog.list(kind)
		for i in l.size():
			if owns(kind, i):
				out.append("%s %s" % [kind.capitalize(), l[i].get("name", "#%d" % (i + 1))])
	for s in Catalog.SHOPS:
		if shop_open(s):
			out.append("Shop " + str(s.name))
	return out

func count_owned(kind: String) -> int:
	var n:= 0
	for i in Catalog.list(kind).size():
		if owns(kind, i):
			n += 1
	return n

func has_extra(id: String) -> bool:
	return data.owned.has("extra:" + _extra_index(id))

func _extra_index(id: String) -> String:
	for i in Catalog.EXTRAS.size():
		if Catalog.EXTRAS[i].id == id:
			return str(i)
	return "-1"

func icon() -> int:
	return int(data.skin.icon)

func c1() -> Color:
	return Color(Catalog.COLORS[int(data.skin.c1)].hex)

func c2() -> Color:
	return Color(Catalog.COLORS[int(data.skin.c2)].hex)

func skin(key: String) -> int:
	return int(data.skin[key])

func set_skin(key: String, v) -> void:
	data.skin[key] = v
	save_data()
	changed.emit()

func setting(name: String):
	return data.settings.get(name, true)

func set_setting(name: String, v) -> void:
	data.settings[name] = v
	save_data()

func toggle(name: String) -> bool:
	data.settings[name] = not bool(setting(name))
	save_data()
	return bool(setting(name))

func claimed(id: String) -> bool:
	return data.claimed.has(id)

func claim(id: String) -> void:
	data.claimed[id] = true
	save_data()
	changed.emit()

func redeem_code(code: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	if not Catalog.CODES.has(code):
		return { "ok": false, "text": "Nothing happens. That isn't a code." }
	if claimed("code:" + code):
		return { "ok": false, "text": "You already used that code." }
	var r: Dictionary = Catalog.CODES[code]
	claim("code:" + code)
	add_stat("codes", 1)
	if r.has("shards"):
		give("shards", int(r.shards))
	if r.has("prisms"):
		give("prisms", int(r.prisms))
	save_data()
	return { "ok": true, "text": "Unlocked " + str(r.text) + "!" }

func check_achievements() -> void:
	for i in Catalog.ACHIEVEMENTS.size():
		var a: Array = Catalog.ACHIEVEMENTS[i]
		var id:= "ach:%d" % i
		if not claimed(id) and stat(a[2]) >= float(a[3]):
			data.claimed[id] = true
			give("shards", int(a[4]))
			_dirty = true
			toast.emit("Achievement: " + str(a[0]), "%s  +%d shards" % [a[1], int(a[4])])

func _ensure_quests() -> void:
	while data.quests.size() < 3:
		data.quests.append(_new_quest())

func _new_quest() -> Dictionary:
	var used:= []
	for q in data.quests:
		used.append(q.stat)
	var pick: Array = Catalog.QUESTS[randi() % Catalog.QUESTS.size()]
	var tries:= 0
	while pick[0] in used and tries < 20:
		pick = Catalog.QUESTS[randi() % Catalog.QUESTS.size()]
		tries += 1
	var n:= randi_range(int(pick[1]), int(pick[2]))
	return { "stat": pick[0], "base": stat(pick[0]), "n": n, "reward": maxi(20, int(round(n * float(pick[3]) / 10.0) * 10)),
		"text": str(pick[4]) % n }

func quest_progress(q: Dictionary) -> int:
	return clampi(int(stat(q.stat) - float(q.base)), 0, int(q.n))

func claim_quest(i: int) -> bool:
	var q: Dictionary = data.quests[i]
	if quest_progress(q) < int(q.n):
		return false
	give("shards", int(q.reward))
	add_stat("quests", 1)
	data.quests[i] = _new_quest()
	save_data()
	return true

func reroll_quest(i: int) -> bool:
	if not spend("shards", 25):
		return false
	data.quests[i] = _new_quest()
	save_data()
	return true

func chest_wait(kind: String) -> int:
	return maxi(0, int(data.chests.get(kind, 0)) - int(Time.get_unix_time_from_system()))

func open_chest(kind: String) -> Dictionary:
	if chest_wait(kind) > 0:
		return {}
	var big:= kind == "big"
	var r:= { "shards": randi_range(100, 220) if big else randi_range(20, 60), "prisms": (1 + randi() % 2) if big else (1 if randf() < 0.15 else 0) }
	data.chests[kind] = int(Time.get_unix_time_from_system()) + (86400 if big else 14400)
	give("shards", r.shards)
	give("prisms", r.prisms)
	add_stat("chests", 1)
	save_data()
	return r
