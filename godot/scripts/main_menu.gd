# Title screen shown over a live "attract mode" game: player level, big PLAY
# button, daily challenge, and screens for heroes, achievements, stats,
# settings and how to play. Uses the style helpers from ui.gd.
extends Control

const Defs = preload("res://scripts/defs.gd")
const Maps = preload("res://scripts/maps.gd")
const Progress = preload("res://scripts/progress.gd")

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
var ach_btn: Button
var tip_lbl: Label
var screens := {}
var hero_detail: VBoxContainer
var tip_i := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	# Soft vignette so text reads over the live game
	for top in [true, false]:
		var g := ColorRect.new()
		g.color = Color(0.05, 0.1, 0.25, 0.45)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.anchor_right = 1.0
		g.anchor_top = 0.0 if top else 1.0
		g.anchor_bottom = 0.0 if top else 1.0
		g.offset_bottom = 120 if top else 0
		g.offset_top = 0 if top else -90
		add_child(g)

	# Player level badge
	var badge: PanelContainer = ui.panel_of(ui.NAVY, 18)
	badge.position = Vector2(14, 12)
	badge.custom_minimum_size = Vector2(300, 0)
	add_child(badge)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	badge.add_child(bh)
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", ui.sb(ui.GOLD, 30, 3, false, 0))
	circle.custom_minimum_size = Vector2(60, 60)
	bh.add_child(circle)
	level_lbl = ui.lbl("1", 30, Color.WHITE, 10)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(level_lbl)
	var bv := VBoxContainer.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bv)
	bv.add_child(ui.lbl("PLAYER LEVEL", 16, ui.GOLD, 6))
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(200, 16)
	xp_bar.add_theme_stylebox_override("background", ui.sb(Color(0.2, 0.25, 0.4), 8, 2, false, 0))
	xp_bar.add_theme_stylebox_override("fill", ui.sb(ui.GREEN, 8, 2, false, 0))
	bv.add_child(xp_bar)
	xp_lbl = ui.lbl("", 12, Color(0.8, 0.9, 1.0), 0)
	bv.add_child(xp_lbl)

	# Logo
	var logo := VBoxContainer.new()
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.offset_top = 70
	logo.add_theme_constant_override("separation", -10)
	add_child(logo)
	var t1: Label = ui.lbl("SAKURA", 96, Color.WHITE, 26)
	t1.add_theme_color_override("font_shadow_color", ui.PINK)
	t1.add_theme_constant_override("shadow_offset_y", 9)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(t1)
	var t2: Label = ui.lbl("SPIRIT DEFENSE", 46, ui.GOLD, 16)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(t2)

	# Centre: PLAY and the daily challenge
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.offset_top = 40
	center.add_theme_constant_override("separation", 14)
	add_child(center)
	var play: Button = ui.btn("PLAY", ui.GREEN, 64, 30)
	play.custom_minimum_size = Vector2(340, 110)
	play.pressed.connect(func() -> void: ui.show_map_select())
	center.add_child(play)
	daily_btn = ui.btn("", ui.ORANGE, 18, 16)
	daily_btn.custom_minimum_size = Vector2(340, 70)
	daily_btn.pressed.connect(func() -> void: game.start_daily())
	center.add_child(daily_btn)

	# Side buttons
	var left := _side_column(true)
	left.add_child(_side_btn("HEROES", ui.PINK, func() -> void: _open("heroes")))
	ach_btn = _side_btn("ACHIEVEMENTS", ui.VIOLET, func() -> void: _open("achievements"))
	left.add_child(ach_btn)
	left.add_child(_side_btn("STATS", Color(0.35, 0.5, 0.75), func() -> void: _open("stats")))
	var right := _side_column(false)
	right.add_child(_side_btn("SETTINGS", Color(0.35, 0.5, 0.75), func() -> void: _open("settings")))
	right.add_child(_side_btn("HOW TO PLAY", Color(0.35, 0.5, 0.75), func() -> void: _open("howto")))
	if OS.has_feature("pc") and not OS.has_feature("web"):
		right.add_child(_side_btn("QUIT", Color(0.92, 0.3, 0.3), func() -> void: get_tree().quit()))

	tip_lbl = ui.lbl("", 18, Color.WHITE, 8)
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.anchor_left = 0.0
	tip_lbl.anchor_right = 1.0
	tip_lbl.anchor_top = 1.0
	tip_lbl.anchor_bottom = 1.0
	tip_lbl.offset_top = -50
	tip_lbl.offset_bottom = -16
	add_child(tip_lbl)
	_next_tip()

func _side_column(left_side: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.offset_top = 40
	if left_side:
		v.anchor_left = 0.0
		v.anchor_right = 0.0
		v.offset_left = 30
	else:
		v.anchor_left = 1.0
		v.anchor_right = 1.0
		v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		v.offset_right = -30
	add_child(v)
	return v

func _side_btn(text: String, bg: Color, cb: Callable) -> Button:
	var b: Button = ui.btn(text, bg, 24, 18)
	b.custom_minimum_size = Vector2(230, 64)
	b.pressed.connect(cb)
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
	daily_btn.text = "DAILY CHALLENGE%s\n%s - %s - %s" % [" (DONE)" if d["done"] else "", m["name"], String(d["diff"]).capitalize(), game.MODES[d["mode"]]["name"]]
	ach_btn.text = "ACHIEVEMENTS %d/%d" % [p.unlocked_count(), Progress.ACHIEVEMENTS.size()]

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
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
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
			_show_hero(Defs.HERO_ORDER[0])
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 6)
	list.add_theme_constant_override("v_separation", 6)
	h.add_child(list)
	for k in Defs.HERO_ORDER:
		var key: String = k
		var b: Button = ui.btn("", ui.TILE, 14, 10)
		b.custom_minimum_size = Vector2(96, 96)
		ui.centered(b, ui._portrait_rect(key, 84))
		b.pressed.connect(func() -> void: _show_hero(key))
		list.add_child(b)
	hero_detail = VBoxContainer.new()
	hero_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_detail.add_theme_constant_override("separation", 6)
	h.add_child(hero_detail)
	return sc

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
	var desc: Label = ui.lbl(d["desc"], 16, Color(0.85, 0.92, 1.0), 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	info.add_child(ui.lbl("Cost $%d" % int(d["cost"]), 18, ui.GOLD, 6))
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
			v.add_child(ui.dark_lbl("%d. %s  ($%d)" % [t + 1, up[0], int(up[1])], 14))
			var ud: Label = ui.dark_lbl(up[2], 12)
			ud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ud.custom_minimum_size = Vector2(200, 0)
			v.add_child(ud)

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
