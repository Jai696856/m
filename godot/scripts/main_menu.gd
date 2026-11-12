# Title screen shown over a live "attract mode" game: player level, big PLAY
# button, daily challenge, and screens for heroes, achievements, stats,
# settings and how to play. Uses the style helpers from ui.gd.
extends Control

const Defs = preload("res://scripts/defs.gd")
const Maps = preload("res://scripts/maps.gd")
const Progress = preload("res://scripts/progress.gd")
const UIScript = preload("res://scripts/ui.gd")

const TIPS := [
	"Tip: Heroes on tier 3 of any path unlock an ability. Press Q to Q-I to use them.",
	"Tip: Veiled spirits are invisible to most heroes. Kaede and upgraded heroes can see them.",
	"Tip: Shadow Wisps shrug off explosions, Frost Wisps can't be frozen.",
	"Tip: Aiko earns money every round and makes nearby heroes stronger.",
	"Tip: Regrowing spirits heal if you leave them alone. Finish them off!",
	"Tip: Expert maps have short tracks. Place damage where spirits enter.",
	"Tip: Clay Masks take many hits. Bring bonus damage against masks.",
	"Tip: Boss rounds are announced. Save money for boss-damage upgrades.",
]

var ui
var game
var level_lbl: Label
var xp_bar: ProgressBar
var xp_lbl: Label
var daily_btn: Button
var medal_pill: Label
var trophy_pill: Label
var hero_class_i := 0
var hero_list: VBoxContainer
var hero_tabs: Array = []
var tip_lbl: Label
var screens := {}
var hero_detail: VBoxContainer
var tip_i := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_home()
	screens["heroes"] = _build_heroes()
	screens["achievements"] = _screen("ACHIEVEMENTS")
	screens["stats"] = _screen("STATS")
	screens["settings"] = _build_settings()
	screens["howto"] = _build_howto()
	var t := Timer.new()
	t.wait_time = 6.0
	t.autostart = true
	t.timeout.connect(_next_tip)
	add_child(t)

# ---------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------
func _build_home() -> void:
	# Soft bands top and bottom so buttons read over the village
	for top in [true, false]:
		var g := ColorRect.new()
		g.color = Color(0.05, 0.1, 0.25, 0.35)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.anchor_right = 1.0
		g.anchor_top = 0.0 if top else 1.0
		g.anchor_bottom = 0.0 if top else 1.0
		g.offset_bottom = 84 if top else 0
		g.offset_top = 0 if top else -150
		add_child(g)

	# Top-left: player level badge
	var badge := HBoxContainer.new()
	badge.position = Vector2(12, 8)
	badge.add_theme_constant_override("separation", 8)
	add_child(badge)
	var star := Control.new()
	star.custom_minimum_size = Vector2(70, 70)
	badge.add_child(star)
	var star_icon = UIScript.HudIcon.new("star", 70, ui.GOLD)
	star.add_child(star_icon)
	level_lbl = ui.lbl("1", 24, Color.WHITE, 8)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_lbl.size = Vector2(70, 70)
	star.add_child(level_lbl)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	badge.add_child(bv)
	bv.add_child(ui.lbl("SHRINE KEEPER", 20, Color.WHITE, 8))
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(220, 18)
	xp_bar.add_theme_stylebox_override("background", ui.sb(Color(0.15, 0.2, 0.35), 9, 3, false, 0))
	xp_bar.add_theme_stylebox_override("fill", ui.sb(Color(0.3, 0.75, 1.0), 9, 3, false, 0))
	bv.add_child(xp_bar)
	xp_lbl = ui.lbl("", 13, Color.WHITE, 5)
	bv.add_child(xp_lbl)

	# Top-centre: small logo
	var logo: Label = ui.lbl("SAKURA SPIRIT DEFENSE", 30, Color.WHITE, 12)
	logo.add_theme_color_override("font_shadow_color", ui.PINK)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.offset_top = 18
	add_child(logo)

	# Top-right: medals and trophies
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 10)
	pills.anchor_left = 1.0
	pills.anchor_right = 1.0
	pills.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pills.offset_right = -14
	pills.offset_top = 14
	add_child(pills)
	medal_pill = _pill(pills, "coin", ui.GOLD)
	trophy_pill = _pill(pills, "trophy", ui.GOLD)

	# Left column: small round buttons
	var left := _icon_column(true)
	_icon_button(left, "gear", "SETTINGS", Color(0.35, 0.5, 0.75), func() -> void: _open("settings"))
	_icon_button(left, "book", "HOW TO PLAY", Color(0.35, 0.5, 0.75), func() -> void: _open("howto"))
	if OS.has_feature("pc") and not OS.has_feature("web"):
		_icon_button(left, "door", "QUIT", Color(0.92, 0.3, 0.3), func() -> void: get_tree().quit())

	# Bottom row: big round buttons, PLAY in the middle
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -6
	add_child(row)
	_big_button(row, "", "HEROES", ui.PINK, 96, func() -> void: _open("heroes"), "ninja")
	_big_button(row, "trophy", "TROPHIES", ui.VIOLET, 96, func() -> void: _open("achievements"))
	_big_button(row, "play", "PLAY", ui.GREEN, 128, func() -> void: ui.show_map_select())
	daily_btn = _big_button(row, "calendar", "DAILY", ui.ORANGE, 96, func() -> void: game.start_daily())
	_big_button(row, "chart", "STATS", Color(0.35, 0.5, 0.75), 96, func() -> void: _open("stats"))

	tip_lbl = ui.lbl("", 15, Color.WHITE, 6)
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.anchor_left = 0.0
	tip_lbl.anchor_right = 1.0
	tip_lbl.offset_top = 92
	tip_lbl.offset_bottom = 116
	add_child(tip_lbl)
	_next_tip()

func _pill(parent: Control, icon: String, col: Color) -> Label:
	var p: PanelContainer = ui.panel_of(Color(0.1, 0.17, 0.29, 0.85), 20)
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(UIScript.HudIcon.new(icon, 30, col))
	var l: Label = ui.lbl("0", 22, Color.WHITE, 8)
	h.add_child(l)
	return l

func _icon_column(left_side: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.offset_top = -20
	if left_side:
		v.offset_left = 16
	else:
		v.anchor_left = 1.0
		v.anchor_right = 1.0
		v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		v.offset_right = -16
	add_child(v)
	return v

func _icon_button(parent: Control, icon: String, text: String, bg: Color, cb: Callable) -> Button:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", -2)
	parent.add_child(cell)
	var b: Button = ui.round_btn(bg, 64)
	b.tooltip_text = text
	ui.centered(b, UIScript.HudIcon.new(icon, 42, Color.WHITE))
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(b)
	var l: Label = ui.lbl(text, 13, Color.WHITE, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(l)
	return b

func _big_button(parent: Control, icon: String, text: String, bg: Color, px: int, cb: Callable, portrait_key: String = "") -> Button:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", -4)
	cell.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(cell)
	var b: Button = ui.round_btn(bg, px)
	b.add_theme_stylebox_override("normal", ui.sb(bg, px / 2, 4))
	b.add_theme_stylebox_override("hover", ui.sb(bg.lightened(0.15), px / 2, 4))
	if portrait_key != "":
		ui.centered(b, ui._portrait_rect(portrait_key, px * 0.85))
	else:
		ui.centered(b, UIScript.HudIcon.new(icon, px * 0.62, Color.WHITE))
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(b)
	var l: Label = ui.lbl(text, 22 if px > 100 else 18, Color.WHITE, 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(l)
	b.set_meta("label", l)
	return b

func _next_tip() -> void:
	tip_lbl.text = TIPS[tip_i % TIPS.size()]
	tip_i += 1

## Refresh level, daily challenge and achievement counts.
func refresh() -> void:
	var p = game.progress
	level_lbl.text = str(p.level())
	var lp: Vector2 = p.level_progress()
	xp_bar.max_value = lp.y
	xp_bar.value = lp.x
	xp_lbl.text = "%d / %d XP" % [int(lp.x), int(lp.y)]
	var d: Dictionary = p.daily()
	var m: Dictionary = Maps.MAPS[d["map"]]
	daily_btn.tooltip_text = "DAILY CHALLENGE\n%s - %s - %s%s" % [m["name"], String(d["diff"]).capitalize(), game.MODES[d["mode"]]["name"], "\n(completed today)" if d["done"] else ""]
	(daily_btn.get_meta("label") as Label).text = "DAILY - DONE" if d["done"] else "DAILY - NEW!"
	trophy_pill.text = "%d/%d" % [p.unlocked_count(), Progress.ACHIEVEMENTS.size()]
	var medals := 0
	for i in range(Maps.MAPS.size()):
		for dd in ["easy", "normal", "hard"]:
			if game.has_medal(i, dd, "standard"):
				medals += 1
	medal_pill.text = str(medals)

func show_home() -> void:
	for k in screens:
		(screens[k] as Control).visible = false
	refresh()
	visible = true

# ---------------------------------------------------------------------
# Sub-screens
# ---------------------------------------------------------------------
func _screen(title: String) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.12, 0.25, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card: PanelContainer = ui.panel_of(ui.NAVY, 24)
	card.custom_minimum_size = Vector2(1000, 600)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t: Label = ui.lbl(title, 44, Color.WHITE, 14)
	t.add_theme_color_override("font_shadow_color", ui.PINK)
	t.add_theme_constant_override("shadow_offset_y", 5)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back: Button = ui.btn("BACK", Color(0.35, 0.5, 0.75), 22, 14)
	back.custom_minimum_size = Vector2(140, 50)
	back.pressed.connect(show_home)
	head.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "Scroll"
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	shade.set_meta("body", body)
	shade.set_meta("card", card)
	return shade

func _body(which: String) -> VBoxContainer:
	return (screens[which] as Control).get_meta("body")

func _open(which: String) -> void:
	for k in screens:
		(screens[k] as Control).visible = k == which
	match which:
		"achievements":
			_fill_achievements()
		"stats":
			_fill_stats()
		"heroes":
			_pick_hero_class(hero_class_i)
		"settings":
			_fill_settings()

func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()

func _fill_achievements() -> void:
	var body := _body("achievements")
	_clear(body)
	var p = game.progress
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for a in Progress.ACHIEVEMENTS:
		var done: bool = p.is_unlocked(a[0])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ui.sb(ui.CARD if done else Color(0.55, 0.6, 0.7), 12, 3, false, 8))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(470, 0)
		grid.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var star := PanelContainer.new()
		star.custom_minimum_size = Vector2(40, 40)
		star.add_theme_stylebox_override("panel", ui.sb(ui.GOLD if done else Color(0.35, 0.38, 0.45), 20, 3, false, 0))
		h.add_child(star)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		v.add_child(ui.dark_lbl(a[1], 18))
		v.add_child(ui.dark_lbl(a[2], 13))
		var have := minf(p.get_stat(a[3]), float(a[4]))
		h.add_child(ui.dark_lbl("DONE" if done else "%s / %s" % [_num(have), _num(a[4])], 14))

func _fill_stats() -> void:
	var body := _body("stats")
	_clear(body)
	var p = game.progress
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var rows := [["Player level", str(p.level())], ["Total XP", _num(p.xp())], ["Achievements", "%d / %d" % [p.unlocked_count(), Progress.ACHIEVEMENTS.size()]]]
	for s in Progress.STAT_LABELS:
		var v: float = p.get_stat(s[0])
		rows.append([s[1], ("$" if s[0] == "cash_earned" else "") + _num(v)])
	var medals := 0
	for i in range(Maps.MAPS.size()):
		for d in ["easy", "normal", "hard"]:
			for m in game.MODE_ORDER:
				if game.has_medal(i, d, m):
					medals += 1
	rows.append(["Medals earned", str(medals)])
	for r in rows:
		grid.add_child(ui.lbl(r[0], 22, Color.WHITE, 8))
		grid.add_child(ui.lbl(r[1], 22, ui.GOLD, 8))

static func _num(v) -> String:
	var n := int(v)
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# Heroes: portrait list on the left, details and the full upgrade tree on the right.
func _build_heroes() -> Control:
	var sc := _screen("HEROES")
	var body: VBoxContainer = sc.get_meta("body")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for i in range(Defs.CLASSES.size()):
		var c: Dictionary = Defs.CLASSES[i]
		var tb: Button = ui.btn(c["name"], Defs.col(c["color"]).darkened(0.3), 16, 10)
		tb.custom_minimum_size = Vector2(150, 40)
		tb.pressed.connect(_pick_hero_class.bind(i))
		tabs.add_child(tb)
		hero_tabs.append(tb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	hero_list = VBoxContainer.new()
	hero_list.add_theme_constant_override("separation", 6)
	h.add_child(hero_list)
	hero_detail = VBoxContainer.new()
	hero_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_detail.add_theme_constant_override("separation", 6)
	h.add_child(hero_detail)
	return sc

func _pick_hero_class(i: int) -> void:
	hero_class_i = i
	for j in range(hero_tabs.size()):
		var col: Color = Defs.col(Defs.CLASSES[j]["color"])
		ui._set_btn_bg(hero_tabs[j], col if j == i else col.darkened(0.45), 10)
	_clear(hero_list)
	var heroes: Array = Defs.CLASSES[i]["heroes"]
	for k in heroes:
		var key: String = k
		var d: Dictionary = Defs.HEROES[key]
		var unlocked: bool = game.progress.level() >= int(Defs.UNLOCK_LEVEL[key])
		var b: Button = ui.btn("", ui.TILE if unlocked else Color(0.5, 0.55, 0.65), 14, 12)
		b.custom_minimum_size = Vector2(250, 96)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		b.add_child(row)
		var pic: TextureRect = ui._portrait_rect(key, 84)
		if not unlocked:
			pic.modulate = Color(0.25, 0.25, 0.35)
		row.add_child(pic)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		v.add_child(ui.lbl(d["name"], 22, Color.WHITE, 8))
		v.add_child(ui.lbl(d["role"], 14, Color.WHITE, 5))
		v.add_child(ui.lbl("UNLOCKED" if unlocked else "LEVEL %d" % int(Defs.UNLOCK_LEVEL[key]), 14, ui.GREEN if unlocked else ui.GOLD, 5))
		b.pressed.connect(func() -> void: _show_hero(key))
		hero_list.add_child(b)
	_show_hero(heroes[0])

func _show_hero(k: String) -> void:
	_clear(hero_detail)
	var d: Dictionary = Defs.HEROES[k]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	hero_detail.add_child(top)
	var pic := PanelContainer.new()
	pic.add_theme_stylebox_override("panel", ui.sb(ui.TILE, 14, 3, false, 0))
	pic.add_child(ui._portrait_rect(k, 120))
	top.add_child(pic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(ui.lbl("%s  -  %s" % [d["name"], d["role"]], 34, Color.WHITE, 12))
	var need := int(Defs.UNLOCK_LEVEL[k])
	if game.progress.level() < need:
		info.add_child(ui.lbl("Joins your squad at player level %d (you are level %d)" % [need, game.progress.level()], 16, ui.GOLD, 6))
	var desc: Label = ui.lbl(d["desc"], 16, Color(0.85, 0.92, 1.0), 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	info.add_child(ui.lbl("Cost $%d      Hero XP: %s" % [int(d["cost"]), _num(game.progress.hero_xp(k))], 18, ui.GOLD, 6))
	var hint: Label = ui.lbl("Earn hero XP by popping spirits with %s. Spend it below to unlock upgrades for good." % d["name"], 13, Color(0.75, 0.65, 1.0), 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(hint)
	var ab: Dictionary = game.ABILITIES[k]
	var ab_lbl: Label = ui.lbl("Ability (tier 3): %s - %s" % [ab["name"], ab["desc"]], 15, Color(1, 0.85, 0.5), 0)
	ab_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(ab_lbl)
	var paths := HBoxContainer.new()
	paths.add_theme_constant_override("separation", 8)
	hero_detail.add_child(paths)
	for p in range(3):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ui.sb(ui.CARD, 12, 3, false, 8))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		paths.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		v.add_child(ui.dark_lbl(String(d["path_names"][p]).to_upper(), 18))
		for t in range(4):
			var up: Array = d["paths"][p][t]
			var tier := t + 1
			var unlocked: bool = game.progress.upgrade_unlocked(k, p, tier)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			v.add_child(row)
			var name_lbl: Label = ui.dark_lbl("%d. %s  ($%d)" % [tier, up[0], int(up[1])], 14)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)
			if unlocked:
				row.add_child(ui.lbl("OK", 13, ui.GREEN.darkened(0.2), 4))
			else:
				var block: String = game.progress.unlock_blocker(k, p, tier)
				var ub: Button = ui.btn("%d XP" % int(game.progress.UNLOCK_COST[tier]), ui.VIOLET, 12, 8)
				ub.disabled = block != ""
				ub.tooltip_text = block if block != "" else "Unlock %s" % up[0]
				ub.custom_minimum_size = Vector2(76, 26)
				ub.pressed.connect(_unlock.bind(k, p, tier))
				row.add_child(ub)
			var ud: Label = ui.dark_lbl(up[2], 12)
			ud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ud.custom_minimum_size = Vector2(200, 0)
			ud.modulate.a = 1.0 if unlocked else 0.6
			v.add_child(ud)

func _unlock(k: String, p: int, tier: int) -> void:
	if game.unlock_upgrade(k, p, tier):
		_show_hero(k)
		refresh()

func _build_settings() -> Control:
	return _screen("SETTINGS")

func _fill_settings() -> void:
	var body := _body("settings")
	_clear(body)
	var items := [
		["sound", "Sound effects", "Pops, explosions and music stings."],
		["shake", "Camera shake", "Shake the camera on boss pops and leaks."],
		["shadows", "Shadows", "Turn off for better performance on slow devices."],
		["autostart", "Auto-start rounds", "Start each new game with AUTO switched on."],
	]
	for it in items:
		var key: String = it[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		var on: bool = game.get_setting(key)
		var b: Button = ui.btn("ON" if on else "OFF", ui.GREEN if on else Color(0.55, 0.6, 0.7), 22, 14)
		b.custom_minimum_size = Vector2(110, 50)
		b.pressed.connect(_toggle_setting.bind(key))
		row.add_child(b)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		row.add_child(v)
		v.add_child(ui.lbl(it[1], 24, Color.WHITE, 8))
		v.add_child(ui.lbl(it[2], 14, Color(0.8, 0.9, 1.0), 0))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 30)
	body.add_child(sep)
	var reset: Button = ui.btn("RESET ALL PROGRESS", Color(0.92, 0.3, 0.3), 20, 14)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(_on_reset.bind(reset))
	body.add_child(reset)

func _toggle_setting(key: String) -> void:
	game.set_setting(key, not game.get_setting(key))
	_fill_settings()

func _on_reset(b: Button) -> void:
	if b.text == "TAP AGAIN TO CONFIRM":
		game.reset_progress()
		show_home()
	else:
		b.text = "TAP AGAIN TO CONFIRM"

func _build_howto() -> Control:
	var sc := _screen("HOW TO PLAY")
	var body: VBoxContainer = sc.get_meta("body")
	var lines := [
		["Goal", "Spirits march along the stone track toward the shrine. Pop them before they arrive. Each one that gets through costs lives."],
		["Heroes", "Pick a hero from the shop (or press 1-7) and click on grass to place them. Click a hero to upgrade, change targeting or sell."],
		["Upgrades", "Each hero has 3 upgrade paths with 4 tiers. You can upgrade two paths, and only one of them past tier 2."],
		["Abilities", "Reaching tier 3 on any path unlocks a hero ability. Use it from the bar at the bottom or with Q W E R T Y U I."],
		["Spirits", "Spirits are layered: popping one reveals the next. Veiled spirits need detection, fortified spirits have double health and regrowing spirits heal if left alone."],
		["Rounds", "Press PLAY (or Space) to send the next round. Press it again to speed up. AUTO starts rounds by itself."],
		["Camera", "Drag to rotate, right-drag to pan, wheel or pinch to zoom. Esc or P pauses."],
		["Progress", "Earn XP, medals and achievements. Try a new daily challenge every day."],
	]
	for l in lines:
		body.add_child(ui.lbl(l[0], 24, ui.GOLD, 8))
		var t: Label = ui.lbl(l[1], 16, Color.WHITE, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(t)
	return sc

## Narrower cards on phones held upright.
func layout(portrait: bool) -> void:
	for k in screens:
		var card: PanelContainer = (screens[k] as Control).get_meta("card")
		card.custom_minimum_size = Vector2(680, 1000) if portrait else Vector2(1000, 600)
