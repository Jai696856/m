extends Control
## The in-game phone (C, or the PHONE button on a touchscreen). Apps: Contacts
## (GPS to your contacts, the heist, a mechanic who drops off a car), Jobs, Chirp,
## Special ability, Map and Settings. The world keeps running while it's open.

const MECHANIC_COOLDOWN := 45.0

var game
var body: PanelContainer
var title: Label
var content: VBoxContainer
var status: Label
var clock: Label
var screen := "home"
var _open := false
var mechanic_cd := 0.0
var last_delivery = null


func setup(g) -> void:
	game = g
	name = "Phone"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	body = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.12, 0.96)
	sb.border_color = Color(0.25, 0.22, 0.35)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 18
	body.add_theme_stylebox_override("panel", sb)
	add_child(body)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	body.add_child(vb)
	clock = Label.new()
	clock.add_theme_font_size_override("font_size", 14)
	clock.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vb.add_child(clock)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.75))
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	vb.add_child(status)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	vb.add_child(nav)
	nav.add_child(_button("Home", func(): show_screen("home"), 110))
	nav.add_child(_button("Close", func(): close(), 110))
	body.visible = false


func _button(text: String, cb: Callable, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _text(t: String, size := 17, col := Color(0.92, 0.92, 0.96)) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or game.state != "play":
		return
	_open = true
	body.visible = true
	show_screen("home")
	game.sfx.play("click", null, -6.0)
	if not game.headless and not game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	body.visible = false
	if not game.headless and not game.touch_mode and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or game.hud.intro.visible:
		return
	if event.is_action_pressed("phone"):
		toggle()
		get_viewport().set_input_as_handled()


func _say(t: String) -> void:
	status.text = t


func show_screen(s: String) -> void:
	screen = s
	status.text = ""
	for c in content.get_children():
		c.queue_free()
	match s:
		"home":
			title.text = "Shores OS"
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			content.add_child(grid)
			for app in [["Contacts", "contacts"], ["Jobs", "jobs"], ["Chirp", "chirp"], ["Special", "special"], ["Map", "map"], ["Settings", "settings"]]:
				var b := _button(app[0], show_screen.bind(app[1]), 130)
				b.custom_minimum_size.y = 70
				grid.add_child(b)
		"contacts":
			title.text = "Contacts"
			var cp: Array = game.city.contact_points
			content.add_child(_button("Rosa  (car jobs)", _gps.bind(cp[0], "Rosa")))
			content.add_child(_button("Dex  (street races)", _gps.bind(cp[1], "Dex")))
			content.add_child(_button("Lena  (special jobs)", _gps.bind(cp[2], "Lena")))
			content.add_child(_button("Lena: THE HEIST", _call_heist))
			content.add_child(_button("Mechanic: bring me a car", _mechanic))
			content.add_child(_button("GPS: Bay Bank", _gps.bind(game.interiors.bank.entrance, "Bay Bank")))
			content.add_child(_button("GPS: Quick Stop", _gps.bind(game.interiors.store.counter_front + Vector3(0, 0, 7), "Quick Stop")))
			content.add_child(_button("GPS: Respray", _gps.bind(game.city.respray_pos, "Respray")))
			content.add_child(_button("Clear GPS", func(): game.set_waypoint(null); _say("GPS cleared.")))
		"jobs":
			title.text = "Jobs"
			var m = game.missions
			if m.is_active():
				content.add_child(_text("Now: " + m.active.def.title, 19, Color(1, 0.85, 0.4)))
				content.add_child(_text(game.hud.objective))
			else:
				var d: Dictionary = m.next_def()
				content.add_child(_text("Next: %s  (%s)" % [d.title, m.CONTACTS[d.contact]], 19, Color(1, 0.85, 0.4)))
				content.add_child(_button("GPS to %s" % m.CONTACTS[d.contact], _gps.bind(game.city.contact_points[d.contact], m.CONTACTS[d.contact])))
			var why: String = m.can_heist()
			content.add_child(_text("Heist: " + ("ready. Call Lena from Contacts." if why == "" else why)))
			var st: Dictionary = game.stats
			content.add_child(_text("Story jobs done: %d / %d\nHeists: %d   Robberies: %d\nStunts: %d   Cars stolen: %d" % [mini(m.index, m.STORY.size()), m.STORY.size(), st.heists, st.robberies, st.stunts, st.cars_stolen], 15, Color(0.75, 0.75, 0.85)))
		"chirp":
			title.text = "Chirp"
			if game.hud.history.is_empty():
				content.add_child(_text("Nothing trending yet. Go make some news."))
			for p in game.hud.history:
				content.add_child(_text(p[0], 15, Color(0.5, 0.85, 1.0)))
				content.add_child(_text(p[1], 16))
		"special":
			title.text = "Special"
			var pl = game.player
			for i in pl.crew.size():
				var c: Dictionary = pl.crew[i]
				content.add_child(_text("%s: %s" % [c.name, c.ability], 19, c.tint))
				content.add_child(_text(c.ability_text + ". " + c.perk_text.split(".")[0] + ".", 15))
			content.add_child(_text("Meter: %d%%   Press V (or ABIL) to use it." % int(pl.special), 16, Color(1, 0.85, 0.4)))
			content.add_child(_button("Switch to %s" % pl.crew[1 - pl.hero].name, func(): close(); pl.switch_hero()))
		"map":
			close()
			game.hud.show_map = true
		"settings":
			title.text = "Settings"
			content.add_child(_button("Radio: " + ("on" if game.sfx.radio_on else "off"), func(): game.sfx.toggle_radio(); show_screen("settings")))
			content.add_child(_button("Graphics: " + ("lighter" if game.low_spec else "full"), func(): game.set_low_spec(not game.low_spec); show_screen("settings")))
			content.add_child(_text("Lighter graphics: less traffic, cheaper shadows. Good for phones.", 14, Color(0.75, 0.75, 0.85)))


func _gps(pos: Vector3, label: String) -> void:
	game.set_waypoint(pos)
	_say("GPS set to %s." % label)


func _call_heist() -> void:
	var why: String = game.missions.can_heist()
	if why != "":
		_say(why)
		return
	close()
	game.missions.start(game.missions.HEIST)


func _mechanic() -> void:
	if mechanic_cd > 0.0:
		_say("Mechanic: \"Give me %d seconds.\"" % ceili(mechanic_cd))
		return
	var city = game.city
	var pp: Vector3 = game.player_pos()
	var best: Transform3D
	var bd := INF
	for n in [city.nearest_node(pp)]:
		for m in city.neighbors(n):
			var A: Vector3 = city.nodev(n)
			var B: Vector3 = city.nodev(m)
			var d := (B - A).normalized()
			var r := Vector3(-d.z, 0, d.x)
			var pos: Vector3 = A.lerp(B, 0.35) + r * city.PARK_OFF
			var dist: float = pos.distance_to(pp)
			if dist < bd and dist > 6.0:
				bd = dist
				best = Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), pos + Vector3.UP * 0.3)
	var car = game.traffic.spawn_car("sport", Color(0.95, 0.25, 0.55), best)
	mechanic_cd = MECHANIC_COOLDOWN
	game.set_waypoint(best.origin)
	_say("Mechanic: \"Pink Marlin GT, parked on the curb. Try not to scratch it.\"")
	game.sfx.play("horn", best.origin, 0.0)
	last_delivery = car


func _process(delta: float) -> void:
	mechanic_cd -= delta / maxf(Engine.time_scale, 0.05)
	if not _open:
		return
	if game.state != "play":
		close()
		return
	var s := get_viewport_rect().size
	var h := minf(640.0, s.y * 0.86)
	var w := minf(360.0, h * 0.58)
	body.size = Vector2(w, h)
	body.position = Vector2(s.x * 0.5 + 40.0, (s.y - h) * 0.5) if game.touch_mode else Vector2(s.x - w - 40.0, s.y - h - 30.0)
	var hr := int(game.hour)
	clock.text = "%02d:%02d     $%d" % [hr, int((game.hour - hr) * 60.0), game.money]
