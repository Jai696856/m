extends Control
## On-screen controls for phones and tablets. A floating joystick on the left half,
## drag on the right half to look around, and buttons that press the same input
## actions the keyboard does.

var game
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var cam_ids := {}            # touch index -> last position
var btn_ids := {}            # touch index -> button name
var buttons: Array = []      # {name, action, label, pos, r, hold, when}
var stick_r := 80.0
var _held := {}


func setup(g) -> void:
	game = g
	name = "Touch"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout() -> void:
	var s := size
	var u := clampf(minf(s.x, s.y) / 9.0, 46.0, 90.0)
	stick_r = u * 1.5
	buttons = [
		{"name": "fire", "action": "fire", "label": "FIRE", "pos": Vector2(s.x - u * 1.6, s.y - u * 1.7), "r": u * 0.95, "hold": true, "when": "any"},
		{"name": "jump", "action": "jump", "label": "JUMP", "pos": Vector2(s.x - u * 3.6, s.y - u * 1.1), "r": u * 0.7, "hold": true, "when": "foot"},
		{"name": "brake", "action": "handbrake", "label": "DRIFT", "pos": Vector2(s.x - u * 3.6, s.y - u * 1.1), "r": u * 0.7, "hold": true, "when": "car"},
		{"name": "car", "action": "enter_exit", "label": "CAR", "pos": Vector2(s.x - u * 1.4, s.y - u * 4.0), "r": u * 0.65, "hold": false, "when": "any"},
		{"name": "ability", "action": "ability", "label": "ABIL", "pos": Vector2(s.x - u * 5.1, s.y - u * 1.3), "r": u * 0.55, "hold": false, "when": "any"},
		{"name": "phone", "action": "phone", "label": "PHONE", "pos": Vector2(s.x * 0.5 - u * 1.5, u * 0.7), "r": u * 0.42, "hold": false, "when": "any"},
		{"name": "weapon", "action": "next_weapon", "label": "GUN", "pos": Vector2(s.x - u * 3.1, s.y - u * 3.1), "r": u * 0.5, "hold": false, "when": "any"},
		{"name": "flip", "action": "reset_car", "label": "FLIP", "pos": Vector2(s.x - u * 3.1, s.y - u * 3.1), "r": u * 0.5, "hold": false, "when": "car_flipped"},
		{"name": "horn", "action": "horn", "label": "HORN", "pos": Vector2(s.x - u * 4.3, s.y - u * 2.6), "r": u * 0.45, "hold": false, "when": "car"},
		{"name": "pause", "action": "pause", "label": "II", "pos": Vector2(s.x * 0.5 + u * 1.5, u * 0.7), "r": u * 0.42, "hold": false, "when": "any"},
		{"name": "map", "action": "map", "label": "MAP", "pos": Vector2(s.x * 0.5 + u * 0.5, u * 0.7), "r": u * 0.42, "hold": false, "when": "any"},
		{"name": "swap", "action": "switch_hero", "label": "SWAP", "pos": Vector2(s.x * 0.5 - u * 0.5, u * 0.7), "r": u * 0.42, "hold": false, "when": "any"},
	]


func _label(b: Dictionary) -> String:
	if b.name == "car" and game.player.in_car == null and not game.find_interaction(game.player.global_position).is_empty():
		return "USE"
	return b.label


func _visible_now(b: Dictionary) -> bool:
	var p = game.player
	match b.when:
		"foot":
			return p.in_car == null
		"car":
			return p.in_car != null
		"car_flipped":
			return p.in_car != null and p.in_car.upside_down_t > 0.5
	if b.name == "weapon" and p.in_car != null and p.in_car.upside_down_t > 0.5:
		return false
	return true


func _button_at(pos: Vector2):
	for b in buttons:
		if _visible_now(b) and pos.distance_to(b.pos) < b.r * 1.15:
			return b
	return null


func _press(action: String, strength := 1.0) -> void:
	Input.action_press(action, strength)
	_held[action] = true


func _release(action: String) -> void:
	Input.action_release(action)
	_held.erase(action)


func _input(event: InputEvent) -> void:
	if not visible or game.hud.intro.visible:
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if get_tree().paused:
				return
			var b = _button_at(pos)
			if b != null:
				btn_ids[event.index] = b.name
				if b.hold:
					_press(b.action)
				else:
					var e := InputEventAction.new()
					e.action = b.action
					e.pressed = true
					Input.parse_input_event(e)
					_press(b.action)
					get_tree().create_timer(0.08, true).timeout.connect(func(): _release(b.action))
				get_viewport().set_input_as_handled()
			elif pos.x < size.x * 0.45 and stick_id == -1:
				stick_id = event.index
				stick_origin = pos
				stick_pos = pos
				get_viewport().set_input_as_handled()
			else:
				cam_ids[event.index] = pos
		else:
			if event.index == stick_id:
				stick_id = -1
				_apply_stick(Vector2.ZERO)
			if btn_ids.has(event.index):
				var nm: String = btn_ids[event.index]
				btn_ids.erase(event.index)
				for b in buttons:
					if b.name == nm and b.hold:
						_release(b.action)
			cam_ids.erase(event.index)
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick_pos = event.position
			var v: Vector2 = (stick_pos - stick_origin) / stick_r
			if v.length() > 1.0:
				stick_origin = stick_pos - v.normalized() * stick_r
				v = v.normalized()
			_apply_stick(v)
			get_viewport().set_input_as_handled()
		elif cam_ids.has(event.index) or btn_ids.has(event.index):
			if btn_ids.has(event.index) and btn_ids[event.index] != "fire":
				return
			var rel: Vector2 = event.relative
			if rel.length() < 120.0:  # a finger landing can register as one huge jump
				game.cam.look(rel.x * 0.006, rel.y * 0.005)


func _apply_stick(v: Vector2) -> void:
	var dead := 0.12
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_forward", -v.y], ["move_back", v.y]]:
		var strength: float = pair[1]
		if strength > dead:
			_press(pair[0], clampf((strength - dead) / (1.0 - dead), 0.0, 1.0))
		else:
			_release(pair[0])
	if v.length() > 0.92 and game.player.in_car == null:
		_press("sprint")
	else:
		_release("sprint")


func release_all() -> void:
	for a in _held.keys():
		Input.action_release(a)
	_held.clear()
	stick_id = -1
	cam_ids.clear()
	btn_ids.clear()


func _process(_delta: float) -> void:
	if not visible:
		return
	_layout()
	queue_redraw()


func _draw() -> void:
	if game.hud.intro.visible or get_tree().paused:
		return
	var font := ThemeDB.fallback_font
	if stick_id != -1:
		draw_circle(stick_origin, stick_r, Color(1, 1, 1, 0.12))
		draw_arc(stick_origin, stick_r, 0, TAU, 40, Color(1, 1, 1, 0.4), 3.0, true)
		draw_circle(stick_pos, stick_r * 0.42, Color(1, 1, 1, 0.45))
	else:
		var hint_pos := Vector2(size.x * 0.16, size.y * 0.72)
		draw_arc(hint_pos, stick_r * 0.8, 0, TAU, 40, Color(1, 1, 1, 0.18), 2.0, true)
		draw_string(font, hint_pos + Vector2(-40, 6), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(1, 1, 1, 0.35))
	for b in buttons:
		if not _visible_now(b):
			continue
		var held := false
		for k in btn_ids:
			if btn_ids[k] == b.name:
				held = true
		var col := Color(1.0, 0.35, 0.55, 0.55) if b.name == "fire" else Color(0.1, 0.08, 0.2, 0.5)
		if held:
			col = col.lightened(0.35)
		draw_circle(b.pos, b.r, col)
		draw_arc(b.pos, b.r, 0, TAU, 36, Color(1, 1, 1, 0.55), 2.5, true)
		var fs := int(clampf(b.r * 0.42, 12.0, 26.0))
		draw_string(font, b.pos + Vector2(-b.r, fs * 0.35), _label(b), HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0, fs, Color(1, 1, 1, 0.95))
