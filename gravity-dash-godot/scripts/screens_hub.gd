extends RefCounted
## The Explore hub (a 5 x 3 grid of tiles) and every screen behind it.

const Levels = preload("res://scripts/levels.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Skins = preload("res://scripts/skins.gd")
const Tile = preload("res://scripts/ui/tile.gd")
const Widget = preload("res://scripts/ui/widgets.gd")
const LevelCard = preload("res://scripts/ui/level_card.gd")
const FONT = preload("res://fonts/Fredoka-Bold.ttf")

var m  # main.gd
var forge_state := {"name": "My Level", "tier": 1, "length": 1, "pace": 1, "mech": ["pad"], "seed": 0}
var search_tier := 2


func _init(main) -> void:
	m = main


static func today() -> String:
	return Time.get_date_string_from_system()


static func week() -> String:
	return "w%d" % int((Time.get_unix_time_from_system() + 259200) / 604800.0)


static func secs_to_midnight() -> int:
	var d := Time.get_time_dict_from_system()
	return 86400 - (int(d.hour) * 3600 + int(d.minute) * 60 + int(d.second))


static func secs_to_week_end() -> int:
	return 604800 - int(fposmod(Time.get_unix_time_from_system() + 259200, 604800.0))


# ---------- Hub ----------

func show_hub() -> void:
	var root: Control = m.new_screen("hub")
	m.frame(root, "Explore", m.show_menu, Color("ffb13d"))
	var center: CenterContainer = m.center_box(root, 60.0)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	center.add_child(grid)
	var claimable := 0
	for q in Save.data.quests:
		if Save.quest_progress(q) >= int(q.n):
			claimable += 1
	var stars := Save.stat("stars")
	var done := Save.stat("completions")
	var chest_ready := Save.chest_wait("small") == 0 or Save.chest_wait("big") == 0
	var tiles := [
		["forge", "Forge", Color("3fb3a0"), false, show_forge, ""],
		["saved", "Saved", Color("7ad35a"), false, show_saved, ""],
		["scores", "Records", Color("5ab0e0"), false, show_records, ""],
		["quests", "Quests", Color("7ad35a"), false, show_quests, str(claimable) if claimable > 0 else ""],
		["ghost", "Ghost Race", Color("9a7aff"), done < 1, show_ghost, ""],
		["map", "Star Map", Color("d9a55a"), false, show_map, ""],
		["daily", "Daily", Color("ffb13d"), false, show_daily, "" if Save.is_done(Levels.daily_params(today()).key) else "!"],
		["weekly", "Weekly", Color("ff6a8a"), stars < 5, show_weekly, ""],
		["event", "Event", Color("ffcf3d"), done < 3, show_event, ""],
		["trials", "Trials", Color("e0653d"), stars < 10, show_trials, ""],
		["featured", "Featured", Color("7ad35a"), false, show_featured, ""],
		["bonus", "Chests", Color("c98a4b"), false, show_chests, "!" if chest_ready else ""],
		["paths", "Paths", Color("5ab0e0"), false, show_paths, ""],
		["packs", "Packs", Color("b07aff"), false, show_packs, ""],
		["search", "Search", Color("3fb3a0"), false, show_search, ""],
	]
	var hints := {"Ghost Race": "Complete a main level to race your ghost.", "Weekly": "Collect 5 stars to unlock weekly levels.",
		"Event": "Complete 3 main levels to unlock events.", "Trials": "Collect 10 stars to unlock the trials."}
	var note: Label = m.label("", 22, Color(1, 1, 1, 0.8), 7)
	for t in tiles:
		var tl = Tile.new()
		var locked: bool = t[3]
		var fn: Callable = t[4]
		var name: String = t[1]
		var on_click := func():
			if locked:
				note.text = hints.get(name, "Locked")
			else:
				m.go(fn)
		tl.hub(t[0], name, t[2], locked, on_click, 158.0)
		tl.badge = t[5]
		grid.add_child(tl)
	root.add_child(note)
	m.pin(note, Control.PRESET_CENTER_BOTTOM, 14)


# ---------- Shared pieces ----------

## A list row: face, name, best %, coins, then Play (and Practice) buttons.
func _row(p: Dictionary, back: Callable, won_cb := Callable(), extra := "") -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var w = Widget.new()
	w.kind = "row"
	w.lv = {"p": p}
	w.custom_minimum_size = Vector2(520, 46)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(w)
	if extra != "":
		var l: Label = m.label(extra, 18, Color(1, 1, 1, 0.7), 5)
		l.custom_minimum_size = Vector2(90, 0)
		h.add_child(l)
	h.add_child(m.button("round", Color("8ee53f"), "play", "", Vector2(56, 46), func(): m.start_level(p, false, back, won_cb)))
	h.add_child(m.button("round", Color("7ee0c8"), "restart", "", Vector2(56, 46), func(): m.start_level(p, true, back, won_cb)))
	return h


func _scroll_list(root: Control, size := Vector2(780, 470), top := 90.0) -> VBoxContainer:
	var center: CenterContainer = m.center_box(root, top)
	var pnl: PanelContainer = m.panel(Vector2(0, 0))
	center.add_child(pnl)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func _single(root: Control, p: Dictionary, sub: String, info: String, back: Callable) -> void:
	var center: CenterContainer = m.center_box(root, 40.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var card = LevelCard.new()
	card.custom_minimum_size = Vector2(820, 310)
	card.set_level(Levels.build(p), 0, sub)
	card.chosen.connect(func(): m.start_level(p, false, back))
	v.add_child(card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(m.button("round", Color("8ee53f"), "play", "Play", Vector2(210, 62), func(): m.start_level(p, false, back)))
	row.add_child(m.button("round", Color("7ee0c8"), "restart", "Practice", Vector2(230, 62), func(): m.start_level(p, true, back)))
	var l: Label = m.label(info, 22, Color(1, 1, 1, 0.8), 7)
	v.add_child(l)
	Audio.register(p.key, p)
	Audio.prefetch(p.key)


# ---------- Daily, weekly, event ----------

func show_daily() -> void:
	var root: Control = m.new_screen("daily")
	m.frame(root, "Daily Level", show_hub, Color("ffb13d"))
	var p := Levels.daily_params(today())
	var done := Save.is_done(p.key)
	_single(root, p, "TODAY  " + today(), ("Beaten! " if done else "Reward: 100 shards + 2 prisms.  ") + "New level in " + m.fmt_wait(secs_to_midnight()), show_daily)


func show_weekly() -> void:
	var root: Control = m.new_screen("weekly")
	m.frame(root, "Weekly Demon", show_hub, Color("ff6a8a"))
	var p := Levels.weekly_params(week())
	var done := Save.is_done(p.key)
	_single(root, p, "THIS WEEK", ("Beaten! " if done else "Reward: 300 shards + 5 prisms.  ") + "New level in " + m.fmt_wait(secs_to_week_end()), show_weekly)


func show_event() -> void:
	var root: Control = m.new_screen("event")
	m.frame(root, "Event: Gravity Rush", show_hub, Color("ffcf3d"))
	var p := Levels.event_params(week())
	_single(root, p, "SPEEDS UP EVERY 10 SECTIONS", "A long run that keeps getting faster. Reward: 250 shards.  Changes in " + m.fmt_wait(secs_to_week_end()), show_event)


# ---------- Featured, saved, search ----------

func show_featured() -> void:
	var root: Control = m.new_screen("featured")
	m.frame(root, "Featured", show_hub, Color("ffd34d"))
	var v := _scroll_list(root)
	for i in Levels.FEATURED.size():
		v.add_child(_row(Levels.featured_params(i), show_featured))


func show_saved() -> void:
	var root: Control = m.new_screen("saved")
	m.frame(root, "Saved Levels", show_hub, Color("7ad35a"))
	var v := _scroll_list(root)
	if Save.data.forge.is_empty():
		v.add_child(m.label("Nothing saved yet. Build a level in the Forge and it appears here.", 22, Color(1, 1, 1, 0.75), 6))
	for i in Save.data.forge.size():
		var f: Dictionary = Save.data.forge[i]
		var h: Control = _row(Levels.forge_params(f), show_saved)
		var idx: int = i
		h.add_child(m.button("round", Color("ff5c5c"), "", "X", Vector2(46, 46), func():
			Save.data.forge.remove_at(idx)
			Save.save_data()
			m.go(show_saved)))
		v.add_child(h)


func show_search() -> void:
	var root: Control = m.new_screen("search")
	m.frame(root, "Search", show_hub, Color("3fb3a0"))
	var center: CenterContainer = m.center_box(root, 70.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	v.add_child(m.label("Type any words. Every phrase grows its own level.", 22, Color(1, 1, 1, 0.8), 6))
	var input := LineEdit.new()
	input.placeholder_text = "for example: purple thunder"
	input.custom_minimum_size = Vector2(560, 56)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_override("font", FONT)
	input.add_theme_font_size_override("font_size", 26)
	input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(input)
	var tiers := HBoxContainer.new()
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers.add_theme_constant_override("separation", 8)
	v.add_child(tiers)
	var result_box := VBoxContainer.new()
	v.add_child(result_box)
	var go_search := func(_t = ""):
		for c in result_box.get_children():
			c.queue_free()
		var q: String = input.text.strip_edges()
		if q == "":
			return
		var p := Levels.search_params(q, search_tier)
		result_box.add_child(_row(p, show_search))
	for t in 6:
		var tt := t
		var b = m.button("round", Color(Skins.TIER_COLORS[t]) if t == search_tier else Color(Skins.TIER_COLORS[t]).darkened(0.45),
			"", Skins.TIER_NAMES[t], Vector2(120, 48), func():
				search_tier = tt
				m.go(show_search))
		b.font_size = 20
		tiers.add_child(b)
	input.text_submitted.connect(go_search)
	v.add_child(m.button("round", Color("3fb3a0"), "search", "Find level", Vector2(260, 60), go_search))


# ---------- Forge ----------

func show_forge() -> void:
	var root: Control = m.new_screen("forge")
	m.frame(root, "The Forge", show_hub, Color("3fb3a0"))
	var f := forge_state
	if int(f.seed) == 0:
		f.seed = randi() % 900000 + 1000
	var center: CenterContainer = m.center_box(root, 70.0)
	var pnl: PanelContainer = m.panel(Vector2(820, 0))
	center.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pnl.add_child(v)
	var name_edit := LineEdit.new()
	name_edit.text = str(f.name)
	name_edit.max_length = 22
	name_edit.custom_minimum_size = Vector2(420, 50)
	name_edit.add_theme_font_override("font", FONT)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.text_changed.connect(func(t): f.name = t)
	var nh := HBoxContainer.new()
	nh.add_child(_field("Name"))
	nh.add_child(name_edit)
	v.add_child(nh)
	v.add_child(_choice("Difficulty", Skins.TIER_NAMES, int(f.tier), func(i): f.tier = i))
	v.add_child(_choice("Length", ["Short", "Medium", "Long"], int(f.length), func(i): f.length = i))
	v.add_child(_choice("Pace", ["Relaxed", "Normal", "Fast"], int(f.pace), func(i): f.pace = i))
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 8)
	mh.add_child(_field("Objects"))
	for mech in Levels.ALL_MECH:
		var on: bool = mech in f.mech
		var mm: String = mech
		var b = m.button("round", Color("7ee04a") if on else Color("4a4a5a"), "", LevelCard.MECH_NAMES[mech], Vector2(92, 46), func():
			if mm in f.mech:
				f.mech.erase(mm)
			else:
				f.mech.append(mm)
			m.go(show_forge))
		b.font_size = 18
		mh.add_child(b)
	v.add_child(mh)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	sh.add_child(_field("Seed"))
	sh.add_child(m.label(str(f.seed), 26, Color("bdf1ff"), 7))
	sh.add_child(m.button("round", Color("ffb13d"), "restart", "Reroll", Vector2(170, 48), func():
		f.seed = randi() % 900000 + 1000
		m.go(show_forge)))
	v.add_child(sh)
	var status: Label = m.label("Build it, then beat it to save it to your Saved list.", 20, Color(1, 1, 1, 0.7), 6)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(m.button("round", Color("8ee53f"), "forge", "Build & play", Vector2(280, 64), func():
		var snap: Dictionary = f.duplicate(true)
		if str(snap.name).strip_edges() == "":
			snap.name = "Untitled"
		m.start_level(Levels.forge_params(snap), false, show_forge, func(_res): _save_forged(snap))))
	v.add_child(status)


func _save_forged(f: Dictionary) -> void:
	for g in Save.data.forge:
		if int(g.seed) == int(f.seed):
			return
	Save.data.forge.append(f)
	Save.add_stat("forge", 1)
	Save.save_data()
	forge_state.seed = 0


func _field(t: String) -> Label:
	var l: Label = m.label(t, 22, Color(1, 1, 1, 0.75), 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(130, 0)
	return l


func _choice(title: String, names: Array, sel: int, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_field(title))
	for i in names.size():
		var ii := i
		var b = m.button("round", Color("5ab0e0") if i == sel else Color("4a4a5a"), "", str(names[i]), Vector2(100, 46), func():
			cb.call(ii)
			m.go(show_forge))
		b.font_size = 18
		h.add_child(b)
	return h


# ---------- Records ----------

func show_records() -> void:
	var root: Control = m.new_screen("records")
	m.frame(root, "Records", show_hub, Color("5ab0e0"))
	var v := _scroll_list(root, Vector2(820, 470))
	var head := HBoxContainer.new()
	for t in [["Level", 300], ["Best", 90], ["Practice", 110], ["Fastest", 120], ["Tries", 90], ["Coins", 90]]:
		var l: Label = m.label(str(t[0]), 20, Color("ffd34d"), 6)
		l.custom_minimum_size = Vector2(t[1], 0)
		head.add_child(l)
	v.add_child(head)
	for i in Levels.main_count():
		var p := Levels.main_params(i)
		var rec: Dictionary = Save.level(p.key) if Save.has_level(p.key) else {}
		var h := HBoxContainer.new()
		var coins := 0
		for c in rec.get("coins", []):
			if c:
				coins += 1
		var cells := [[str(p.name), 300], ["%d%%" % int(rec.get("best", 0)), 90], ["%d%%" % int(rec.get("practice", 0)), 110],
			[LevelCard.fmt_time(float(rec.get("time", 0.0))), 120], [str(int(rec.get("attempts", 0))), 90], ["%d / 3" % coins, 90]]
		for cell in cells:
			var l: Label = m.label(str(cell[0]), 19, Color("8ee53f") if rec.get("done", false) else Color.WHITE, 5)
			l.custom_minimum_size = Vector2(cell[1], 0)
			h.add_child(l)
		v.add_child(h)


# ---------- Quests ----------

func show_quests() -> void:
	var root: Control = m.new_screen("quests")
	m.frame(root, "Quests", show_hub, Color("7ad35a"))
	var center: CenterContainer = m.center_box(root, 80.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	for i in Save.data.quests.size():
		var q: Dictionary = Save.data.quests[i]
		var pnl: PanelContainer = m.panel(Vector2(760, 0))
		v.add_child(pnl)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		pnl.add_child(h)
		var left := VBoxContainer.new()
		left.custom_minimum_size = Vector2(430, 0)
		h.add_child(left)
		var title: Label = m.label(str(q.text), 26, Color.WHITE, 7)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(title)
		var bar = Widget.new()
		bar.kind = "progress"
		bar.value = int(100.0 * Save.quest_progress(q) / maxf(1.0, float(q.n)))
		bar.color = Color("7ee04a")
		bar.custom_minimum_size = Vector2(420, 28)
		left.add_child(bar)
		var prog: Label = m.label("%d / %d    Reward %d shards" % [Save.quest_progress(q), int(q.n), int(q.reward)], 18, Color(1, 1, 1, 0.7), 5)
		prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(prog)
		var idx: int = i
		var ready := Save.quest_progress(q) >= int(q.n)
		h.add_child(m.button("round", Color("ffd34d") if ready else Color("4a4a5a"), "", "Claim", Vector2(130, 56), func():
			if Save.claim_quest(idx):
				Audio.sfx("chest")
				m.go(show_quests)
			else:
				Audio.sfx("deny")))
		h.add_child(m.button("round", Color("5ab0e0"), "restart", "25", Vector2(110, 56), func():
			if Save.reroll_quest(idx):
				m.go(show_quests)
			else:
				Audio.sfx("deny")))
	v.add_child(m.label("Finished quests are replaced by new ones. The blue button swaps a quest for 25 shards.", 18, Color(1, 1, 1, 0.6), 5))


# ---------- Ghost race ----------

func show_ghost() -> void:
	var root: Control = m.new_screen("ghost")
	m.frame(root, "Ghost Race", show_hub, Color("b9a6ff"))
	var v := _scroll_list(root, Vector2(820, 440), 120.0)
	var info: Label = m.label("Race the ghost of your best run. Levels you have a ghost for are listed here.", 22, Color(1, 1, 1, 0.8), 6)
	root.add_child(info)
	m.pin(info, Control.PRESET_CENTER_TOP, 84)
	if not Save.setting("ghost"):
		Save.set_setting("ghost", true)
	var any := false
	for i in Levels.main_count():
		var p := Levels.main_params(i)
		if Save.ghost(p.key).size() > 0:
			v.add_child(_row(p, show_ghost))
			any = true
	if not any:
		v.add_child(m.label("No ghosts yet. Set a new best on any main level to record one.", 22, Color(1, 1, 1, 0.7), 6))


# ---------- Star map ----------

func show_map() -> void:
	var root: Control = m.new_screen("map")
	m.frame(root, "Star Map", show_hub, Color("e9d9b0"))
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 100
	sc.offset_bottom = -40
	var map := MapView.new()
	map.main = m
	map.custom_minimum_size = Vector2(160 + Levels.main_count() * 150, 500)
	sc.add_child(map)
	var tip: Label = m.label("Click a star to open that level. Scroll sideways to see the whole map.", 20, Color(1, 1, 1, 0.7), 6)
	root.add_child(tip)
	m.pin(tip, Control.PRESET_CENTER_BOTTOM, 10)
	await m.get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_horizontal = maxi(0, int(80 + m.page * 150 - 500))


class MapView extends Control:
	var main
	var t := 0.0
	const LV = preload("res://scripts/levels.gd")
	const SK = preload("res://scripts/skins.gd")
	const F = preload("res://fonts/Fredoka-Bold.ttf")

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _pos(i: int) -> Vector2:
		return Vector2(100 + i * 150, size.y * 0.5 + sin(i * 1.3) * 120.0)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for i in LV.main_count():
				if e.position.distance_to(_pos(i)) < 40.0:
					main.page = i
					Audio.sfx("click")
					main.go(main.show_levels)
					accept_event()
					return

	func _draw() -> void:
		var n := LV.main_count()
		for i in n - 1:
			var a := _pos(i)
			var b := _pos(i + 1)
			var done := Save.is_done(LV.main_params(i).key)
			for k in 10:
				var q := a.lerp(b, (k + 0.5) / 10.0)
				draw_circle(q, 3.0, Color("ffe08a") if done else Color(1, 1, 1, 0.25))
		for i in n:
			var p: Dictionary = LV.main_params(i)
			var c := _pos(i)
			var done := Save.is_done(p.key)
			var pulse := 1.0 + (sin(t * 3.0) * 0.08 if i == main.page else 0.0)
			draw_circle(c, 34.0 * pulse, Color(0.05, 0.03, 0.12))
			draw_circle(c, 29.0 * pulse, Color(SK.TIER_COLORS[int(p.tier)]) if done else Color(SK.TIER_COLORS[int(p.tier)]).darkened(0.55))
			if done:
				SK.symbol(self, "star", c, 15.0)
			else:
				draw_string(F, c + Vector2(-30, 9), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 60, 24, Color.WHITE)
			draw_string_outline(F, c + Vector2(-70, 58), str(p.name), HORIZONTAL_ALIGNMENT_CENTER, 140, 17, 5, Color(0.05, 0.03, 0.12))
			draw_string(F, c + Vector2(-70, 58), str(p.name), HORIZONTAL_ALIGNMENT_CENTER, 140, 17, Color.WHITE)


# ---------- Trials ----------

func show_trials() -> void:
	var root: Control = m.new_screen("trials")
	m.frame(root, "Trials", show_hub, Color("ff8a5c"))
	var center: CenterContainer = m.center_box(root, 80.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	center.add_child(grid)
	var stars := Save.stat("stars")
	for t in Levels.TRIALS.size():
		var tr: Dictionary = Levels.TRIALS[t]
		var pnl: PanelContainer = m.panel(Vector2(560, 0), Levels.palette(float(tr.hue)).accent)
		grid.add_child(pnl)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		pnl.add_child(v)
		var locked := stars < float(tr.stars)
		v.add_child(m.label(str(tr.name) + ("  (locked)" if locked else ""), 28, Levels.palette(float(tr.hue)).accent, 8))
		if locked:
			v.add_child(m.label("Collect %d stars to enter." % int(tr.stars), 20, Color(1, 1, 1, 0.7), 5))
			continue
		var all_done := true
		for j in 3:
			var p := Levels.trial_params(t, j)
			var done := Save.is_done(p.key)
			all_done = all_done and done
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var l: Label = m.label(("Done  " if done else "") + str(p.name), 22, Color("8ee53f") if done else Color.WHITE, 6)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.custom_minimum_size = Vector2(300, 0)
			h.add_child(l)
			h.add_child(m.label("%d%%" % Save.best(p.key), 20, Color(1, 1, 1, 0.75), 5))
			h.add_child(m.button("round", Color("8ee53f"), "play", "", Vector2(56, 42), func(): m.start_level(p, false, show_trials)))
			h.add_child(m.button("round", Color("7ee0c8"), "restart", "", Vector2(56, 42), func(): m.start_level(p, true, show_trials)))
			v.add_child(h)
		var id := "trial:%d" % t
		if Save.claimed(id):
			v.add_child(m.label("Reward claimed: icon, 400 shards, 5 prisms", 18, Color("ffd34d"), 5))
		elif all_done:
			var tt := t
			v.add_child(m.button("round", Color("ffd34d"), "bonus", "Claim reward", Vector2(260, 52), func():
				Save.claim("trial:%d" % tt)
				Save.add_stat("trials", 1)
				Save.give("shards", 400)
				Save.give("prisms", 5)
				Audio.sfx("chest")
				m.go(show_trials)))
		else:
			v.add_child(m.label("Beat all three for an exclusive icon, 400 shards and 5 prisms.", 18, Color(1, 1, 1, 0.65), 5))


# ---------- Chests ----------

func show_chests() -> void:
	var root: Control = m.new_screen("chests")
	m.frame(root, "Chests", show_hub, Color("e0a35a"))
	var center: CenterContainer = m.center_box(root, 80.0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 60)
	center.add_child(h)
	for kind in ["small", "big"]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		h.add_child(v)
		var ch = Widget.new()
		ch.kind = "chest"
		ch.idx = 0 if kind == "small" else 1
		ch.ready_glow = Save.chest_wait(kind) == 0
		ch.custom_minimum_size = Vector2(260, 220)
		v.add_child(ch)
		v.add_child(m.label("Small chest (every 4 hours)" if kind == "small" else "Big chest (every day)", 22, Color.WHITE, 6))
		var wait := Save.chest_wait(kind)
		var status: Label = m.label(m.fmt_wait(wait), 26, Color("8ee53f") if wait == 0 else Color(1, 1, 1, 0.7), 7)
		v.add_child(status)
		var kk: String = kind
		v.add_child(m.button("round", Color("ffd34d") if wait == 0 else Color("4a4a5a"), "bonus", "Open", Vector2(200, 58), func():
			var r: Dictionary = Save.open_chest(kk)
			if r.is_empty():
				Audio.sfx("deny")
				return
			Audio.sfx("chest")
			status.text = "+%d shards%s" % [int(r.shards), ("  +%d prisms" % int(r.prisms)) if int(r.prisms) > 0 else ""]
			status.add_theme_color_override("font_color", Color("ffd34d"))
			ch.ready_glow = false))


# ---------- Paths ----------

func show_paths() -> void:
	var root: Control = m.new_screen("paths")
	m.frame(root, "Paths", show_hub, Color("5ab0e0"))
	var center: CenterContainer = m.center_box(root, 80.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	for path in Catalog.PATHS:
		var pnl: PanelContainer = m.panel(Vector2(900, 0))
		v.add_child(pnl)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		pnl.add_child(h)
		var val := Save.stat(path.stat)
		var name_l: Label = m.label("%s\n%s" % [path.name, m.fmt(val)], 22, Color.WHITE, 6)
		name_l.custom_minimum_size = Vector2(220, 0)
		h.add_child(name_l)
		for k in 5:
			var goal: int = path.steps[k]
			var id := "path:%s:%d" % [path.id, k]
			var reached := val >= goal
			var got := Save.claimed(id)
			var txt: String = ("Got" if got else m.fmt(goal)) + "\n" + ("+icon" if k == 4 else "+%d" % Catalog.PATH_REWARDS[k])
			var kk := k
			var b = m.button("round", Color("8ee53f") if got else (Color("ffd34d") if reached else Color("4a4a5a")), "", txt, Vector2(120, 64), func():
				if reached and not got:
					Save.claim(id)
					Save.give("shards", Catalog.PATH_REWARDS[kk])
					Audio.sfx("chest")
					m.go(show_paths)
				else:
					Audio.sfx("deny"))
			b.font_size = 17
			h.add_child(b)


# ---------- Packs ----------

func show_packs() -> void:
	var root: Control = m.new_screen("packs")
	m.frame(root, "Level Packs", show_hub, Color("c9a6ff"))
	var v := _scroll_list(root, Vector2(860, 480))
	for i in Levels.PACKS.size():
		var pk: Dictionary = Levels.PACKS[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		var done := 0
		var names := PackedStringArray()
		for li in pk.levels:
			var p := Levels.main_params(int(li))
			names.append(str(p.name))
			if Save.is_done(p.key):
				done += 1
		var l: Label = m.label("%s   %d / %d\n%s" % [pk.name, done, pk.levels.size(), ", ".join(names)], 20, Levels.palette(float(pk.hue)).accent, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.custom_minimum_size = Vector2(560, 0)
		h.add_child(l)
		var id := "pack:%d" % i
		var complete: bool = done == pk.levels.size()
		var reward := int(pk.shards)
		var first_left := -1
		for li in pk.levels:
			if not Save.is_done(Levels.main_params(int(li)).key):
				first_left = int(li)
				break
		if Save.claimed(id):
			h.add_child(m.label("Claimed", 22, Color("8ee53f"), 6))
		elif complete:
			h.add_child(m.button("round", Color("ffd34d"), "", "+%d" % reward, Vector2(130, 52), func():
				Save.claim(id)
				Save.give("shards", reward)
				Audio.sfx("chest")
				m.go(show_packs)))
		else:
			h.add_child(m.button("round", Color("8ee53f"), "play", "Next", Vector2(130, 52), func(): m.play_main(first_left, false)))
