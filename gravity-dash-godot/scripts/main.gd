extends Node
## Screen flow: main menu, level select, icon kit, statistics, and the game with its pause and results panels.

const Levels = preload("res://scripts/levels.gd")
const Skins = preload("res://scripts/skins.gd")
const GDButton = preload("res://scripts/ui/gd_button.gd")
const TitleArt = preload("res://scripts/ui/title_art.gd")
const LevelCard = preload("res://scripts/ui/level_card.gd")
const Tile = preload("res://scripts/ui/tile.gd")
const Widget = preload("res://scripts/ui/widgets.gd")
const World = preload("res://scripts/world.gd")
const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const DARK := Color(0.05, 0.03, 0.12)

var world
var ui: CanvasLayer
var fade: ColorRect
var screen: Control
var levels: Array = []
var page := 0
var current := ""
var busy := false
var card
var page_label: Label
var pause_box: Control
var win_box: Control
var result: Dictionary = {}
var tiles: Array = []
var preview
var info: Label
var skin_name: Label


func _ready() -> void:
	for i in Levels.DEFS.size():
		levels.append(Levels.build(i))
	world = World.new()
	add_child(world)
	world.died.connect(_on_died)
	world.won.connect(_on_won)
	world.win_panel_ready.connect(_show_win_panel)
	ui = CanvasLayer.new()
	add_child(ui)
	var top := CanvasLayer.new()
	top.layer = 10
	add_child(top)
	fade = ColorRect.new()
	fade.color = Color(DARK, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in levels.size():
		if not Save.is_done(i):
			page = i
			break
	_show_menu()
	create_tween().tween_property(fade, "color:a", 0.0, 0.5)


# ---------- Helpers ----------

func _go(fn: Callable) -> void:
	if busy:
		return
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.16)
	tw.tween_callback(fn)
	tw.tween_property(fade, "color:a", 0.0, 0.22)
	tw.tween_callback(_go_done)


func _go_done() -> void:
	busy = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _new_screen(n: String) -> Control:
	if is_instance_valid(screen):
		screen.queue_free()
	pause_box = null
	win_box = null
	tiles.clear()
	screen = Control.new()
	screen.name = n
	ui.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current = n
	return screen


func _label(text: String, fs := 28, col := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", DARK)
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(shape: String, fill: Color, icon: String, text: String, sz: Vector2, cb: Callable) -> Control:
	var b = GDButton.new()
	b.setup(shape, fill, icon, text, sz)
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Anchors a control to a screen edge or corner, sized to its minimum size.
func _pin(c: Control, preset: int, margin := 20) -> void:
	var sz := c.get_combined_minimum_size().max(c.custom_minimum_size)
	c.set_anchors_preset(preset)
	var ax := c.anchor_left
	var ay := c.anchor_top
	c.offset_left = margin if ax == 0.0 else (-sz.x * 0.5 if ax == 0.5 else -sz.x - margin)
	c.offset_top = margin if ay == 0.0 else (-sz.y * 0.5 if ay == 0.5 else -sz.y - margin)
	c.offset_right = c.offset_left + sz.x
	c.offset_bottom = c.offset_top + sz.y


func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.025, 0.12, 0.82)
	sb.set_corner_radius_all(24)
	sb.border_color = DARK
	sb.set_border_width_all(5)
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(0, 8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	return p


func _back_button(to: Callable) -> void:
	var back := _button("circle", Color("5ce1ff"), "back", "", Vector2(72, 72), func(): _go(to))
	screen.add_child(back)
	_pin(back, Control.PRESET_TOP_LEFT, 22)


func _toggle(setting: String) -> Control:
	var b = GDButton.new()
	b.setup("round", Color("9a7aff"), "music" if setting == "music" else "sound", "", Vector2(66, 66))
	b.crossed = not Save.setting(setting)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		b.crossed = not Save.toggle(setting)
		b.queue_redraw()
		if setting == "music":
			Audio.music_setting_changed())
	return b


static func _fmt(n: float) -> String:
	var s := str(int(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


static func _fmt_time(sec: float) -> String:
	var t := int(sec)
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t / 60) % 60]
	return "%dm %02ds" % [t / 60, t % 60]


func _unhandled_input(e: InputEvent) -> void:
	if busy or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.keycode
	match current:
		"menu":
			if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_go(_show_levels)
		"levels":
			if k in [KEY_LEFT, KEY_A]:
				_page(-1)
			elif k in [KEY_RIGHT, KEY_D]:
				_page(1)
			elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_go(_start_page)
			elif k == KEY_ESCAPE:
				_go(_show_menu)
		"icons", "stats":
			if k == KEY_ESCAPE:
				_go(_show_menu)
		"play":
			if k in [KEY_ESCAPE, KEY_P]:
				if world.mode == "play":
					_pause()
				elif world.mode == "paused":
					_resume()
			elif k == KEY_R and world.mode in ["play", "paused", "dead"]:
				_restart()
			elif k in [KEY_ENTER, KEY_KP_ENTER] and win_box != null:
				if page + 1 < levels.size():
					_go(_start_next)
				else:
					_go(_start_page)
	get_viewport().set_input_as_handled()


# ---------- Main menu ----------

func _show_menu() -> void:
	var root := _new_screen("menu")
	world.set_menu()
	Audio.play_menu()
	var col := VBoxContainer.new()
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	var title = TitleArt.new()
	title.custom_minimum_size = Vector2(0, 250)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	col.add_child(row)
	row.add_child(_menu_item(Color("ff7ad9"), "cube", 132.0, "Icon Kit", _show_icons))
	row.add_child(_menu_item(Color("8ee53f"), "play", 200.0, "Play", _show_levels))
	row.add_child(_menu_item(Color("ffb13d"), "chart", 132.0, "Stats", _show_stats))
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 14)
	root.add_child(opts)
	opts.add_child(_toggle("music"))
	opts.add_child(_toggle("sfx"))
	_pin(opts, Control.PRESET_BOTTOM_LEFT, 22)
	var tally := _label("★ %d / %d      Levels %d / %d" % [int(Save.stat("stars")), Levels.total_stars(),
		int(Save.stat("completions")), levels.size()], 26, Color("ffe08a"), 9)
	root.add_child(tally)
	_pin(tally, Control.PRESET_BOTTOM_RIGHT, 28)


func _menu_item(fill: Color, icon: String, side: float, caption: String, to: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(_button("circle", fill, icon, "", Vector2(side, side), func(): _go(to)))
	v.add_child(_label(caption, 30))
	return v


# ---------- Level select ----------

func _show_levels() -> void:
	var root := _new_screen("levels")
	if world.mode != "menu":
		world.set_menu()
	Audio.play_menu()
	_back_button(_show_menu)
	var stars := _label("★ %d / %d" % [int(Save.stat("stars")), Levels.total_stars()], 34, Color("ffe08a"))
	root.add_child(stars)
	_pin(stars, Control.PRESET_TOP_RIGHT, 30)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	center.add_child(hb)
	hb.add_child(_button("circle", Color("ffc94d"), "left", "", Vector2(86, 86), _page.bind(-1)))
	card = LevelCard.new()
	card.custom_minimum_size = Vector2(800, 330)
	card.chosen.connect(func(): _go(_start_page))
	hb.add_child(card)
	hb.add_child(_button("circle", Color("ffc94d"), "right", "", Vector2(86, 86), _page.bind(1)))
	page_label = _label("", 26, Color(1, 1, 1, 0.85), 8)
	root.add_child(page_label)
	_pin(page_label, Control.PRESET_CENTER_BOTTOM, 40)
	var hint := _label("Click the card to play.  Arrow keys change level.", 20, Color(1, 1, 1, 0.6), 6)
	root.add_child(hint)
	_pin(hint, Control.PRESET_CENTER_BOTTOM, 14)
	_refresh_card(0)


func _page(dir: int) -> void:
	page = posmod(page + dir, levels.size())
	_refresh_card(dir)


func _refresh_card(dir: int) -> void:
	card.set_level(levels[page], page, dir)
	var dots := ""
	for i in levels.size():
		dots += "●" if i == page else "·"
	page_label.text = dots
	Audio.prefetch(page)


# ---------- Icon kit ----------

func _show_icons() -> void:
	var root := _new_screen("icons")
	world.set_menu()
	_back_button(_show_menu)
	var title := _label("Icon Kit", 54, Color("ff9ae6"), 12)
	root.add_child(title)
	_pin(title, Control.PRESET_CENTER_TOP, 18)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 60
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 36)
	center.add_child(hb)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(300, 0)
	hb.add_child(left)
	preview = Widget.new()
	preview.kind = "preview"
	preview.custom_minimum_size = Vector2(300, 230)
	left.add_child(preview)
	skin_name = _label(str(Skins.ICONS[Save.icon()].name), 36)
	left.add_child(skin_name)
	info = _label("Pick an icon and two colours.\nLocked ones show what earns them.", 20, Color(1, 1, 1, 0.75), 6)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(300, 90)
	left.add_child(info)

	var panel := _panel(Vector2(0, 0))
	hb.add_child(panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	panel.add_child(right)
	var sections := [["Icons", "icon", Skins.ICONS.size(), 74.0], ["Main colour", "c1", Skins.COLORS.size(), 50.0], ["Second colour", "c2", Skins.COLORS.size(), 50.0]]
	for sec in sections:
		var head := _label(str(sec[0]), 24, Color(1, 1, 1, 0.85), 7)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		right.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		right.add_child(grid)
		for i in int(sec[2]):
			var tl = Tile.new()
			tl.setup(str(sec[1]), i, _pick, float(sec[3]))
			grid.add_child(tl)
			tiles.append(tl)


func _pick(kind: String, idx: int) -> void:
	var list: Array = Skins.ICONS if kind == "icon" else Skins.COLORS
	var req: Dictionary = list[idx].req
	if not Save.unlocked(req):
		info.text = "Locked\n" + Save.req_text(req)
		Audio.sfx("deny")
		return
	Save.set_skin(kind, idx)
	Audio.sfx("click")
	for tl in tiles:
		tl.queue_redraw()
	preview.pop = 1.0
	skin_name.text = str(Skins.ICONS[Save.icon()].name)
	info.text = ""


# ---------- Statistics ----------

func _show_stats() -> void:
	var root := _new_screen("stats")
	world.set_menu()
	_back_button(_show_menu)
	var title := _label("Statistics", 54, Color("ffc46b"), 12)
	root.add_child(title)
	_pin(title, Control.PRESET_CENTER_TOP, 18)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 70
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 28)
	center.add_child(hb)

	var left := _panel(Vector2(440, 0))
	hb.add_child(left)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	left.add_child(rows)
	var attempts := Save.stat("attempts")
	var flips := Save.stat("flips")
	var data := [
		["Attempts", _fmt(attempts)],
		["Gravity flips", _fmt(flips)],
		["Crashes", _fmt(Save.stat("deaths"))],
		["Levels completed", "%d / %d" % [int(Save.stat("completions")), levels.size()]],
		["Stars", "%d / %d" % [int(Save.stat("stars")), Levels.total_stars()]],
		["First-try clears", _fmt(Save.stat("perfect"))],
		["Total clears", _fmt(Save.stat("clears"))],
		["Time played", _fmt_time(Save.stat("time"))],
		["Distance", _fmt(Save.stat("distance")) + " blocks"],
		["Flips per attempt", "%.1f" % (flips / maxf(1.0, attempts))],
		["Icons unlocked", "%d / %d" % [Save.count_unlocked(Skins.ICONS), Skins.ICONS.size()]],
		["Colours unlocked", "%d / %d" % [Save.count_unlocked(Skins.COLORS), Skins.COLORS.size()]],
	]
	for row in data:
		var h := HBoxContainer.new()
		rows.add_child(h)
		var n := _label(str(row[0]), 23, Color(1, 1, 1, 0.72), 6)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var v := _label(str(row[1]), 25, Color.WHITE, 7)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)

	var right := _panel(Vector2(560, 0))
	hb.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in levels.size():
		var r = Widget.new()
		r.kind = "row"
		r.lv = levels[i]
		r.idx = i
		r.custom_minimum_size = Vector2(500, 44)
		list.add_child(r)


# ---------- Playing ----------

func _start_page() -> void:
	_start_level(page)


func _start_next() -> void:
	_start_level(mini(page + 1, levels.size() - 1))


func _start_level(i: int) -> void:
	page = i
	var root := _new_screen("play")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar = Widget.new()
	bar.kind = "progress"
	bar.world = world
	bar.color = Color(levels[i].def.accent)
	bar.custom_minimum_size = Vector2(520, 34)
	root.add_child(bar)
	_pin(bar, Control.PRESET_CENTER_TOP, 18)
	var pb := _button("circle", Color("5ce1ff"), "pause", "", Vector2(62, 62), _pause)
	pb.focus_mode = Control.FOCUS_NONE
	pb.name = "PauseButton"
	root.add_child(pb)
	_pin(pb, Control.PRESET_TOP_RIGHT, 16)
	world.start(levels[i])
	get_viewport().gui_release_focus()


func _pause() -> void:
	if world.mode != "play" or pause_box != null:
		return
	world.set_paused(true)
	pause_box = Control.new()
	screen.add_child(pause_box)
	pause_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	pause_box.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	pause_box.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	center.add_child(v)
	v.add_child(_label(str(levels[page].def.name), 64, Color.WHITE, 14))
	var bar = Widget.new()
	bar.kind = "progress"
	bar.value = Save.best(page)
	bar.color = Color(levels[page].def.accent)
	bar.custom_minimum_size = Vector2(520, 34)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_label("Best", 22, Color(1, 1, 1, 0.7), 6))
	v.add_child(bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	row.add_child(_button("circle", Color("ffb13d"), "restart", "", Vector2(104, 104), _restart))
	var resume := _button("circle", Color("8ee53f"), "play", "", Vector2(140, 140), _resume)
	row.add_child(resume)
	row.add_child(_button("circle", Color("5ce1ff"), "list", "", Vector2(104, 104), func(): _go(_show_levels)))
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 14)
	v.add_child(opts)
	opts.add_child(_toggle("music"))
	opts.add_child(_toggle("sfx"))


func _resume() -> void:
	if pause_box:
		pause_box.queue_free()
		pause_box = null
	world.set_paused(false)


func _restart() -> void:
	if pause_box:
		pause_box.queue_free()
		pause_box = null
	world.attempts += 1
	world.reset_run()


func _on_died(pct: int, new_best: bool) -> void:
	if not new_best or pct <= 0 or current != "play":
		return
	Audio.sfx("best")
	var l := _label("New Best!\n%d%%" % pct, 64, Color("ffe14d"), 16)
	screen.add_child(l)
	_pin(l, Control.PRESET_CENTER, 0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ZERO
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _on_won(res: Dictionary) -> void:
	result = res
	var pb := screen.get_node_or_null("PauseButton")
	if pb:
		pb.hide()


## The results panel drops in after the "LEVEL COMPLETE!" animation.
func _show_win_panel() -> void:
	if current != "play":
		return
	win_box = Control.new()
	screen.add_child(win_box)
	win_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := _panel(Vector2(640, 0))
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.border_color = Color(levels[page].def.accent)
	win_box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_label(str(levels[page].def.name), 44, Color(levels[page].def.accent), 11))
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 46)
	v.add_child(grid)
	for item in [["Attempts", str(result.attempts)], ["Flips", str(result.flips)], ["Time", LevelCard.fmt_time(float(result.time))]]:
		var cell := VBoxContainer.new()
		cell.add_child(_label(str(item[0]), 22, Color(1, 1, 1, 0.65), 6))
		cell.add_child(_label(str(item[1]), 40, Color.WHITE, 10))
		grid.add_child(cell)
	var reward: Label = null
	if int(result.stars) > 0:
		reward = _label("+%d ★" % int(result.stars), 56, Color("ffd34d"), 14)
		v.add_child(reward)
	else:
		v.add_child(_label("Already beaten: no new stars", 22, Color(1, 1, 1, 0.6), 6))
	if result.perfect:
		v.add_child(_label("Perfect! Beaten on the first attempt", 24, Color("8ee53f"), 7))
	if not result.unlocks.is_empty():
		var names := PackedStringArray()
		for u in result.unlocks:
			names.append(str(u))
		var ul := _label("Unlocked:  " + ", ".join(names), 24, Color("ff9ae6"), 7)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size = Vector2(580, 0)
		v.add_child(ul)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	row.add_child(_button("circle", Color("ffb13d"), "restart", "", Vector2(96, 96), func(): _go(_start_page)))
	row.add_child(_button("circle", Color("5ce1ff"), "list", "", Vector2(96, 96), func(): _go(_show_levels)))
	if page + 1 < levels.size():
		row.add_child(_button("circle", Color("8ee53f"), "right", "", Vector2(96, 96), func(): _go(_start_next)))

	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, -panel.size.y - 40.0)
	var target_y := maxf(vp.y * 0.3, vp.y - panel.size.y - 30.0) if panel.size.y > vp.y * 0.65 else vp.y * 0.3
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", target_y, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if reward:
		reward.pivot_offset = reward.size * 0.5
		reward.scale = Vector2.ZERO
		tw.tween_callback(Audio.sfx.bind("unlock"))
		tw.tween_property(reward, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
