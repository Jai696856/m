# Records the game trailer straight from the real game (needs a display):
#
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --fixed-fps 30 \
#       --write-movie /tmp/trailer/f.png -s tools/trailer.gd [-- shot,names]
#
# Godot's movie writer saves every frame as a PNG plus one WAV with the game's sound.
# tools/make_trailer.sh then adds the music and encodes an MP4.
extends SceneTree

const TYPES := ["blue", "green", "gold", "violet", "kitsune", "prism", "shadow", "frost", "lantern", "mask"]

var main: Node3D
var only: Array = []
var layer: CanvasLayer
var fade: ColorRect
var dim: ColorRect
var cap_box: PanelContainer
var cap_lbl: Label
var title_box: VBoxContainer
var title_lbl: Label
var sub_lbl: Label
var cap_age := 0
var cap_total := 0
var fade_v := 1.0
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		only = Array(args[0].split(","))
	rng.seed = 2026
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.save = ConfigFile.new()
	main.progress.save = main.save
	main.save.set_value("settings", "tutorial_seen", true)
	main.save.set_value("settings", "music", false)
	main.music.set_enabled(false)   # the music is mixed in afterwards so it never restarts on a cut
	main.progress.unlock_everything(main.Defs.HERO_ORDER)
	main.progress.add_gems(900)
	for id in ["time_stop", "shrine_bomb"]:
		main.progress.buy_power(id)
	for k in main.Defs.ORDER:
		main.progress.add_to_set("spirits_seen", k)
	main.progress.claim_login(main.Defs.HERO_ORDER)
	main.menu.login_shown = true
	main.ui.toast_box.visible = false
	_build_overlay()

	for shot in ["title", "heroes", "play", "upgrade", "abilities", "bosses", "maps", "farm", "powers", "menus", "end"]:
		if only.is_empty() or only.has(shot):
			await call("_shot_" + shot)
	main.queue_free()
	await process_frame
	quit(0)

# ---------------------------------------------------------------------
# Overlay: captions, title card and fades
# ---------------------------------------------------------------------
func _build_overlay() -> void:
	var bold: Font = load("res://fonts/Fredoka-Bold.ttf")
	layer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	dim = ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.12, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	cap_box = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.075, 0.1, 0.19, 0.9)
	st.set_corner_radius_all(30)
	st.content_margin_left = 34
	st.content_margin_right = 34
	st.content_margin_top = 10
	st.content_margin_bottom = 12
	st.border_color = Color(1, 1, 1, 0.12)
	st.set_border_width_all(2)
	st.shadow_color = Color(0, 0, 0, 0.3)
	st.shadow_size = 10
	cap_box.add_theme_stylebox_override("panel", st)
	cap_box.anchor_left = 0.5
	cap_box.anchor_right = 0.5
	cap_box.anchor_top = 1.0
	cap_box.anchor_bottom = 1.0
	cap_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cap_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cap_box.offset_bottom = -54
	cap_box.modulate.a = 0.0
	layer.add_child(cap_box)
	cap_lbl = Label.new()
	cap_lbl.add_theme_font_override("font", bold)
	cap_lbl.add_theme_font_size_override("font_size", 44)
	cap_lbl.add_theme_color_override("font_color", Color.WHITE)
	cap_box.add_child(cap_lbl)

	title_box = VBoxContainer.new()
	title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 4)
	title_box.modulate.a = 0.0
	layer.add_child(title_box)
	title_lbl = Label.new()
	title_lbl.add_theme_font_override("font", bold)
	title_lbl.add_theme_font_size_override("font_size", 104)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_constant_override("outline_size", 22)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.16))
	title_lbl.add_theme_constant_override("line_spacing", -22)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title_lbl)
	sub_lbl = Label.new()
	sub_lbl.add_theme_font_override("font", bold)
	sub_lbl.add_theme_font_size_override("font_size", 38)
	sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	sub_lbl.add_theme_constant_override("outline_size", 12)
	sub_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.16))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(sub_lbl)

	fade = ColorRect.new()
	fade.color = Color(0.03, 0.04, 0.09, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

func _caption(text: String, frames_total: int) -> void:
	cap_lbl.text = text
	cap_age = 0
	cap_total = frames_total

func _cut() -> void:
	fade_v = 1.0

## Advance one recorded frame.
func _frame() -> void:
	fade_v = maxf(0.0, fade_v - 0.2)
	fade.color.a = fade_v
	if cap_total > 0:
		cap_age += 1
		var a := clampf(cap_age / 8.0, 0.0, 1.0) * clampf((cap_total - cap_age) / 7.0, 0.0, 1.0)
		cap_box.modulate.a = a
		cap_box.offset_bottom = -54.0 + (1.0 - clampf(cap_age / 10.0, 0.0, 1.0)) * 26.0
		if cap_age >= cap_total:
			cap_total = 0
	else:
		cap_box.modulate.a = 0.0
	await process_frame

static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

# ---------------------------------------------------------------------
# Game helpers
# ---------------------------------------------------------------------
func _cinematic(hud: bool) -> void:
	main.ui.set_hud_visible(hud)
	main.ui.banner_box.visible = hud
	if main.ui.sandbox_panel:
		main.ui.sandbox_panel.visible = false
	main.select_hero(null)

## Buildable spots next to the track, nearest to `center` first.
func _spots(center: Vector3, max_track_dist: float = 4.6) -> Array:
	var out: Array = []
	for x in range(-32, 28, 2):
		for z in range(-18, 19, 2):
			if main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < max_track_dist:
				out.append(Vector2(x, z))
	out.sort_custom(func(a, b): return a.distance_to(Vector2(center.x, center.z)) < b.distance_to(Vector2(center.x, center.z)))
	return out

func _place(keys: Array, center: Vector3, tiers: int = 0, spread: float = 2.6) -> Array:
	var placed: Array = []
	var cash0: float = main.cash
	main.cash = 1.0e9
	for k in keys:
		for s in _spots(center):
			var ok := true
			for h in main.heroes:
				if Vector2(h.x, h.z).distance_to(s) < spread:
					ok = false
			if not ok:
				continue
			var h = main.place_hero(k, s.x, s.y)
			if h:
				for t in range(tiers):
					main.buy_upgrade(h, placed.size() % 3)
				placed.append(h)
				break
	main.cash = cash0
	main.select_hero(null)
	return placed

func _spread_heroes(keys: Array, tiers: int) -> Array:
	var placed: Array = []
	for i in range(keys.size()):
		var c: Vector3 = main.pos_at(main.path_len * (0.08 + 0.84 * i / maxf(1.0, keys.size() - 1.0)))
		placed.append_array(_place([keys[i]], c, tiers))
	return placed

func _crowd(n: int, from: float = 0.05, to: float = 0.7) -> void:
	for i in range(n):
		main.spawn_enemy(TYPES[rng.randi() % TYPES.size()], main.path_len * rng.randf_range(from, to))

func _preroll(steps: int) -> void:
	for i in range(steps):
		main._step(1.0 / 60.0)

func _cam(target: Vector3, dist: float, pitch: float, yaw: float) -> void:
	main.cam_target = target
	main.cam_dist = dist
	main.cam_pitch = pitch
	main.cam_yaw = yaw

func _hub_cam(pos: Vector3, look: Vector3) -> void:
	var hub: Node3D = main.hub
	hub.camera.position = pos
	hub.camera.look_at(hub.global_position + look, Vector3.UP)

# ---------------------------------------------------------------------
# Shots
# ---------------------------------------------------------------------
func _shot_title() -> void:
	main.to_home()
	main.menu.visible = false
	main.hub.set_heroes(["ninja", "miko", "mage", "ice", "samurai", "mecha", "idol"])
	title_lbl.text = "SAKURA\nSPIRIT DEFENSE"
	sub_lbl.text = "A 3D anime tower defense"
	_cut()
	var n := 135
	for i in range(n):
		var t := _ease(float(i) / (n - 1))
		_hub_cam(Vector3(0, 19.0, 34.0).lerp(Vector3(0, 12.5, 21.5), t), Vector3(0, 1.8, -1.0))
		var a := clampf((i - 18) / 14.0, 0.0, 1.0) * clampf((n - 8 - i) / 10.0, 0.0, 1.0)
		title_box.modulate.a = a
		title_box.scale = Vector2.ONE * (1.0 + (1.0 - _ease(clampf((i - 18) / 18.0, 0.0, 1.0))) * 0.12)
		title_box.pivot_offset = Vector2(640, 360)
		dim.color.a = 0.25 * a
		await _frame()
	title_box.modulate.a = 0.0
	dim.color.a = 0.0

func _shot_heroes() -> void:
	main.to_home()
	main.menu.visible = false
	main.hub.set_heroes(["ren", "kenta", "saya", "sora", "komugi", "hina", "lumi", "kaito", "rei"])
	_cut()
	_caption("21 heroes in 5 classes", 104)
	var n := 110
	for i in range(n):
		var t := float(i) / (n - 1)
		var x := lerpf(-7.5, 7.5, t)
		_hub_cam(Vector3(x, 3.6, 12.5), Vector3(x * 0.72, 1.9, 0.5))
		await _frame()

func _shot_play() -> void:
	main.new_game("normal", 0, "standard")
	_cinematic(true)
	_spread_heroes(["ninja", "miko", "mage", "ice", "samurai", "kenta", "idol"], 2)
	main.cash = 2450.0
	main.round_num = 16
	main.start_round()
	main.speed = 2
	main.ui.banner_box.visible = false
	_preroll(420)
	main.ui.update_hud()
	main._fit_camera()
	var d0: float = main.cam_dist
	_cut()
	_caption("Place heroes. Pop spirits.", 150)
	var n := 185
	for i in range(n):
		var t := _ease(float(i) / (n - 1))
		main.cam_dist = d0 * lerpf(1.0, 0.86, t)
		if i % 9 == 0:
			main.spawn_enemy(TYPES[rng.randi() % 6], 0.0)
		await _frame()

func _shot_upgrade() -> void:
	main.new_game("normal", 0, "sandbox")
	_cinematic(false)
	var c: Vector3 = main.pos_at(main.path_len * 0.3)
	var hs := _place(["mage"], c, 0)
	_place(["ninja", "ice"], c, 2, 3.4)
	var h = hs[0]
	var hp := Vector3(h.x, 0, h.z)
	_crowd(26, 0.12, 0.3)
	_preroll(40)
	_cut()
	_caption("Upgrade three paths", 150)
	var n := 170
	for i in range(n):
		var t := float(i) / (n - 1)
		_cam(hp + Vector3(0, 1.2, 0), 17.0, 0.47, lerpf(0.55, -0.45, _ease(t)))
		if i in [24, 56, 88, 120]:
			main.buy_upgrade(h, 0)
			main.select_hero(null)
		if i % 5 == 0:
			main.spawn_enemy(TYPES[rng.randi() % 7], main.path_len * 0.16)
		await _frame()

func _shot_abilities() -> void:
	main.new_game("normal", 0, "sandbox")
	_cinematic(false)
	var c: Vector3 = main.pos_at(main.path_len * 0.45)
	var hs := _place(["mage", "ninja", "ice", "mecha", "kaito", "sora"], c, 3, 3.0)
	for h in hs:
		for k in range(3 - int(h.tiers.max())):
			main.buy_upgrade(h, h.tiers.find(h.tiers.max()))
	_crowd(60, 0.2, 0.7)
	_preroll(30)
	_cut()
	_caption("Unleash abilities", 160)
	var n := 180
	for i in range(n):
		var t := float(i) / (n - 1)
		_cam(c, lerpf(40.0, 33.0, _ease(t)), 0.78, lerpf(-0.25, 0.25, t))
		var slot := [14, 44, 74, 104, 130, 152].find(i)
		if slot >= 0 and slot < hs.size():
			main.use_ability(hs[slot])
		if i % 2 == 0:
			main.spawn_enemy(TYPES[rng.randi() % TYPES.size()], main.path_len * rng.randf_range(0.2, 0.6))
		await _frame()

func _shot_bosses() -> void:
	main.new_game("normal", 4, "sandbox")
	_cinematic(false)
	var mid: Vector3 = main.pos_at(main.path_len * 0.34)
	_place(["samurai", "saya", "rei", "miko"], mid, 2, 3.2)
	var boss = main.spawn_enemy("shogun", main.path_len * 0.2, false, true)
	main.spawn_enemy("dragon", main.path_len * 0.1, false, true)
	main.spawn_enemy("oni", main.path_len * 0.27, false, true)
	main.spawn_enemy("oni", main.path_len * 0.31, false, true)
	_preroll(20)
	_cut()
	_caption("Face giant bosses", 150)
	var n := 170
	var target: Vector3 = boss.pos
	for i in range(n):
		var t := float(i) / (n - 1)
		if boss.alive:
			target = target.lerp(boss.pos, 0.2)
		_cam(target + Vector3(0, 1.0, 0), lerpf(24.0, 30.0, t), 0.74, lerpf(0.7, 0.1, _ease(t)))
		if i % 12 == 0:
			main.spawn_enemy("mask", main.path_len * 0.16)
		await _frame()

func _shot_maps() -> void:
	_caption("46 maps across 6 worlds", 232)
	for map_i in [2, 3, 1, 4, 11]:
		main.new_game("normal", map_i, "sandbox")
		_cinematic(false)
		_spread_heroes(["mage", "kenta", "ice", "samurai", "hina", "sora"], 2)
		for j in range(46):
			main.spawn_enemy(TYPES[rng.randi() % TYPES.size()], main.path_len * (0.02 + 0.9 * j / 46.0))
		_preroll(50)
		main._fit_camera()
		var d0: float = main.cam_dist
		var tgt: Vector3 = main.cam_target
		_cut()
		var n := 48
		for i in range(n):
			var t := float(i) / (n - 1)
			_cam(tgt, d0 * lerpf(0.9, 0.84, t), 0.9, lerpf(0.16, 0.04, t))
			if i % 4 == 0:
				main.spawn_enemy(TYPES[rng.randi() % 6], 0.0)
			await _frame()

func _shot_farm() -> void:
	main.new_game("normal", 6, "sandbox")
	_cinematic(false)
	var c: Vector3 = main.pos_at(main.path_len * 0.4)
	var farms := _place(["komugi", "komugi"], c, 0, 4.0)
	for f in farms:
		for k in range(3):
			main.buy_upgrade(f, 0)
	_place(["ninja", "lumi"], c, 2, 3.2)
	main.select_hero(null)
	var f0 = farms[0]
	_crowd(14, 0.25, 0.45)
	_cut()
	_caption("Grow a farm", 84)
	var n := 95
	for i in range(n):
		var t := float(i) / (n - 1)
		_cam(Vector3(f0.x, 0.8, f0.z), 17.0, 0.6, lerpf(-0.5, 0.2, _ease(t)))
		if i % 7 == 0:
			main._grow_crop(farms[(i / 7) % farms.size()], main.eff(farms[(i / 7) % farms.size()]))
		if i == 62 or i == 84:
			main.collect_all_crops()
		if i % 6 == 0:
			main.spawn_enemy(TYPES[rng.randi() % 5], main.path_len * 0.3)
		await _frame()

func _shot_powers() -> void:
	main.new_game("normal", 4, "standard")
	_cinematic(false)
	main.ui.banner_box.visible = true
	_spread_heroes(["miko", "ice", "kenta"], 1)
	main.round_num = 20
	_crowd(80, 0.05, 0.8)
	main._fit_camera()
	var d0: float = main.cam_dist
	var tgt: Vector3 = main.cam_target
	_cut()
	_caption("Call down powers", 78)
	var n := 88
	for i in range(n):
		var t := float(i) / (n - 1)
		_cam(tgt, d0 * lerpf(0.8, 0.72, t), 0.85, lerpf(-0.1, 0.1, t))
		if i == 12:
			main.use_power("time_stop")
		if i == 50:
			main.use_power("shrine_bomb")
		await _frame()
	main.ui.banner_box.visible = false

func _shot_menus() -> void:
	main.to_home()
	main.menu.visible = true
	_caption("Unlock. Collect. Master.", 146)
	var screens := ["tree", "store", "almanac", "blessings"]
	for s in screens:
		if s == "tree":
			main.menu.open_tree("mage")
		else:
			main.menu._open(s)
		_cut()
		for i in range(38):
			await _frame()
	main.menu.show_home()

func _shot_end() -> void:
	main.to_home()
	main.menu.visible = false
	main.hub.set_heroes(["ninja", "miko", "mage", "ice", "samurai", "komugi", "lumi"])
	title_lbl.text = "SAKURA\nSPIRIT DEFENSE"
	sub_lbl.text = "Play free now  ·  Web  ·  Windows  ·  Linux"
	_cut()
	var n := 150
	for i in range(n):
		var t := _ease(float(i) / (n - 1))
		_hub_cam(Vector3(0, 12.5, 21.5).lerp(Vector3(0, 15.0, 26.0), t), Vector3(0, 1.8, -1.0))
		var a := clampf((i - 6) / 12.0, 0.0, 1.0)
		title_box.modulate.a = a
		title_box.scale = Vector2.ONE
		dim.color.a = 0.4 * a
		if i > n - 22:
			fade_v = clampf((i - (n - 22)) / 18.0, 0.0, 1.0) + 0.2
		await _frame()
