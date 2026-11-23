extends CanvasLayer
## Heads-up display: rotating minimap, full map, wanted stars, health and armour,
## money, weapon, mission objective and timer, big messages, pause and intro screens.

var game
var root: Control
var overlay: Control
var minimap: Control
var bigmap: Control
var lbl_money: Label
var lbl_clock: Label
var lbl_weapon: Label
var lbl_obj: Label
var lbl_big: Label
var lbl_big_sub: Label
var lbl_timer: Label
var lbl_hint: Label
var lbl_notice: Label
var lbl_vehicle: Label
var lbl_speed: Label
var lbl_sub: Label
var pause_panel: Control
var intro: Control
var objective := ""
var big_t := 0.0
var notice_t := 0.0
var sub_t := 0.0
var vehicle_t := 0.0
var stars_flash := 0.0
var money_shown := 0.0
var show_map := false
var heading_font: Font
var feed: RichTextLabel
var feed_box: PanelContainer
var posts: Array = []   # [handle, text, time_left]
var history: Array = [] # last posts for the phone's Chirp app
var lbl_hero: Label


func setup(g) -> void:
	game = g
	name = "Hud"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Impact", "Anton", "Bebas Neue", "Arial Black", "DejaVu Sans"])
	sf.font_weight = 900
	heading_font = sf
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = Overlay.new()
	overlay.hud = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	minimap = Minimap.new()
	minimap.game = game
	minimap.clip_contents = true
	var mask := Shader.new()
	mask.code = """shader_type canvas_item;
// Round radar: everything the minimap draws is cut to a circle with a soft edge.
uniform vec2 size = vec2(240.0);
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	float r = min(size.x, size.y) * 0.5;
	float d = length(local - size * 0.5);
	COLOR.a *= 1.0 - smoothstep(r - 1.5, r, d);
}"""
	var mmat := ShaderMaterial.new()
	mmat.shader = mask
	minimap.material = mmat
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	bigmap = Minimap.new()
	bigmap.game = game
	bigmap.big = true
	bigmap.clip_contents = true
	bigmap.visible = false
	bigmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bigmap)
	lbl_money = _label(40, Color(0.45, 1.0, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, true)
	lbl_clock = _label(26, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_weapon = _label(22, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_obj = _label(26, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	lbl_sub = _label(24, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_big = _label(96, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, true)
	lbl_big_sub = _label(34, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	lbl_timer = _label(40, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, true)
	lbl_hint = _label(22, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
	lbl_notice = _label(26, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_LEFT)
	lbl_vehicle = _label(40, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, true)
	lbl_speed = _label(30, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, true)
	lbl_hero = _label(22, Color(1.0, 0.65, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, true)
	_build_feed()
	_build_pause()
	_build_intro()


func _label(size: int, color: Color, align: HorizontalAlignment, heading := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	if heading:
		l.add_theme_font_override("font", heading_font)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _build_feed() -> void:
	feed_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.12, 0.62)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	feed_box.add_theme_stylebox_override("panel", sb)
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed_box)
	feed = RichTextLabel.new()
	feed.bbcode_enabled = true
	feed.fit_content = true
	feed.scroll_active = false
	feed.custom_minimum_size = Vector2(400, 0)
	feed.add_theme_font_size_override("normal_font_size", 16)
	feed.add_theme_font_size_override("bold_font_size", 16)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.add_child(feed)
	feed_box.visible = false


func add_post(handle: String, text: String) -> void:
	posts.push_front([handle, text, 14.0])
	history.push_front([handle, text])
	if history.size() > 15:
		history.resize(15)
	if posts.size() > 3:
		posts.resize(3)
	_refresh_feed()


func _refresh_feed() -> void:
	var b := "[color=#ff7ab8][b]CHIRP[/b][/color]  [color=#aaaaaa]trending in Sunset Shores[/color]\n"
	for p in posts:
		b += "[color=#7fd8ff][b]%s[/b][/color]  %s\n" % [p[0], p[1]]
	feed.text = b.strip_edges()
	feed_box.visible = not posts.is_empty()
	feed_box.reset_size()


func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", sb)
	return p


const CONTROLS_TEXT := """WASD / left stick    Move, or drive
Mouse / right stick   Look around
Shift                 Sprint
Space                 Jump  (handbrake in a car)
F                     Enter, exit or steal a car
Left click / RB       Shoot (works from a car too)
Right click / LB      Aim
Q / mouse wheel       Switch weapon
R                     Flip the car upright
H                     Horn          T   Radio on/off
Tab                   Switch between Marisol and Cole
V                     Special ability       C   Phone
M                     Full map      Esc   Pause"""


const TOUCH_TEXT := """Left thumb       Move (push all the way to sprint), or drive
Right thumb      Drag to look around
FIRE             Shoot          JUMP / DRIFT   Jump or handbrake
CAR              Get in, out or steal a car
GUN  MAP  SWAP   Switch weapon, full map, Marisol / Cole
ABIL  PHONE      Special ability, in-game phone"""


func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var panel := _panel(Color(0.08, 0.06, 0.16, 0.95))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_override("font", heading_font)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var stats := Label.new()
	stats.name = "Stats"
	stats.add_theme_font_size_override("font_size", 18)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stats)
	var ctl := Label.new()
	ctl.text = TOUCH_TEXT if game.touch_mode else CONTROLS_TEXT
	ctl.add_theme_font_size_override("font_size", 18)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	ctl.add_theme_font_override("font", mono)
	vb.add_child(ctl)
	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(260, 48)
	resume.pressed.connect(func(): set_paused(false))
	vb.add_child(resume)
	var quit := Button.new()
	quit.text = "Quit to desktop"
	quit.custom_minimum_size = Vector2(260, 48)
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)


func _build_intro() -> void:
	intro = Control.new()
	intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(intro)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)
	var title := Label.new()
	title.text = "SUNSET SHORES"
	title.add_theme_font_override("font", heading_font)
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.65))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.3))
	title.add_theme_constant_override("outline_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var tag := Label.new()
	tag.text = "Steal cars. Run jobs. Stay ahead of the law."
	tag.add_theme_font_size_override("font_size", 28)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag.add_theme_constant_override("outline_size", 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)
	var ctl := Label.new()
	ctl.text = (TOUCH_TEXT if game.touch_mode else CONTROLS_TEXT) + "\n\nWalk into the coloured beam on the minimap to start a job."
	ctl.add_theme_font_size_override("font_size", 20)
	ctl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	ctl.add_theme_constant_override("outline_size", 6)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	ctl.add_theme_font_override("font", mono)
	vb.add_child(ctl)
	var go := Label.new()
	go.text = "Tap to play" if game.touch_mode else "Click or press any key to play"
	go.name = "Go"
	go.add_theme_font_size_override("font_size", 30)
	go.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	go.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	go.add_theme_constant_override("outline_size", 8)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(go)


func set_paused(p: bool) -> void:
	get_tree().paused = p
	pause_panel.visible = p
	if p:
		var s: Dictionary = game.stats
		(pause_panel.find_child("Stats", true, false) as Label).text = "Missions passed: %d    Cars stolen: %d    Cars destroyed: %d    Takedowns: %d" % [s.missions, s.cars_stolen, s.cars_destroyed, s.kills]
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not game.headless and not game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if intro.visible:
		return
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not game.headless and not game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("map"):
		show_map = not show_map
	if event.is_action_pressed("radio"):
		game.sfx.toggle_radio()


# --- messages -----------------------------------------------------------------------

func big_message(text: String, sub: String, color: Color, time: float) -> void:
	lbl_big.text = text
	lbl_big.add_theme_color_override("font_color", color)
	lbl_big_sub.text = sub
	big_t = time


func notice(text: String) -> void:
	lbl_notice.text = text
	notice_t = 3.5


func subtitle(text: String, time: float) -> void:
	lbl_sub.text = text
	sub_t = time


func show_vehicle(vname: String) -> void:
	lbl_vehicle.text = vname
	vehicle_t = 3.0
	if game.sfx.radio_ready and game.sfx.radio_on:
		notice("Palm FM  (T to switch off)")


func flash_stars() -> void:
	stars_flash = 2.0


## The title screen is dismissed here, before the GUI sees the click or tap.
func _input(event: InputEvent) -> void:
	if intro == null or not intro.visible:
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch) and event.is_pressed():
		intro.visible = false
		get_tree().paused = false
		if not game.headless and not game.touch_mode:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if root == null or game == null or lbl_money == null:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	var s := root.get_viewport_rect().size
	var p = game.player
	big_t -= real_dt
	notice_t -= real_dt
	sub_t -= real_dt
	vehicle_t -= real_dt
	stars_flash -= real_dt
	money_shown = move_toward(money_shown, game.money, maxf(40.0, absf(game.money - money_shown) * 4.0) * real_dt)
	lbl_money.text = "$%08d" % int(money_shown)
	lbl_hero.text = p.crew[p.hero].name.to_upper()
	lbl_hero.position = Vector2(s.x - 420, 178)
	lbl_hero.size = Vector2(390, 30)
	var changed := false
	for post in posts:
		post[2] -= real_dt
		if post[2] <= 0.0:
			changed = true
	if changed:
		posts = posts.filter(func(q): return q[2] > 0.0)
		_refresh_feed()
	feed_box.position = Vector2(18, 18 + clampf(s.y * 0.24, 130.0, 280.0) + 44) if game.touch_mode else Vector2(26, 104)
	lbl_money.position = Vector2(s.x - 420, 58)
	lbl_money.size = Vector2(390, 50)
	var h := int(game.hour)
	var m := int((game.hour - h) * 60.0)
	lbl_clock.text = "%02d:%02d" % [h, m]
	lbl_clock.position = Vector2(s.x - 220, 22)
	lbl_clock.size = Vector2(190, 36)
	var w: Dictionary = p.weapons[p.weapon]
	lbl_weapon.text = w.name + ("" if w.ammo < 0 else "  %d" % w.ammo)
	lbl_weapon.position = Vector2(s.x - 420, 150)
	lbl_weapon.size = Vector2(390, 30)
	var touch: bool = game.touch_mode
	var map_size := clampf(s.y * (0.24 if touch else 0.27), 130.0, 280.0)
	minimap.position = Vector2(26, 26) if touch else Vector2(36, s.y - map_size - 36)
	minimap.size = Vector2(map_size, map_size)
	(minimap.material as ShaderMaterial).set_shader_parameter("size", minimap.size)
	bigmap.visible = show_map
	if show_map:
		var bs := minf(s.x - 120, s.y - 120)
		bigmap.size = Vector2(bs, bs)
		bigmap.position = (s - bigmap.size) * 0.5
	minimap.queue_redraw()
	if show_map:
		bigmap.queue_redraw()
	lbl_obj.text = objective
	lbl_obj.position = Vector2(s.x * 0.5 - 600, s.y - 90)
	lbl_obj.size = Vector2(1200, 40)
	lbl_sub.visible = sub_t > 0.0
	lbl_sub.position = Vector2(s.x * 0.5 - 520, s.y - 190)
	lbl_sub.size = Vector2(1040, 90)
	lbl_big.visible = big_t > 0.0
	lbl_big_sub.visible = big_t > 0.0
	lbl_big.modulate.a = clampf(big_t * 2.0, 0.0, 1.0)
	lbl_big_sub.modulate.a = lbl_big.modulate.a
	lbl_big.position = Vector2(0, s.y * 0.32)
	lbl_big.size = Vector2(s.x, 120)
	lbl_big_sub.position = Vector2(0, s.y * 0.32 + 118)
	lbl_big_sub.size = Vector2(s.x, 50)
	var tl: float = game.missions.timer_left()
	lbl_timer.visible = tl >= 0.0
	if tl >= 0.0:
		lbl_timer.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60]
		lbl_timer.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if tl < 10.0 else Color(1, 1, 1))
		lbl_timer.position = Vector2(s.x * 0.5 - 150, 24)
		lbl_timer.size = Vector2(300, 50)
	lbl_hint.text = game.hint
	lbl_hint.visible = game.hint != "" and game.state == "play"
	lbl_hint.position = Vector2(30, 26)
	lbl_hint.size = Vector2(700, 30)
	if game.touch_mode:
		lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_hint.position = Vector2(s.x * 0.5 - 400, 110)
		lbl_hint.size = Vector2(800, 30)
		lbl_hint.text = lbl_hint.text.replace("Press F to", "Tap CAR to").replace("Press R to", "Tap FLIP to")
	lbl_notice.visible = notice_t > 0.0
	lbl_notice.position = Vector2(30, 62)
	lbl_notice.size = Vector2(700, 34)
	if game.touch_mode:
		lbl_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_notice.position = Vector2(s.x * 0.5 - 400, 146)
		lbl_notice.size = Vector2(800, 34)
	var car = p.in_car
	lbl_vehicle.visible = car != null and vehicle_t > 0.0
	lbl_vehicle.position = Vector2(s.x - 520, s.y - 150)
	lbl_vehicle.size = Vector2(490, 50)
	lbl_speed.visible = car != null
	if car:
		lbl_speed.text = "%d km/h" % int(absf(car.forward_speed()) * 3.6)
	lbl_speed.position = Vector2(s.x - 320, s.y - 70)
	lbl_speed.size = Vector2(290, 40)
	var go := intro.find_child("Go", true, false) as Label
	if go:
		go.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.005)
	overlay.queue_redraw()


# --- drawing --------------------------------------------------------------------------

class Overlay extends Control:
	var hud

	## A curved bar: background track, then the filled part from `a0` toward `a1`.
	func _gauge(c: Vector2, r: float, a0: float, a1: float, frac: float, col: Color) -> void:
		draw_arc(c, r, a0, a1, 32, Color(0, 0, 0, 0.6), 9.0, true)
		if frac > 0.005:
			draw_arc(c, r, a0, lerpf(a0, a1, frac), 32, col, 6.0, true)

	func _star(c: Vector2, r: float, col: Color, filled: bool) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + i * PI / 5.0
			var rr := r if i % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		if filled:
			draw_colored_polygon(pts, col)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0, 0, 0, 0.8) if filled else col, 2.0, true)

	func _draw() -> void:
		var game = hud.game
		var s := size
		var p = game.player
		if p.hurt_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.8, 0.0, 0.0, p.hurt_flash * 0.35))
		if game.state != "play":
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, 0.25))
		# wanted stars
		var police = game.police
		var blink: bool = (police.searching() or hud.stars_flash > 0.0) and fmod(Time.get_ticks_msec() * 0.003, 1.0) < 0.5
		for i in 5:
			var c := Vector2(s.x - 52 - i * 42, 128)
			var on: bool = i < police.wanted
			if on and not blink:
				_star(c, 17, Color(1.0, 0.85, 0.25), true)
			else:
				_star(c, 17, Color(1, 1, 1, 0.35), false)
		# crosshair
		if p.in_car == null and not p.dead and game.state == "play" and not hud.intro.visible:
			var cc := s * 0.5
			var g := 6.0 if p.aiming else 10.0
			var col := Color(1, 1, 1, 0.9)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(cc + d * g, cc + d * (g + 8.0), Color(0, 0, 0, 0.6), 4.0)
				draw_line(cc + d * g, cc + d * (g + 8.0), col, 2.0)
		# the radar's rim, with health / armour / special as curved gauges around it
		var mm: Control = hud.minimap
		var c := mm.position + mm.size * 0.5
		var r := mm.size.x * 0.5
		draw_arc(c, r + 2.0, 0.0, TAU, 72, Color(0.04, 0.03, 0.08, 0.95), 6.0, true)
		var hp: float = clampf(p.health / 100.0, 0.0, 1.0)
		var hc := Color(0.3, 0.9, 0.35) if hp > 0.3 else Color(0.95, 0.25, 0.2)
		var tint: Color = p.crew[p.hero].tint
		# health: lower-left quarter, filling upward from the bottom
		_gauge(c, r + 11.0, PI * 0.5, PI * 0.5 + PI * 0.48, hp, hc)
		# armour: lower-right quarter
		_gauge(c, r + 11.0, PI * 0.5, PI * 0.5 - PI * 0.48, clampf(p.armor / 100.0, 0.0, 1.0), Color(0.35, 0.6, 1.0))
		# special: an inner band along the top
		_gauge(c, r + 11.0, PI * 1.5 - PI * 0.4, PI * 1.5 + PI * 0.4, clampf(p.special / 100.0, 0.0, 1.0), tint if not p.ability_on else tint.lightened(0.4))
		if p.ability_on:
			draw_rect(Rect2(Vector2.ZERO, s), Color(tint.r, tint.g, tint.b, 0.1))
		# car health
		if p.in_car:
			var ch: float = clampf(p.in_car.health / 100.0, 0.0, 1.0)
			var r := Rect2(s.x - 320, s.y - 30, 290, 8)
			draw_rect(r.grow(2), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(r.position, Vector2(r.size.x * ch, r.size.y)), Color(1.0, 0.65, 0.2) if ch > 0.3 else Color(1, 0.2, 0.15))


class Minimap extends Control:
	var game
	var big := false
	var _p := Vector3.ZERO
	var _yaw := 0.0
	var _scale := 1.0
	var _c := Vector2.ZERO

	var _island := PackedVector2Array()
	var _inland := PackedVector2Array()

	## The coastline pushed in (negative) or out by `off` metres.
	func _outline(poly: PackedVector2Array, off: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		var n := poly.size()
		var cen := Vector2.ZERO
		for q in poly:
			cen += q
		cen /= n
		for k in n:
			var t := (poly[(k + 1) % n] - poly[(k - 1 + n) % n]).normalized()
			var nrm := Vector2(-t.y, t.x)
			if nrm.dot(poly[k] - cen) < 0.0:
				nrm = -nrm
			out.append(poly[k] + nrm * off)
		return out

	func _w2s(w: Vector3) -> Vector2:
		return Vector2(w.x - _p.x, w.z - _p.z).rotated(_yaw) * _scale + _c

	func _quad(cx: float, cz: float, hx: float, hz: float, col: Color) -> void:
		var pts := PackedVector2Array([
			_w2s(Vector3(cx - hx, 0, cz - hz)), _w2s(Vector3(cx + hx, 0, cz - hz)),
			_w2s(Vector3(cx + hx, 0, cz + hz)), _w2s(Vector3(cx - hx, 0, cz + hz))])
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var city = game.city
		var s := size
		if s.x < 24.0 or s.y < 24.0:
			return
		_c = s * 0.5
		if big:
			_p = Vector3(157.0, 0, -95.0)
			_yaw = 0.0
			_scale = s.x / 1560.0
		else:
			_p = game.player_pos()
			_yaw = game.cam.yaw
			var spd := 0.0
			if game.player.in_car:
				spd = absf(game.player.in_car.forward_speed())
			_scale = lerpf(1.0, 0.55, clampf(spd / 40.0, 0.0, 1.0)) * s.x / 240.0
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.14, 0.42, 0.6, 0.95))
		var view_r: float = s.length() * 0.5 / _scale + 60.0
		# the island: a sandy rim, then the land inside it
		var t = city.terrain
		if _island.is_empty():
			_island = _outline(t.coast, 0.0)
			_inland = _outline(t.coast, -30.0)
		var pts := PackedVector2Array()
		for q in _island:
			pts.append(_w2s(Vector3(q.x, 0, q.y)))
		draw_colored_polygon(pts, Color(0.85, 0.78, 0.58))
		pts = PackedVector2Array()
		for q in _inland:
			pts.append(_w2s(Vector3(q.x, 0, q.y)))
		draw_colored_polygon(pts, Color(0.33, 0.45, 0.28))
		# Mount Sol and the hills
		for hill in [[Vector3(590, 0, -690), 150.0, 0.38], [Vector3(-120, 0, -575), 95.0, 0.4], [Vector3(250, 0, 560), 85.0, 0.4]]:
			draw_circle(_w2s(hill[0]), float(hill[1]) * _scale, Color(0.27, 0.37, 0.22, hill[2]))
			draw_circle(_w2s(hill[0]), float(hill[1]) * 0.5 * _scale, Color(0.45, 0.42, 0.36, hill[2]))
		_quad(-375.0, 0.0, 45.0, 345.0, Color(0.85, 0.78, 0.58))
		_quad(0.0, 0.0, city.HALF + 8.0, city.HALF + 8.0, Color(0.2, 0.2, 0.22))
		# coastal highway and side roads
		var road_w := maxf(2.0, 15.0 * _scale)
		var lines: Array = [t.hwy]
		lines.append_array(t.connectors)
		for pl in lines:
			var sp := PackedVector2Array()
			for q in pl:
				sp.append(_w2s(q))
			draw_polyline(sp, Color(0.2, 0.2, 0.22), road_w, true)
		for pool in city.pools:
			var mc: Vector3 = pool[0]
			draw_circle(_w2s(mc), (float(pool[1]) + 40.0) * _scale, Color(0.24, 0.32, 0.18, 0.55))
		for pool in city.pools:
			var pc: Vector3 = pool[0]
			if big or Vector2(pc.x - _p.x, pc.z - _p.z).length() < view_r + 30.0:
				draw_circle(_w2s(pc), float(pool[1]) * _scale, Color(0.12, 0.3, 0.3))
		for key in city.kinds:
			var k: Vector2i = key
			var c: Vector3 = city.block_center(k.x, k.y)
			if not big and Vector2(c.x - _p.x, c.z - _p.z).length() > view_r + 50.0:
				continue
			var kind: String = city.kinds[key]
			var col := Color(0.55, 0.55, 0.53)
			if kind == "park":
				col = Color(0.35, 0.6, 0.3)
			elif kind == "residential":
				col = Color(0.45, 0.58, 0.38)
			elif kind == "beach":
				col = Color(0.75, 0.7, 0.6)
			_quad(c.x, c.z, 32.0, 32.0, col)
		for r in city.footprints:
			var rc: Rect2 = r
			var cen := rc.get_center()
			if not big and Vector2(cen.x - _p.x, cen.y - _p.z).length() > view_r:
				continue
			_quad(cen.x, cen.y, rc.size.x * 0.5, rc.size.y * 0.5, Color(0.36, 0.36, 0.38))
		var blips: Array = game.get_blips()
		for b in blips:
			var pos: Vector3 = b[0]
			var col: Color = b[1]
			var kind: String = b[2]
			var sp := _w2s(pos)
			var important: bool = kind in ["objective", "target", "contact"]
			var edge := s.x * 0.5 - 10.0
			var inside := (sp - _c).length() < edge if not big else Rect2(Vector2(6, 6), s - Vector2(12, 12)).has_point(sp)
			if not inside:
				if not important:
					continue
				if big:
					sp = Vector2(clampf(sp.x, 8, s.x - 8), clampf(sp.y, 8, s.y - 8))
				else:
					sp = _c + (sp - _c).normalized() * edge
			var r := 4.0
			match kind:
				"objective", "contact":
					r = 7.0
				"target", "police":
					r = 6.0
				"hospital", "respray", "partner", "bank", "store":
					r = 6.0
			draw_circle(sp, r + 2.0, Color(0, 0, 0, 0.75))
			draw_circle(sp, r, col)
			if kind == "hospital":
				draw_line(sp - Vector2(3, 0), sp + Vector2(3, 0), Color.WHITE, 2.0)
				draw_line(sp - Vector2(0, 3), sp + Vector2(0, 3), Color.WHITE, 2.0)
		# player arrow
		var pp: Vector3 = game.player_pos()
		var fwd := Vector3(0, 0, -1)
		if game.player.in_car:
			fwd = -game.player.in_car.global_transform.basis.z
		else:
			fwd = game.player.model.global_transform.basis.z * -1.0
		var ang := Vector2(fwd.x, fwd.z).rotated(_yaw).angle()
		var ap := _w2s(pp)
		var tri := PackedVector2Array([ap + Vector2(9, 0).rotated(ang), ap + Vector2(-6, 6).rotated(ang), ap + Vector2(-6, -6).rotated(ang)])
		draw_colored_polygon(tri, Color(0, 0, 0, 0.8))
		var tri2 := PackedVector2Array([ap + Vector2(7, 0).rotated(ang), ap + Vector2(-4.5, 4.5).rotated(ang), ap + Vector2(-4.5, -4.5).rotated(ang)])
		draw_colored_polygon(tri2, Color(1, 1, 1))
		if not big:
			var north := Vector2(0, -1).rotated(_yaw) * (s.x * 0.5 - 12.0) + _c
			draw_circle(north, 9, Color(0, 0, 0, 0.7))
			draw_string(ThemeDB.fallback_font, north + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		if big:
			draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.9), false, 3.0)
		else:
			# soft inner shadow so the radar reads like a lens
			draw_arc(_c, s.x * 0.5 - 4.0, 0.0, TAU, 72, Color(0, 0, 0, 0.35), 8.0, true)
