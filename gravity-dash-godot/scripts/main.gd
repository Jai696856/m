extends Node
## Screen flow and shared UI helpers. The screens themselves are split across three files:
##   main.gd           main menu, level select, playing (pause, results), settings, secret codes
##   screens_hub.gd    the Explore hub grid and everything behind its tiles
##   screens_shop.gd   icon kit, shops, achievements, statistics

const Levels = preload("res://scripts/levels.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Skins = preload("res://scripts/skins.gd")
const GDButton = preload("res://scripts/ui/gd_button.gd")
const TitleArt = preload("res://scripts/ui/title_art.gd")
const LevelCard = preload("res://scripts/ui/level_card.gd")
const Tile = preload("res://scripts/ui/tile.gd")
const Widget = preload("res://scripts/ui/widgets.gd")
const World = preload("res://scripts/world.gd")
const HubScreens = preload("res://scripts/screens_hub.gd")
const ShopScreens = preload("res://scripts/screens_shop.gd")
const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const DARK := Color(0.05, 0.03, 0.12)

var world
var ui: CanvasLayer
var top: CanvasLayer
var fade: ColorRect
var fade_label: Label
var screen: Control
var hub
var shops
var mains: Array = []      # built (unverified) main levels, for cards
var cache: Dictionary = {} # verified levels by key
var page := 0
var current := ""
var busy := false
var card
var page_label: Label
var pause_box: Control
var win_box: Control
var result: Dictionary = {}
var playing: Dictionary = {}
var play_practice := false
var back_to: Callable
var on_level_won: Callable
var toasts: Array = []


func _ready() -> void:
	for i in Levels.main_count():
		mains.append(Levels.build(Levels.main_params(i)))
	hub = HubScreens.new(self)
	shops = ShopScreens.new(self)
	world = World.new()
	add_child(world)
	world.died.connect(_on_died)
	world.won.connect(_on_won)
	world.win_panel_ready.connect(_show_win_panel)
	ui = CanvasLayer.new()
	add_child(ui)
	top = CanvasLayer.new()
	top.layer = 10
	add_child(top)
	fade = ColorRect.new()
	fade.color = Color(DARK, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_label = _label("", 30, Color(1, 1, 1, 0.8))
	fade.add_child(fade_label)
	fade_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Save.toast.connect(_toast)
	for i in mains.size():
		if not Save.is_done(mains[i].key):
			page = i
			break
	show_menu()
	create_tween().tween_property(fade, "color:a", 0.0, 0.5)


# ---------- Helpers ----------

func go(fn: Callable, loading := "") -> void:
	if busy:
		return
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_label.text = loading
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.16)
	tw.tween_interval(0.03)
	tw.tween_callback(fn)
	tw.tween_property(fade, "color:a", 0.0, 0.22)
	tw.tween_callback(_go_done)


func _go_done() -> void:
	busy = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_label.text = ""


func new_screen(n: String) -> Control:
	if is_instance_valid(screen):
		screen.queue_free()
	pause_box = null
	win_box = null
	screen = Control.new()
	screen.name = n
	ui.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current = n
	world.show_cube = n == "menu"
	if n != "play":
		if world.mode != "menu":
			world.set_menu()
		Audio.play_menu()
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


func label(text: String, fs := 28, col := Color.WHITE, outline := 10) -> Label:
	return _label(text, fs, col, outline)


func button(shape: String, fill: Color, icon: String, text: String, sz: Vector2, cb: Callable) -> Control:
	var b = GDButton.new()
	b.setup(shape, fill, icon, text, sz)
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Anchors a control to a screen edge or corner, sized to its minimum size.
func pin(c: Control, preset: int, margin := 20) -> void:
	var sz := c.get_combined_minimum_size().max(c.custom_minimum_size)
	c.set_anchors_preset(preset)
	var ax := c.anchor_left
	var ay := c.anchor_top
	c.offset_left = margin if ax == 0.0 else (-sz.x * 0.5 if ax == 0.5 else -sz.x - margin)
	c.offset_top = margin if ay == 0.0 else (-sz.y * 0.5 if ay == 0.5 else -sz.y - margin)
	c.offset_right = c.offset_left + sz.x
	c.offset_bottom = c.offset_top + sz.y


func panel(min_size: Vector2, border := DARK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.025, 0.12, 0.86)
	sb.set_corner_radius_all(20)
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_offset = Vector2(0, 6)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	return p


func center_box(root: Control, top_offset := 70.0) -> CenterContainer:
	var c := CenterContainer.new()
	root.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_top = top_offset
	return c


## Standard screen frame: back button, title and wallet.
func frame(root: Control, title: String, back: Callable, col := Color("ffc46b")) -> void:
	var b := button("circle", Color("5ce1ff"), "back", "", Vector2(70, 70), func(): go(back))
	root.add_child(b)
	pin(b, Control.PRESET_TOP_LEFT, 20)
	if title != "":
		var t := _label(title, 50, col, 12)
		root.add_child(t)
		pin(t, Control.PRESET_CENTER_TOP, 16)
	var w = Widget.new()
	w.kind = "wallet"
	w.custom_minimum_size = Vector2(230, 44)
	root.add_child(w)
	pin(w, Control.PRESET_TOP_RIGHT, 24)


func toggle_button(setting: String) -> Control:
	var b = GDButton.new()
	b.setup("round", Color("9a7aff"), "music" if setting == "music" else "sound", "", Vector2(64, 64))
	b.crossed = not bool(Save.setting(setting))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		b.crossed = not Save.toggle(setting)
		b.queue_redraw()
		if setting == "music":
			Audio.music_setting_changed())
	return b


static func fmt(n: float) -> String:
	var s := str(int(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


static func fmt_time(sec: float) -> String:
	var t := int(sec)
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t / 60) % 60]
	return "%dm %02ds" % [t / 60, t % 60]


static func fmt_wait(sec: int) -> String:
	if sec <= 0:
		return "Ready!"
	if sec >= 3600:
		return "%dh %02dm" % [sec / 3600, (sec / 60) % 60]
	return "%dm %02ds" % [sec / 60, sec % 60]


## A notification banner that slides in at the top (achievements, unlocks).
func _toast(title: String, text: String) -> void:
	var p := panel(Vector2(520, 0), Color("ffd34d"))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(_label(title, 26, Color("ffd34d"), 8))
	v.add_child(_label(text, 20, Color.WHITE, 6))
	top.add_child(p)
	toasts.append(p)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var vs := get_viewport().get_visible_rect().size
	p.position = Vector2((vs.x - p.size.x) * 0.5, vs.y + 10)
	Audio.sfx("unlock")
	var tw := p.create_tween()
	tw.tween_interval((toasts.size() - 1) * 1.2)
	tw.tween_property(p, "position:y", vs.y - p.size.y - 14.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(p, "position:y", vs.y + 10, 0.3)
	tw.tween_callback(func():
		toasts.erase(p)
		p.queue_free())


func _unhandled_input(e: InputEvent) -> void:
	if busy or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.keycode
	match current:
		"menu":
			if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				go(show_levels)
		"levels":
			if k in [KEY_LEFT, KEY_A]:
				_page(-1)
			elif k in [KEY_RIGHT, KEY_D]:
				_page(1)
			elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				play_main(page, false)
			elif k == KEY_ESCAPE:
				go(show_menu)
		"play":
			if k in [KEY_ESCAPE, KEY_P]:
				if world.mode == "play":
					_pause()
				elif world.mode == "paused":
					_resume()
			elif k == KEY_R and world.mode in ["play", "paused", "dead"]:
				_restart()
			elif k in [KEY_ENTER, KEY_KP_ENTER] and win_box != null:
				go(back_to)
		"codes":
			return
		_:
			if k == KEY_ESCAPE:
				go(show_menu)
	get_viewport().set_input_as_handled()


# ---------- Main menu ----------

func show_menu() -> void:
	var root := new_screen("menu")
	var col := VBoxContainer.new()
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	var title = TitleArt.new()
	title.custom_minimum_size = Vector2(0, 240)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	col.add_child(row)
	row.add_child(_menu_item(Color("ff7ad9"), "cube", 130.0, "Icon Kit", shops.show_icons))
	row.add_child(_menu_item(Color("8ee53f"), "play", 196.0, "Play", show_levels))
	row.add_child(_menu_item(Color("ffb13d"), "grid", 130.0, "Explore", hub.show_hub))

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)
	left.add_child(toggle_button("music"))
	left.add_child(toggle_button("sfx"))
	left.add_child(button("round", Color("9a7aff"), "gear", "", Vector2(64, 64), func(): go(show_settings)))
	pin(left, Control.PRESET_BOTTOM_LEFT, 20)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	right.add_child(button("round", Color("ffd34d"), "medal", "", Vector2(64, 64), func(): go(shops.show_achievements)))
	right.add_child(button("round", Color("ffb13d"), "chart", "", Vector2(64, 64), func(): go(shops.show_stats)))
	right.add_child(button("round", Color("8a5cff"), "door", "", Vector2(64, 64), func(): go(shops.show_market)))
	pin(right, Control.PRESET_BOTTOM_RIGHT, 20)

	var lock := button("round", Color("3a3f5c"), "lock", "", Vector2(64, 64), func(): go(show_codes))
	root.add_child(lock)
	pin(lock, Control.PRESET_TOP_RIGHT, 20)
	var w = Widget.new()
	w.kind = "wallet"
	w.custom_minimum_size = Vector2(230, 44)
	root.add_child(w)
	pin(w, Control.PRESET_TOP_LEFT, 26)
	var tally := _label("Stars %d   Levels %d / %d   Coins %d" % [int(Save.stat("stars")), int(Save.stat("completions")), mains.size(),
		int(Save.stat("coins"))], 20, Color("ffe08a"), 7)
	root.add_child(tally)
	pin(tally, Control.PRESET_CENTER_BOTTOM, 22)


func _menu_item(fill: Color, icon: String, side: float, caption: String, to: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(button("circle", fill, icon, "", Vector2(side, side), func(): go(to)))
	v.add_child(_label(caption, 28))
	return v


# ---------- Level select (main levels) ----------

func show_levels() -> void:
	var root := new_screen("levels")
	frame(root, "", show_menu)
	var center := center_box(root, 0.0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	center.add_child(hb)
	hb.add_child(button("circle", Color("ffc94d"), "left", "", Vector2(80, 80), _page.bind(-1)))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	hb.add_child(mid)
	card = LevelCard.new()
	card.custom_minimum_size = Vector2(820, 310)
	card.chosen.connect(func(): play_main(page, false))
	mid.add_child(card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	mid.add_child(row)
	row.add_child(button("round", Color("8ee53f"), "play", "Play", Vector2(210, 64), func(): play_main(page, false)))
	row.add_child(button("round", Color("7ee0c8"), "restart", "Practice", Vector2(230, 64), func(): play_main(page, true)))
	hb.add_child(button("circle", Color("ffc94d"), "right", "", Vector2(80, 80), _page.bind(1)))
	page_label = _label("", 24, Color(1, 1, 1, 0.85), 8)
	root.add_child(page_label)
	pin(page_label, Control.PRESET_CENTER_BOTTOM, 30)
	_refresh_card(0)


func _page(dir: int) -> void:
	page = posmod(page + dir, mains.size())
	_refresh_card(dir)


func _refresh_card(dir: int) -> void:
	card.set_level(mains[page], dir, "LEVEL %d" % (page + 1))
	page_label.text = "Level %d / %d" % [page + 1, mains.size()]
	Audio.prefetch(mains[page].key)


func play_main(i: int, practice: bool) -> void:
	page = i
	start_level(Levels.main_params(i), practice, show_levels)


## Starts any level. Builds and verifies it (cached), then shows the game; `back` is where the results panel returns to.
func start_level(p: Dictionary, practice: bool, back: Callable, won_cb := Callable()) -> void:
	back_to = back
	on_level_won = won_cb
	play_practice = practice
	playing = p
	go(_start_now, "Building level…")


func _start_now() -> void:
	var key: String = playing.key
	if not cache.has(key):
		cache[key] = Levels.build_verified(playing)
	var lv: Dictionary = cache[key]
	var root := new_screen("play")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar = Widget.new()
	bar.kind = "progress"
	bar.world = world
	bar.color = Levels.palette(float(playing.hue)).accent
	bar.custom_minimum_size = Vector2(520, 34)
	root.add_child(bar)
	pin(bar, Control.PRESET_CENTER_TOP, 18)
	var pb := button("circle", Color("5ce1ff"), "pause", "", Vector2(62, 62), _pause)
	pb.focus_mode = Control.FOCUS_NONE
	pb.name = "PauseButton"
	root.add_child(pb)
	pin(pb, Control.PRESET_TOP_RIGHT, 16)
	if play_practice:
		var cps := HBoxContainer.new()
		cps.name = "PracticeButtons"
		cps.add_theme_constant_override("separation", 12)
		root.add_child(cps)
		var add := button("round", Color("7ee04a"), "", "+ Checkpoint", Vector2(210, 56), world.place_checkpoint)
		add.focus_mode = Control.FOCUS_NONE
		cps.add_child(add)
		var rem := button("round", Color("ff7a7a"), "", "- Checkpoint", Vector2(210, 56), world.remove_checkpoint)
		rem.focus_mode = Control.FOCUS_NONE
		cps.add_child(rem)
		pin(cps, Control.PRESET_BOTTOM_LEFT, 18)
	world.start(lv, play_practice)
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
	var center := center_box(pause_box, 0.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	v.add_child(_label(str(playing.name), 58, Color.WHITE, 14))
	for row in [["Normal", Save.best(playing.key), Levels.palette(float(playing.hue)).accent],
			["Practice", int(Save.level(playing.key).practice), Color("7ee04a")]]:
		var bar = Widget.new()
		bar.kind = "progress"
		bar.value = int(row[1])
		bar.color = row[2]
		bar.custom_minimum_size = Vector2(520, 30)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(_label(str(row[0]), 20, Color(1, 1, 1, 0.7), 6))
		v.add_child(bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	row.add_child(button("circle", Color("ffb13d"), "restart", "", Vector2(100, 100), _restart))
	row.add_child(button("circle", Color("8ee53f"), "play", "", Vector2(136, 136), _resume))
	row.add_child(button("circle", Color("7ee0c8"), "featured", "", Vector2(100, 100), _toggle_practice))
	row.add_child(button("circle", Color("5ce1ff"), "list", "", Vector2(100, 100), func(): go(back_to)))
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 14)
	v.add_child(opts)
	opts.add_child(toggle_button("music"))
	opts.add_child(toggle_button("sfx"))
	v.add_child(_label("The star button %s practice mode" % ("turns off" if play_practice else "switches to"), 18, Color(1, 1, 1, 0.6), 5))


func _toggle_practice() -> void:
	start_level(playing, not play_practice, back_to, on_level_won)


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
	if world.practice:
		world.checkpoints.clear()
	world.reset_run()


func _on_died(pct: int, new_best: bool) -> void:
	if not new_best or pct <= 0 or current != "play" or world.practice:
		return
	Audio.sfx("best")
	var l := _label("New Best!\n%d%%" % pct, 64, Color("ffe14d"), 16)
	screen.add_child(l)
	pin(l, Control.PRESET_CENTER, 0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ZERO
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _on_won(res: Dictionary) -> void:
	result = res
	for n in ["PauseButton", "PracticeButtons"]:
		var node := screen.get_node_or_null(n)
		if node:
			node.hide()
	if on_level_won.is_valid() and not res.practice:
		on_level_won.call(res)


## The results panel drops in after the "LEVEL COMPLETE!" animation.
func _show_win_panel() -> void:
	if current != "play":
		return
	win_box = Control.new()
	screen.add_child(win_box)
	win_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var accent: Color = Levels.palette(float(playing.hue)).accent
	var pnl := panel(Vector2(680, 0), accent)
	win_box.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pnl.add_child(v)
	v.add_child(_label(str(playing.name), 42, accent, 11))
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 40)
	v.add_child(grid)
	var coins := 0
	for c in result.coins:
		if c:
			coins += 1
	for item in [["Attempts", str(result.attempts)], ["Flips", str(result.flips)], ["Time", LevelCard.fmt_time(float(result.time))],
			["Coins", "%d / 3" % coins], ["Shards", str(result.shards_picked)]]:
		var cell := VBoxContainer.new()
		cell.add_child(_label(str(item[0]), 20, Color(1, 1, 1, 0.65), 6))
		cell.add_child(_label(str(item[1]), 34, Color.WHITE, 9))
		grid.add_child(cell)
	var reward: Label = null
	if result.practice:
		v.add_child(_label("Practice run: no rewards, but now you know the route.", 22, Color("7ee04a"), 6))
	else:
		var parts := PackedStringArray()
		if int(result.stars) > 0:
			parts.append("+%d Stars" % int(result.stars))
		parts.append("+%d Shards" % int(result.shards))
		if int(result.prisms) > 0:
			parts.append("+%d Prisms" % int(result.prisms))
		reward = _label("   ".join(parts), 40, Color("ffd34d"), 12)
		v.add_child(reward)
		if result.perfect:
			v.add_child(_label("Perfect! Beaten on the first attempt", 22, Color("8ee53f"), 7))
		if int(result.new_coins) > 0:
			v.add_child(_label("New secret coins: %d (+1 prism each)" % int(result.new_coins), 22, Color("ffd34d"), 7))
	if not result.unlocks.is_empty():
		var ul := _label("Unlocked:  " + ", ".join(PackedStringArray(result.unlocks)), 22, Color("ff9ae6"), 7)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size = Vector2(620, 0)
		v.add_child(ul)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	row.add_child(button("circle", Color("ffb13d"), "restart", "", Vector2(92, 92), func(): start_level(playing, play_practice, back_to, on_level_won)))
	row.add_child(button("circle", Color("5ce1ff"), "list", "", Vector2(92, 92), func(): go(back_to)))
	var idx: int = playing.get("index", -1)
	if idx >= 0 and idx + 1 < mains.size():
		row.add_child(button("circle", Color("8ee53f"), "right", "", Vector2(92, 92), func(): play_main(idx + 1, false)))

	await get_tree().process_frame
	if not is_instance_valid(pnl):
		return
	var vp := get_viewport().get_visible_rect().size
	pnl.position = Vector2((vp.x - pnl.size.x) * 0.5, -pnl.size.y - 40.0)
	var target_y := clampf(vp.y * 0.27, 10.0, maxf(10.0, vp.y - pnl.size.y - 16.0))
	var tw := pnl.create_tween()
	tw.tween_property(pnl, "position:y", target_y, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if reward:
		reward.pivot_offset = reward.size * 0.5
		reward.scale = Vector2.ZERO
		tw.tween_callback(Audio.sfx.bind("unlock"))
		tw.tween_property(reward, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------- Settings ----------

func show_settings() -> void:
	var root := new_screen("settings")
	frame(root, "Settings", show_menu, Color("b9a6ff"))
	var center := center_box(root)
	var pnl := panel(Vector2(760, 0))
	center.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pnl.add_child(v)
	for row in [["music_vol", "Music volume"], ["sfx_vol", "Sound volume"]]:
		var h := HBoxContainer.new()
		v.add_child(h)
		var l := _label(str(row[1]), 24, Color.WHITE, 7)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.custom_minimum_size = Vector2(260, 0)
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Save.setting(row[0]))
		sl.custom_minimum_size = Vector2(400, 32)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = row[0]
		sl.value_changed.connect(func(val):
			Save.set_setting(key, val)
			Audio.apply_volume()
			if key == "sfx_vol":
				Audio.sfx("click"))
		h.add_child(sl)
	var toggles := [["music", "Music"], ["sfx", "Sound effects"], ["percent", "Show progress bar"], ["attempt_text", "Show attempt counter"],
		["shake", "Screen shake"], ["flash", "Win flash"], ["ghost", "Show your best-run ghost"], ["auto_cp", "Auto checkpoints in practice"],
		["low_detail", "Low detail (faster on old devices)"]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for row in toggles:
		var cb := CheckButton.new()
		cb.text = str(row[1])
		cb.button_pressed = bool(Save.setting(row[0]))
		cb.add_theme_font_override("font", FONT)
		cb.add_theme_font_size_override("font_size", 20)
		var key: String = row[0]
		cb.toggled.connect(func(on):
			Save.set_setting(key, on)
			if key == "music":
				Audio.music_setting_changed())
		grid.add_child(cb)
	var confirm := _label("", 20, Color("ff8a8a"), 6)
	var reset := button("round", Color("ff5c5c"), "", "Erase all progress", Vector2(300, 56), func():
		if confirm.text == "":
			confirm.text = "Press again to erase everything. This can't be undone."
		else:
			Save.reset_all()
			go(show_menu))
	v.add_child(reset)
	v.add_child(confirm)
	var help := _label("Click, tap or Space flips. Z / X add or remove a practice checkpoint. R restarts. Esc pauses.", 17, Color(1, 1, 1, 0.6), 5)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)


# ---------- Secret codes ----------

func show_codes() -> void:
	var root := new_screen("codes")
	frame(root, "The Lock", show_menu, Color("ffd34d"))
	var center := center_box(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var keeper = Widget.new()
	keeper.kind = "keeper"
	keeper.idx = 3
	keeper.custom_minimum_size = Vector2(220, 190)
	keeper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(keeper)
	var say := _label("Whisper a word to the lock. Some words open things.", 24, Color(1, 1, 1, 0.85), 7)
	v.add_child(say)
	var input := LineEdit.new()
	input.placeholder_text = "Type a code"
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.custom_minimum_size = Vector2(420, 56)
	input.add_theme_font_override("font", FONT)
	input.add_theme_font_size_override("font_size", 28)
	input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(input)
	var submit := func(_t = ""):
		var r: Dictionary = Save.redeem_code(input.text)
		say.text = r.text
		say.add_theme_color_override("font_color", Color("8ee53f") if r.ok else Color("ff8a8a"))
		Audio.sfx("unlock" if r.ok else "deny")
		input.text = ""
	input.text_submitted.connect(submit)
	v.add_child(button("round", Color("ffd34d"), "unlock", "Try it", Vector2(220, 60), submit))
	var used := 0
	for c in Catalog.CODES:
		if Save.claimed("code:" + c):
			used += 1
	v.add_child(_label("Codes found: %d / %d.   Hint: what can't the cube do?" % [used, Catalog.CODES.size()], 18, Color(1, 1, 1, 0.55), 5))
