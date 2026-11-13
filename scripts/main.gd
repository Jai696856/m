# Sakura Spirit Defense — main game controller.
# Everything (map, models, UI) is generated from code; main.tscn is just this node.
extends Node3D

const Defs = preload("res://scripts/defs.gd")
const Models = preload("res://scripts/models.gd")
const GameUI = preload("res://scripts/ui.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Music = preload("res://scripts/music.gd")
const LevelScene = preload("res://scenes/level/level.tscn")
const Maps = preload("res://scripts/maps.gd")
const Progress = preload("res://scripts/progress.gd")
const MainMenu = preload("res://scripts/main_menu.gd")
const Packs = preload("res://scripts/packs.gd")
const HubScene = preload("res://scenes/menu/hub.tscn")
const HUB_POS := Vector3(4000, 0, 0)
const SAVE_PATH := "user://save.cfg"

## Game modes. Medals are earned per map, difficulty and mode (never in sandbox).
const MODE_ORDER := ["standard", "half_cash", "fortified", "deflation", "rush", "one_class", "boss_rush", "sandbox"]
const MODES := {
	"standard": {"name": "Standard", "desc": "The classic game: survive 40 rounds."},
	"half_cash": {"name": "Half Cash", "desc": "All money earned is halved."},
	"fortified": {"name": "Fortified", "desc": "Every spirit is fortified with double health."},
	"deflation": {"name": "Deflation", "desc": "Start with $20,000. No more money is ever earned."},
	"rush": {"name": "Rush", "desc": "Rounds start back to back and spirits move 25% faster."},
	"one_class": {"name": "One Class", "desc": "The first hero you place picks your class. Only heroes of that class can join."},
	"boss_rush": {"name": "Boss Rush", "desc": "A boss joins every 5th round from round 10, and bosses have 25% more health."},
	"sandbox": {"name": "Sandbox", "desc": "Unlimited money and lives. Experiment freely (no medals)."},
}

## Hero abilities unlock when any upgrade path reaches tier 3.
var ABILITIES := {
	"ninja": {"name": "Shadow Storm", "cd": 40.0, "desc": "Hurls 40 shuriken in every direction."},
	"miko": {"name": "Divine Seal", "cd": 50.0, "desc": "Stuns every spirit on the map (bosses briefly)."},
	"mage": {"name": "Meteor Shower", "cd": 45.0, "desc": "Drops 8 meteors on the strongest spirits."},
	"ice": {"name": "Blizzard", "cd": 55.0, "desc": "Freezes every spirit, even bosses and Frost Wisps."},
	"samurai": {"name": "Thousand Cuts", "cd": 40.0, "desc": "Slashes the 6 strongest spirits for heavy damage."},
	"mecha": {"name": "Orbital Strike", "cd": 60.0, "desc": "A huge laser blasts the strongest spirit."},
	"idol": {"name": "Encore!", "cd": 60.0, "desc": "Every hero attacks twice as fast for 10 seconds."},
	"ren": {"name": "Hundred Fists", "cd": 40.0, "desc": "A flurry of blows on the 6 strongest spirits."},
	"kenta": {"name": "Spear Rain", "cd": 45.0, "desc": "30 spears rain down around Kenta."},
	"saya": {"name": "Big Bang", "cd": 50.0, "desc": "Six huge shells blast the strongest spirits."},
	"sora": {"name": "Thunderstorm", "cd": 50.0, "desc": "Lightning stuns and strikes the 10 strongest spirits."},
	"riku": {"name": "Drone Swarm", "cd": 45.0, "desc": "Launches 24 homing explosive drones."},
	"hina": {"name": "Bullet Storm", "cd": 40.0, "desc": "The turret sprays 60 homing bullets."},
	"hiro": {"name": "Market Day", "cd": 60.0, "desc": "Instantly earn $400 plus 5% of your money (max $3000)."},
	"nao": {"name": "Blessing", "cd": 70.0, "desc": "Restores 25 lives."},
	"kaito": {"name": "Broadside", "cd": 45.0, "desc": "Fires 16 cannon shockwaves in every direction."},
	"rei": {"name": "Spirit Cannon", "cd": 55.0, "desc": "A colossal ki wave blasts everything in a line."},
	"ichika": {"name": "Sealing Circle", "cd": 55.0, "desc": "Seals every spirit nearby in place and burns them."},
	"gen": {"name": "Gadget Overload", "cd": 45.0, "desc": "Twelve flashbang grenades hit the strongest spirits."},
	"komugi": {"name": "Bumper Crop", "cd": 50.0, "desc": "The paddy bursts: 8 coin bundles at once, worth double."},
	"lumi": {"name": "Starlight Transformation", "cd": 70.0, "desc": "Heroes attack twice as fast for 8 seconds and the shrine heals 10 lives."},
}
const ABILITY_TIER := 3

## Regrowing spirits heal back up this chain when left alone.
const REGROW_PARENT := {"pink": "blue", "blue": "green", "green": "gold", "gold": "violet"}
const REGROW_DELAY := 2.5

const PATH_W := 4.0  # stone track width including its low barriers
const SPEED_UNIT := 3.4
const HERO_SCALE := 1.25
const CORNER_RADIUS := 1.3  # spirits round the 90-degree corners slightly
const RING_COLORS := [0xffffff, 0x9be15d, 0x4fc3f7, 0xb388ff, 0xffd54f]
const PRIORITIES := ["first", "last", "strong", "close"]
const DIFFS := {"easy": {"lives": 200, "cost": 0.85}, "normal": {"lives": 150, "cost": 1.0}, "hard": {"lives": 100, "cost": 1.08}, "nightmare": {"lives": 1, "cost": 1.2}}
const DIFF_ORDER := ["easy", "normal", "hard", "nightmare"]

class Enemy:
	var type := ""
	var def: Dictionary
	var node: Node3D
	var d := 0.0
	var camo := false
	var alive := true
	var hp := 1.0
	var max_hp := 1.0
	var r := 0.5
	var stun := 0.0
	var frozen := false
	var slow_t := 0.0
	var slow_f := 1.0
	var pos := Vector3.ZERO
	var bob := 0.0
	var ice: MeshInstance3D = null
	var segs: Array = []
	var speed_mul := 1.0
	var dd := 0.0
	var rank := 0
	var boss := false
	var fortified := false
	var regrow := false
	var regrow_top := ""
	var regrow_t := 0.0

class Hero:
	var key := ""
	var def: Dictionary
	var x := 0.0
	var z := 0.0
	var model: Dictionary
	var stats: Dictionary
	var tiers := [0, 0, 0]
	var spent := 0
	var cool := 0.0
	var pops := 0
	var priority := "first"
	var counter := 0
	var anim := 0.0
	var spin := 0.0
	var buff := {"rate": 1.0, "dmg": 0.0, "pierce": 0, "camo": false}
	var aura: MeshInstance3D = null
	var halo: MeshInstance3D = null
	var ability_cd := -1.0  # < 0 while locked
	var crop_t := 0.0  # farm: seconds until the next coin bundle

class Proj:
	var node: Node3D
	var x := 0.0
	var z := 0.0
	var vx := 0.0
	var vz := 0.0
	var speed := 20.0
	var life := 1.0
	var pierce := 1
	var opt: Dictionary
	var hit := {}
	var r := 0.45
	var homing := false
	var explode = null
	var target: Enemy = null
	var dead := false

# ---- game state ----
var cash := 650.0
var lives := 150.0
var round_num := 0
var max_round := 40
var speed := 1
var running := false
var auto_start := false
var over := true
var cost_mul := 1.0
var freeplay := false
var placing := ""
var selected: Hero = null
var round_time := 0.0
var queue: Array = []
var auto_timer := -1.0
var time := 0.0
var shake := 0.0
var difficulty := "normal"
var mode := "standard"
var map_index := 0
var paused := false
var encore_t := 0.0
var golden_t := 0.0  # Golden Touch power: pops pay 5x
var powers_used_game := 0
var game_pops := 0
var cash_earned := 0.0
var save := ConfigFile.new()
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var progress
var menu
## Attract mode: a self-playing sandbox game behind the main menu.
var attract := false
var daily_active := false
var hub
var start_lives := 0.0
var squad := {}

var enemies: Array = []
var heroes: Array = []
var projectiles: Array = []
var effects: Array = []
var blockers: Array = []  # Vector3(x, z, radius)
var animated: Array = []  # Callables(t, dt)
var crops: Array = []  # farm coin bundles {node, value, t, auto, base}
const CROP_PICK := 1.6

var path_pts := PackedVector3Array()
var path_samples := PackedVector3Array()
var path_len := 0.0
var path_step := 0.25
var path_n := 0

var templates := {}
var rainbow_mat: StandardMaterial3D
var rainbow_camo: StandardMaterial3D
var ice_mat: StandardMaterial3D
var seg_mats: Array = []

var camera: Camera3D
var cam_target := Vector3(5, 0, 2)
var cam_yaw := 0.0
var cam_pitch := 0.9
var cam_dist := 56.0
var cam_max := 95.0
var ui
var sfx
var music
var level

var ghost: Dictionary = {}
var range_root: Node3D
var range_ring_mat: StandardMaterial3D
var range_disk_mat: StandardMaterial3D

## Active touch points (index -> position) for pinch-zoom and two-finger pan on iPad/iPhone.
var touches := {}
var multi_touch := false
var pinch_dist := 0.0
var pinch_mid := Vector2.ZERO
var press_pos := Vector2.ZERO
var press_button := 0
var pressing := false
var dragging := false

var pmm: MultiMeshInstance3D
var p_pos: Array = []
var p_vel: Array = []
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_idx := 0
const PCOUNT := 600

# =====================================================================
# Setup
# =====================================================================
func _ready() -> void:
	randomize()
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)
	rainbow_mat = Models.make_toon(Color.RED)
	rainbow_camo = Models.make_toon(Color(1, 0, 0, 0.4))
	ice_mat = Models.make_toon(Defs.col(0xbff4ff, 0.55), false)
	seg_mats = [Models.toon(0x26a69a), Models.toon(0x4dd0b8)]
	_setup_env()
	save.load(SAVE_PATH)
	progress = Progress.new(save)
	Packs.load_all(self)
	load_map(int(save.get_value("settings", "last_map", 0)))
	_setup_particles()
	_setup_range()
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	progress.on_unlock = func(a: Array) -> void: ui.toast("ACHIEVEMENT UNLOCKED", a[1])
	progress.on_level = _on_level_up
	_apply_settings()
	hub = HubScene.instantiate()
	hub.position = HUB_POS
	add_child(hub)
	menu = MainMenu.new()
	menu.ui = ui
	menu.game = self
	ui.root.add_child(menu)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	to_home()

func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky_mat = sm
	sm.sky_top_color = Defs.col(0x3d9df2)
	sm.sky_horizon_color = Defs.col(0xbfe8ff)
	sm.ground_horizon_color = Defs.col(0xbfe8ff)
	sm.ground_bottom_color = Defs.col(0x1f9ad6)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.9, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# A little bloom on bright effects, and slightly richer colour
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.985
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.02
	env.adjustment_saturation = 1.0
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Defs.col(0xfff1dc)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 2.0
	sun.shadow_opacity = 0.85
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 170.0
	sun.rotation_degrees = Vector3(-58, -32, 0)
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 1.0
	camera.far = 700.0
	add_child(camera)
	camera.make_current()

## Builds the level for map `i` (see scripts/maps.gd), replacing the current one.
func load_map(i: int) -> void:
	map_index = clampi(i, 0, Maps.MAPS.size() - 1)
	if level:
		remove_child(level)
		level.queue_free()
	level = LevelScene.instantiate()
	level.name = "Level"
	level.map = Maps.MAPS[map_index]
	add_child(level)
	blockers = level.blockers
	path_pts = PackedVector3Array()
	path_samples = PackedVector3Array()
	_build_path()
	_apply_theme(level.theme)

## Daylight for a theme. Toon-lit surfaces receive the sun at about pi times its energy,
## so the energies here are small: sun * pi + ambient comes to roughly 1.0, which keeps
## every colour on screen close to its palette value instead of blowing out.
const AMBIENT_TINT := Color(0.74, 0.82, 1.0)
const SUN_SCALE := 0.145
const AMBIENT_SCALE := 1.55

func _apply_theme(t: Dictionary) -> void:
	sun.light_color = Defs.col(t["sun"])
	sun.light_energy = float(t["sun_energy"]) * SUN_SCALE
	env.ambient_light_color = Defs.col(t["ambient"]).lerp(AMBIENT_TINT, 0.4)
	env.ambient_light_energy = float(t["ambient_energy"]) * AMBIENT_SCALE
	sky_mat.sky_top_color = Defs.col(t["sky_top"])
	sky_mat.sky_horizon_color = Defs.col(t["sky_horizon"])
	sky_mat.ground_horizon_color = Defs.col(t["sky_horizon"])
	sky_mat.ground_bottom_color = Defs.col(t["sea"])

func current_map() -> Dictionary:
	return Maps.MAPS[map_index]

# Spirits walk the track's centre line: straight runs joined by small rounded
# corners, resampled every 0.25 units so pos_at() is a cheap lookup.
func _build_path() -> void:
	var wps: Array = level.track.get_path_points()
	var dense: Array = [Vector2(wps[0].x, wps[0].z)]
	for i in range(1, wps.size() - 1):
		var a: Vector2 = Vector2(wps[i - 1].x, wps[i - 1].z)
		var b: Vector2 = Vector2(wps[i].x, wps[i].z)
		var c: Vector2 = Vector2(wps[i + 1].x, wps[i + 1].z)
		var p_in: Vector2 = b + (a - b).normalized() * CORNER_RADIUS
		var p_out: Vector2 = b + (c - b).normalized() * CORNER_RADIUS
		for k in range(9):
			var t := k / 8.0
			dense.append(p_in.lerp(b, t).lerp(b.lerp(p_out, t), t))
	var last: Vector3 = wps[wps.size() - 1]
	dense.append(Vector2(last.x, last.z))
	var cum := PackedFloat32Array([0.0])
	for i in range(1, dense.size()):
		cum.append(cum[i - 1] + (dense[i] as Vector2).distance_to(dense[i - 1]))
	path_len = cum[cum.size() - 1]
	path_n = int(ceil(path_len / 0.25))
	path_step = path_len / path_n
	var j := 0
	for s in range(path_n + 1):
		var target := s * path_step
		while j < dense.size() - 2 and cum[j + 1] < target:
			j += 1
		var seg := maxf(cum[j + 1] - cum[j], 0.0001)
		var t := clampf((target - cum[j]) / seg, 0.0, 1.0)
		var v: Vector2 = (dense[j] as Vector2).lerp(dense[j + 1], t)
		path_pts.append(Vector3(v.x, 0, v.y))
	for i in range(0, path_pts.size(), 2):
		path_samples.append(path_pts[i])

func pos_at(d: float) -> Vector3:
	var f := clampf(d / path_step, 0.0, path_n - 0.0001)
	var i := int(f)
	return path_pts[i].lerp(path_pts[i + 1], f - i)

func dir_at(d: float) -> float:
	var i := clampi(int(d / path_step), 0, path_n - 1)
	var a := path_pts[i]
	var b := path_pts[i + 1]
	return atan2(b.x - a.x, b.z - a.z)

func dist_to_path(x: float, z: float) -> float:
	var best := INF
	for p in path_samples:
		var dd: float = (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
		if dd < best:
			best = dd
	return sqrt(best)

func _setup_particles() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = PCOUNT
	var sm := Models.sphere(0.13, 8)
	mm.mesh = sm
	pmm = MultiMeshInstance3D.new()
	pmm.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	pmm.material_override = mat
	pmm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pmm.custom_aabb = AABB(Vector3(-100, -20, -100), Vector3(200, 80, 200))
	add_child(pmm)
	p_life.resize(PCOUNT)
	p_max.resize(PCOUNT)
	for i in range(PCOUNT):
		p_pos.append(Vector3.ZERO)
		p_vel.append(Vector3.ZERO)
		p_life[i] = 0.0
		p_max[i] = 1.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0)))
		mm.set_instance_color(i, Color.WHITE)

func _setup_range() -> void:
	range_root = Node3D.new()
	range_ring_mat = Models.fx_mat(Color(1, 1, 1, 0.9))
	range_disk_mat = Models.fx_mat(Defs.col(0x9ad7ff, 0.18))
	Models.add(range_root, Models.torus(1.0, 0.025), range_ring_mat)
	Models.add(range_root, Models.cyl(1.0, 1.0, 0.01, 64), range_disk_mat)
	range_root.visible = false
	add_child(range_root)

# =====================================================================
# Camera
# =====================================================================
func _fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	var a := vs.x / maxf(vs.y, 1.0)
	var portrait := a < 0.9
	var tanv := tan(deg_to_rad(camera.fov / 2.0))
	var half_w := 27.0 if portrait else 41.0
	cam_dist = clampf(half_w / (tanv * a), 52.0, 125.0)
	cam_max = maxf(95.0, cam_dist + 20.0)
	cam_target = Vector3(-3, 0, 0) if portrait else Vector3(5, 0, 0.5)
	cam_yaw = PI / 2 if portrait else 0.0
	cam_pitch = 1.15 if portrait else 1.08
	_update_camera()

func _update_camera() -> void:
	cam_target.x = clampf(cam_target.x, -30, 30)
	cam_target.z = clampf(cam_target.z, -18, 18)
	cam_pitch = clampf(cam_pitch, 0.35, 1.37)
	cam_dist = clampf(cam_dist, 16.0, cam_max)
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	camera.position = cam_target + off
	camera.look_at(cam_target, Vector3.UP)
	if shake > 0.0:
		camera.position += Vector3(randf() - 0.5, randf() - 0.5, 0) * shake

# =====================================================================
# Input
# =====================================================================
func _pan_camera(screen_delta: Vector2) -> void:
	var right := camera.global_transform.basis.x
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	cam_target += (-right * screen_delta.x + fwd * screen_delta.y) * cam_dist * 0.0015

# Two fingers: pinch to zoom, move together to pan. One finger still rotates and taps
# through the emulated mouse events below.
func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
		else:
			touches.erase(st.index)
		if touches.size() >= 2:
			multi_touch = true
			dragging = true   # a pinch is never a tap
			pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touches.size() >= 2:
			var pts: Array = touches.values()
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[1]
			var dist := a.distance_to(b)
			var mid := (a + b) * 0.5
			if pinch_dist > 0.0 and dist > 1.0:
				cam_dist *= pinch_dist / dist
				_pan_camera(mid - pinch_mid)
			pinch_dist = dist
			pinch_mid = mid

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist *= 0.9
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist *= 1.1
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				if touches.size() <= 1:
					multi_touch = false
				pressing = true
				dragging = multi_touch
				press_pos = mb.position
				press_button = mb.button_index
			elif pressing:
				pressing = false
				if not dragging:
					_on_click(mb.position, press_button, mb.shift_pressed)
				dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if pressing and mm.button_mask == 0:
			pressing = false
			dragging = false
		if pressing and not dragging and mm.position.distance_to(press_pos) > 8.0:
			dragging = true
		if pressing and dragging and not multi_touch:
			if press_button == MOUSE_BUTTON_LEFT:
				cam_yaw -= mm.relative.x * 0.006
				cam_pitch += mm.relative.y * 0.005
			else:
				_pan_camera(mm.relative)
		_update_ghost(mm.position)
	elif event is InputEventMagnifyGesture:
		cam_dist /= (event as InputEventMagnifyGesture).factor
	elif event is InputEventPanGesture:
		cam_dist *= 1.0 + (event as InputEventPanGesture).delta.y * 0.05
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		_on_key(event as InputEventKey)

func _on_key(k: InputEventKey) -> void:
	if over or attract:
		return
	var code := k.keycode
	if code >= KEY_1 and code < KEY_1 + Defs.CLASSES.size():
		ui.select_class(code - KEY_1)
	elif code in [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B]:
		var cls: Array = Defs.CLASSES[ui.shop_class]["heroes"]
		var idx := [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B].find(code)
		if idx < cls.size():
			begin_placing(cls[idx])
	elif code == KEY_ESCAPE:
		if placing != "" or selected != null:
			cancel_placing()
			select_hero(null)
		else:
			toggle_pause()
	elif code == KEY_P:
		toggle_pause()
	elif code in ABILITY_KEYS:
		var slot := ABILITY_KEYS.find(code)
		var list := ability_heroes()
		if slot < list.size():
			use_ability(list[slot])
	elif code == KEY_SPACE:
		on_play()
	elif code in POWER_KEYS:
		var pw: Array = Progress.POWERS[POWER_KEYS.find(code)]
		use_power(pw[0])
	elif selected and code in [KEY_COMMA, KEY_PERIOD, KEY_SLASH]:
		buy_upgrade(selected, [KEY_COMMA, KEY_PERIOD, KEY_SLASH].find(code))
	elif selected and (code == KEY_BACKSPACE or code == KEY_DELETE):
		sell_hero(selected)
	elif selected and code == KEY_TAB:
		cycle_priority(selected)

func _ground_point(screen: Vector2):
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	return Plane(Vector3.UP, 0.0).intersects_ray(from, dir)

func _on_click(screen: Vector2, button: int, shift: bool) -> void:
	if attract:
		return
	if button == MOUSE_BUTTON_RIGHT:
		cancel_placing()
		select_hero(null)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	var hit = _ground_point(screen)
	if hit == null:
		return
	var p: Vector3 = hit
	if placing != "":
		_update_ghost(screen)
		if placing_charm != "" and valid_spot(p.x, p.z):
			var ch := place_charm(p.x, p.z)
			cancel_placing()
			if ch:
				select_hero(ch)
			return
		if valid_spot(p.x, p.z):
			var k := placing
			var h := place_hero(k, p.x, p.z)
			if h and shift and cash >= hero_price(k):
				ui.refresh()
				return
			cancel_placing()
			if h:
				select_hero(h)
		else:
			sfx.play("error")
		return
	var crop = _crop_at(p)
	if crop != null:
		_collect_crop(crop, true)
		return
	var best: Hero = null
	var bd := 1.8
	for h in heroes:
		var dd: float = Vector2(h.x, h.z).distance_to(Vector2(p.x, p.z))
		if dd < bd:
			bd = dd
			best = h
	select_hero(best)

# =====================================================================
# Placement / selection
# =====================================================================
## Shrine Blessings apply in every mode except Sandbox.
func blessed(id: String) -> bool:
	return mode != "sandbox" and progress != null and progress.has_blessing(id)

func hero_price(k: String) -> int:
	return price(float(Defs.HEROES[k]["cost"]) * (0.95 if blessed("recruit") else 1.0))

func upgrade_price(h: Hero, p: int) -> int:
	var up: Array = h.def["paths"][p][h.tiers[p]]
	return price(float(up[1]) * (0.85 if h.tiers[p] == 0 and blessed("apprentice") else 1.0))

func power_limit() -> int:
	return POWER_LIMIT + (1 if blessed("charm") else 0)

func price(c) -> int:
	return int(round(float(c) * cost_mul / 5.0) * 5.0)

func valid_spot(x: float, z: float) -> bool:
	if not level.is_buildable(x, z):
		return false
	if dist_to_path(x, z) < PATH_W / 2.0 + 1.15:
		return false
	for h in heroes:
		if Vector2(h.x, h.z).distance_to(Vector2(x, z)) < 2.4:
			return false
	return true

func show_range(x: float, z: float, r: float, ok: bool) -> void:
	range_root.visible = true
	range_root.position = Vector3(x, 0.08, z)
	var rr := minf(r, 60.0)
	range_root.scale = Vector3(rr, 1, rr)
	range_ring_mat.albedo_color = Color(1, 1, 1, 0.9) if ok else Defs.col(0xff4d6d, 0.9)
	range_disk_mat.albedo_color = Defs.col(0x9ad7ff, 0.18) if ok else Defs.col(0xff4d6d, 0.2)

func begin_placing(k: String) -> void:
	if over:
		return
	if placing == k:
		cancel_placing()
		return
	cancel_placing()
	if not hero_available(k):
		sfx.play("error")
		ui.toast("LOCKED", "%s joins at player level %d" % [Defs.HEROES[k]["name"], int(Defs.UNLOCK_LEVEL[k])])
		return
	if cash < hero_price(k):
		sfx.play("error")
		return
	select_hero(null)
	placing = k
	ghost = Models.build_hero(k)
	var root: Node3D = ghost["root"]
	root.scale = Vector3.ONE * HERO_SCALE
	root.visible = false
	add_child(root)
	_update_ghost(get_viewport().get_mouse_position())
	ui.refresh()

## Hero Charms: place a pre-upgraded hero for free.
var placing_charm := ""

func begin_charm(key: String) -> void:
	if over or progress.charms().get(key, 0) <= 0:
		return
	var c: Dictionary = Progress.parse_charm(key)
	cancel_placing()
	select_hero(null)
	placing = c["hero"]
	placing_charm = key
	ghost = Models.build_hero(placing)
	var root: Node3D = ghost["root"]
	root.scale = Vector3.ONE * HERO_SCALE
	root.visible = false
	add_child(root)
	_update_ghost(get_viewport().get_mouse_position())
	ui.toast("HERO CHARM", "Tap the grass to place %s %s" % [Defs.HEROES[placing]["name"], charm_label(key)])
	ui.refresh()

static func charm_label(key: String) -> String:
	var t: Array = Progress.parse_charm(key)["tiers"]
	return "%d-%d-%d" % [t[0], t[1], t[2]]

func place_charm(x: float, z: float) -> Hero:
	var key := placing_charm
	if key == "" or not progress.take_charm(key):
		return null
	var c: Dictionary = Progress.parse_charm(key)
	var h := place_hero(c["hero"], x, z, true)
	if h == null:
		progress.add_charm(key)
		return null
	var tiers: Array = c["tiers"]
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return int(tiers[a]) > int(tiers[b]))
	for p in order:
		for i in range(int(tiers[p])):
			_force_upgrade(h, p)
	ui.refresh_abilities()
	ui.refresh_powers()
	burst(Vector3(x, 1.5, z), Color(1.0, 0.85, 0.3), 30, 6.0)
	save.save(SAVE_PATH)
	return h

func cancel_placing() -> void:
	placing_charm = ""
	if not ghost.is_empty():
		(ghost["root"] as Node3D).queue_free()
	ghost = {}
	placing = ""
	range_root.visible = selected != null
	if ui:
		ui.refresh()

func _update_ghost(screen: Vector2) -> void:
	if ghost.is_empty():
		return
	var hit = _ground_point(screen)
	if hit == null:
		return
	var p: Vector3 = hit
	var ok := valid_spot(p.x, p.z)
	var root: Node3D = ghost["root"]
	root.visible = true
	root.position = Vector3(p.x, 0, p.z)
	(ghost["ring_mat"] as StandardMaterial3D).albedo_color = Defs.col(0x7dff9a) if ok else Defs.col(0xff4d6d)
	show_range(p.x, p.z, Defs.HEROES[placing]["base"]["range"], ok)

func select_hero(h: Hero) -> void:
	selected = h
	if h:
		show_range(h.x, h.z, h.stats["range"], true)
	elif placing == "":
		range_root.visible = false
	ui.build_panel(h)

# =====================================================================
# Heroes
# =====================================================================
## Heroes unlock with player level (sandbox ignores this).
func hero_available(k: String) -> bool:
	if class_blocked(k):
		return false
	return not _upgrades_need_xp() or progress.level() >= int(Defs.UNLOCK_LEVEL.get(k, 1))

## One Class mode: once a hero is placed, other classes are closed.
var locked_class := ""

func class_blocked(k: String) -> bool:
	return mode == "one_class" and locked_class != "" and String(Defs.hero_class(k)["id"]) != locked_class

func place_hero(k: String, x: float, z: float, free: bool = false) -> Hero:
	if class_blocked(k) or (not hero_available(k) and not free):
		return null
	var def: Dictionary = Defs.HEROES[k]
	var cost := 0 if free else hero_price(k)
	if cash < cost:
		return null
	add_cash(-cost)
	var h := Hero.new()
	h.key = k
	h.def = def
	h.x = x
	h.z = z
	h.model = Models.build_hero(k)
	var skin_i: int = progress.skin(k)
	if skin_i > 0:
		Models.apply_skin(h.model, int(Progress.SKINS[skin_i][1]))
	h.stats = (def["base"] as Dictionary).duplicate(true)
	if progress.mastered(k):
		# Mastery: a permanent edge for this hero in every game
		h.stats["rate"] = float(h.stats["rate"]) * 0.85
		if int(h.stats.get("pierce", 0)) > 0:
			h.stats["pierce"] = int(h.stats["pierce"]) + 1
		if float(h.stats.get("dmg", 0.0)) > 0.0:
			h.stats["dmg"] = float(h.stats["dmg"]) + 1.0
	if blessed("range"):
		h.stats["range"] = float(h.stats["range"]) * 1.05
	if blessed("rate"):
		h.stats["rate"] = float(h.stats["rate"]) * 0.96
	if blessed("pierce") and h.stats["kind"] != "support" and int(h.stats.get("pierce", 0)) > 0:
		h.stats["pierce"] = int(h.stats["pierce"]) + 1
	h.spent = cost
	h.tiers = [0, 0, 0]
	var root: Node3D = h.model["root"]
	root.position = Vector3(x, 0, z)
	root.scale = Vector3.ONE * HERO_SCALE
	(h.model["body"] as Node3D).rotation.y = atan2(-x, 20.0 - z)
	add_child(root)
	if progress.mastered(k):
		Models.add(root, Models.torus(1.1, 0.05), Models.flat(0xffcc33), Vector3(0, 0.06, 0))
		Models.add(root, Models.sphere(0.12, 4), Models.flat(0xffcc33), Vector3(0, 3.1, 0))
	heroes.append(h)
	if mode == "one_class" and locked_class == "":
		locked_class = String(Defs.hero_class(k)["id"])
		ui.banner(String(Defs.hero_class(k)["name"]), "Only this class can join now")
		ui.rebuild_shop()
	if _tracking():
		progress.add("heroes_placed")
		squad[k] = true
		progress.set_max("squad", squad.size())
	recalc_buffs()
	burst(Vector3(x, 0.4, z), Color.WHITE, 14, 4.0)
	shockwave(Vector3(x, 0, z), 2.4, 0xffffff, 0.32, 0.45)
	sfx.play("place")
	return h

func sell_hero(h: Hero) -> void:
	var refund := int(h.spent * 0.7)
	add_cash(refund)
	float_text("+$%d" % refund, Vector3(h.x, 2, h.z), false)
	(h.model["root"] as Node3D).queue_free()
	heroes.erase(h)
	recalc_buffs()
	burst(Vector3(h.x, 1, h.z), Defs.col(0xffd34d), 16, 5.0)
	sfx.play("sell")
	if _tracking():
		progress.add("sold")
	select_hero(null)
	ui.refresh_abilities()

func can_upgrade(h: Hero, p: int) -> String:
	var nxt: int = h.tiers[p] + 1
	if nxt > 4:
		return "MAXED"
	var used := 0
	for v in h.tiers:
		if v > 0:
			used += 1
	if h.tiers[p] == 0 and used >= 2:
		return "Path closed"
	if nxt >= 3:
		for i in range(3):
			if i != p and h.tiers[i] >= 3:
				return "Path closed"
	if _upgrades_need_xp() and not progress.upgrade_unlocked(h.key, p, nxt):
		return "LOCKED"
	return ""

## Upgrades must be unlocked with hero XP, except in sandbox and the menu demo.
func _upgrades_need_xp() -> bool:
	return not attract and mode != "sandbox"

## Spend hero XP to unlock the next tier of a path (from the upgrade panel or the Heroes menu).
func unlock_mastery(k: String) -> bool:
	if not progress.unlock_mastery(k):
		sfx.play("error")
		return false
	save.save(SAVE_PATH)
	sfx.play("win")
	ui.toast("MASTERY UNLOCKED", "%s has mastered every path" % Defs.HEROES[k]["name"])
	return true

func unlock_upgrade(k: String, p: int, t: int) -> bool:
	if not progress.unlock_upgrade(k, p, t):
		sfx.play("error")
		return false
	save.save(SAVE_PATH)
	sfx.play("upgrade")
	ui.toast("UPGRADE UNLOCKED", String(Defs.HEROES[k]["paths"][p][t - 1][0]))
	if selected:
		ui.build_panel(selected)
	return true

func buy_upgrade(h: Hero, p: int) -> void:
	if can_upgrade(h, p) != "":
		return
	var up: Array = h.def["paths"][p][h.tiers[p]]
	var cost := upgrade_price(h, p)
	if cash < cost:
		sfx.play("error")
		return
	add_cash(-cost)
	Defs.apply_upgrade(h.stats, up[3])
	h.tiers[p] += 1
	h.spent += cost
	Models.apply_upgrade_look(h.model, p, h.tiers[p])
	if _tracking():
		progress.add("upgrades", 1.0, false)
		if h.tiers[p] == 4:
			progress.add("tier4")
	_refresh_hero_look(h)
	recalc_buffs()
	if h.ability_cd < 0.0 and h.tiers.max() >= ABILITY_TIER:
		h.ability_cd = 0.0
		float_text(String(ABILITIES[h.key]["name"]).to_upper() + "!", Vector3(h.x, 4.0, h.z), false)
		ui.refresh_abilities()
	burst(Vector3(h.x, 2, h.z), Defs.col(RING_COLORS[h.tiers[p]]), 24, 6.0)
	shockwave(Vector3(h.x, 0, h.z), 2.6, RING_COLORS[h.tiers[p]], 0.4, 0.5)
	pillar(Vector3(h.x, 0, h.z), RING_COLORS[h.tiers[p]], 0.8, 0.45, 5.0)
	sfx.play("upgrade")
	if selected == h:
		show_range(h.x, h.z, h.stats["range"], true)
		ui.build_panel(h)

# ---------------------------------------------------------------------
# Abilities
# ---------------------------------------------------------------------
const ABILITY_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I]

## Heroes whose ability is unlocked, in placement order (max 8 slots).
func ability_heroes() -> Array:
	var out: Array = []
	for h in heroes:
		if h.ability_cd >= 0.0 and out.size() < ABILITY_KEYS.size():
			out.append(h)
	return out

func _strongest(n: int) -> Array:
	var list: Array = []
	for e in enemies:
		if e.alive:
			list.append(e)
	list.sort_custom(func(a, b): return a.rank > b.rank or (a.rank == b.rank and a.d > b.d))
	return list.slice(0, n)

func use_ability(h: Hero) -> void:
	if over or paused or h.ability_cd != 0.0:
		return
	h.ability_cd = float(ABILITIES[h.key]["cd"]) * (0.9 if blessed("focus") else 1.0)
	var s := eff(h)
	var hpos := Vector2(h.x, h.z)
	h.anim = 0.4
	var hp3 := Vector3(h.x, 0, h.z)
	if pack_abilities.has(h.key):
		pack_abilities[h.key].use_ability(self, h, s)
	match h.key:
		"ninja":
			var o := opt_from(s, h, {"dmg": float(s["dmg"]) + 2.0, "type": "magic"})
			h.spin = 0.6
			shockwave(hp3, 5.0, 0x8a7dff, 0.4)
			for wave in range(2):
				after(wave * 0.18, func() -> void:
					for i in range(20):
						fire(hpos, (i + wave * 0.5) / 20.0 * TAU, "shuriken", o, 30.0, 6, {"life": 1.3}))
		"miko":
			rune_fx(hp3, 5.0, 0xffd34d, 1.4)
			shockwave(hp3, 70.0, 0xffe9a8, 0.9, 0.25)
			for e in enemies:
				if e.alive:
					e.stun = maxf(e.stun, 0.8 if e.boss else 2.5)
					e.frozen = false
					pillar(e.pos, 0xffd34d, 0.38 if not e.boss else 1.4, 0.55, 14.0)
		"mage":
			# Meteors really fall: each one lands where its target will be and explodes there
			var o2 := opt_from(s, h, {"dmg": 25.0, "type": "magic", "boss_mul": 3.0})
			rune_fx(hp3, 3.2, 0xff7b22, 1.6)
			var marks := _strongest(8)
			for i in range(8):
				var delay := 0.12 * i
				var fall := 0.62
				var to: Vector3
				if i < marks.size():
					to = predict(marks[i], delay + fall)
				else:
					to = pos_at(randf() * path_len)
				to.y = 0.6
				var from := to + Vector3(randf_range(7.0, 11.0), 30.0, randf_range(-9.0, -5.0))
				after(delay, func() -> void:
					drop(Models.meteor(randf_range(0.9, 1.25)), from, to, fall, func() -> void:
						explode(to.x, to.z, {"r": 4.0, "pierce": 40}, o2, false)
						pillar(to, 0xff8a2a, 1.1, 0.35, 9.0)
						burst(to, Defs.col(0xff7b22), 16, 9.0)
						shake = maxf(shake, 0.35 * shake_mul())))
		"ice":
			rune_fx(hp3, 4.0, 0x9ff3ff, 1.5)
			shockwave(hp3, 70.0, 0xbff4ff, 1.0, 0.3)
			for e in enemies:
				if e.alive:
					e.stun = maxf(e.stun, 2.0 if e.boss else 3.0)
					e.frozen = true
					apply_slow(e, 0.5, 6.0)
					burst(e.pos + Vector3(0, 1, 0), Color(0.85, 0.97, 1.0), 4, 3.0)
			# Ice shards rain across the track
			for i in range(26):
				var to2 := pos_at(randf() * path_len)
				after(randf() * 0.7, func() -> void:
					var shard := Models.mi(Models.cone(0.22, 1.6, 6), Models.fx_mat(Color(0.75, 0.95, 1.0, 0.85), true), Vector3.ZERO, Vector3(PI, 0, 0))
					var holder_n := Node3D.new()
					holder_n.add_child(shard)
					drop(holder_n, to2 + Vector3(2.0, 18.0, -1.0), to2, 0.4, func() -> void:
						burst(to2 + Vector3(0, 0.5, 0), Color(0.8, 0.96, 1.0), 5, 4.0)))
		"samurai":
			var o3 := opt_from(s, h, {"dmg": 150.0, "type": "magic"})
			var cuts := _strongest(6)
			for i in range(cuts.size()):
				var e: Enemy = cuts[i]
				after(i * 0.07, func() -> void:
					if e.alive:
						slash_fx(e.pos, 3.4)
						burst(e.pos + Vector3(0, 1, 0), Color(0.95, 0.98, 1.0), 8, 6.0)
						hit_enemy(e, o3))
			after(cuts.size() * 0.07 + 0.05, func() -> void: shockwave(hp3, 6.0, 0xe8f4ff, 0.35))
		"mecha":
			var top := _strongest(1)
			if not top.is_empty():
				var t: Enemy = top[0]
				var om := opt_from(s, h, {"dmg": 2000.0, "type": "magic", "boss_mul": 1.0})
				var om2 := opt_from(s, h, {"dmg": 10.0, "type": "magic"})
				# A targeting circle closes in, then the beam comes down
				var aim_at := predict(t, 0.55)
				rune_fx(aim_at, 3.0, 0x66f6ff, 0.6)
				after(0.55, func() -> void:
					var at: Vector3 = t.pos if t.alive else aim_at
					pillar(at, 0x66f6ff, 3.2, 0.7, 60.0)
					shockwave(at, 7.0, 0x66f6ff, 0.5, 0.6)
					burst(at + Vector3(0, 1, 0), Color(0.6, 0.97, 1.0), 30, 11.0)
					if t.alive:
						hit_enemy(t, om)
					explode(at.x, at.z, {"r": 3.5, "pierce": 30}, om2, false)
					shake = 0.7 * shake_mul())
		"ren":
			var o4 := opt_from(s, h, {"dmg": 120.0, "type": "magic"})
			var marks2 := _strongest(6)
			for i in range(marks2.size()):
				var e2: Enemy = marks2[i]
				# Three quick blows on each target; the last one carries the damage
				for k in range(3):
					after(i * 0.06 + k * 0.08, func() -> void:
						if e2.alive:
							shockwave(e2.pos, 1.6 + k * 0.5, 0xffb02e, 0.2, 0.7)
							burst(e2.pos + Vector3(0, 1, 0), Defs.col(0xffb02e), 5, 5.0)
							if k == 2:
								hit_enemy(e2, o4))
		"kenta":
			# Spears fall from the sky around Kenta and pierce what they land on
			var o5 := opt_from(s, h, {"dmg": (float(s["dmg"]) + 4.0) * 3.0, "type": "magic"})
			var rng_r: float = float(s["range"]) + 2.0
			var near_k := enemies_near(h.x, h.z, rng_r, true)
			for i in range(30):
				var to3: Vector3
				if i < near_k.size():
					to3 = predict(near_k[i], 0.1 + i * 0.03 + 0.4)
				else:
					var a := randf() * TAU
					var rr := sqrt(randf()) * rng_r
					to3 = Vector3(h.x + cos(a) * rr, 0, h.z + sin(a) * rr)
				to3.y = 0.3
				after(0.1 + i * 0.03, func() -> void:
					drop(Models.spear(), to3 + Vector3(1.5, 22.0, -1.0), to3, 0.4, func() -> void:
						for e in enemies_near(to3.x, to3.z, 1.7, true):
							hit_enemy(e, o5)
						shockwave(to3, 1.5, 0xcfe9ff, 0.22, 0.5)))
		"saya":
			var o6 := opt_from(s, h, {"dmg": 40.0, "type": "magic", "boss_mul": 3.0})
			var marks3 := _strongest(6)
			for i in range(6):
				var to4: Vector3
				if i < marks3.size():
					to4 = predict(marks3[i], 0.2 * i + 0.7)
				else:
					to4 = pos_at(randf() * path_len)
				to4.y = 0.5
				after(0.2 * i, func() -> void:
					sfx.play("throw")
					drop(Models.shell(), to4 + Vector3(-6.0, 26.0, 4.0), to4, 0.7, func() -> void:
						explode(to4.x, to4.z, {"r": 4.5, "pierce": 50}, o6, false)
						pillar(to4, 0xffa040, 1.6, 0.3, 7.0)
						shake = maxf(shake, 0.4 * shake_mul())))
		"sora":
			var o7 := opt_from(s, h, {"dmg": 30.0, "type": "magic"})
			shockwave(hp3, 70.0, 0xfff36b, 0.6, 0.18)
			for e in enemies:
				if e.alive:
					e.stun = maxf(e.stun, 0.5 if e.boss else 1.2)
			var marks4 := _strongest(10)
			for i in range(marks4.size()):
				var e3: Enemy = marks4[i]
				after(i * 0.06, func() -> void:
					if e3.alive:
						lightning_strike(e3.pos)
						sfx.play("beam")
						hit_enemy(e3, o7))
		"riku":
			var o8 := opt_from(s, h, {"dmg": float(s["dmg"]) + 3.0, "type": "blast"})
			var targets := _strongest(24)
			shockwave(hp3, 3.5, 0x66f6ff, 0.3)
			for i in range(24):
				var tg = targets[i % targets.size()] if not targets.is_empty() else null
				after(i * 0.03, func() -> void:
					fire(hpos, i / 24.0 * TAU, "missile", o8, 18.0, 1, {"homing": true, "target": tg, "explode": {"r": 1.8, "pierce": 12}, "life": 3.0}))
		"hina":
			var o9 := opt_from(s, h, {"dmg": float(s["dmg"]) + 2.0, "type": "magic"})
			var tg2 := _strongest(10)
			for i in range(60):
				var t2 = tg2[i % tg2.size()] if not tg2.is_empty() else null
				after(i * 0.012, func() -> void:
					fire(hpos, randf() * TAU, "frag", o9, 30.0, 2, {"homing": true, "target": t2, "life": 2.0}))
		"hiro":
			var gain := minf(3000.0, 400.0 + cash * 0.05)
			earn(gain)
			float_text("+$%d" % int(gain), Vector3(h.x, 3.0, h.z), false)
			pillar(hp3, 0xffd34d, 1.2, 0.6, 10.0)
			for k in range(4):
				after(k * 0.08, func() -> void: burst(Vector3(h.x, 2.0, h.z), Color(1.0, 0.85, 0.3), 14, 7.0))
		"komugi":
			rune_fx(hp3, 3.0, 0x9be15d, 1.0)
			for i in range(8):
				after(i * 0.07, func() -> void: _grow_crop(h, s, 2.0))
		"nao":
			if mode != "sandbox":
				lives += 25
				float_text("+25 LIVES", Vector3(h.x, 3.0, h.z), false)
				ui.update_hud()
			pillar(hp3, 0x7fe0a0, 1.6, 0.9)
			rune_fx(hp3, 3.5, 0x7fe0a0, 1.2)
			var gate := pos_at(path_len)
			pillar(gate, 0x7fe0a0, 2.4, 1.0)
			shockwave(gate, 6.0, 0x7fe0a0, 0.7)
		"kaito":
			var ok := opt_from(s, h, {"dmg": 20.0, "type": "magic"})
			for wave in range(2):
				after(wave * 0.22, func() -> void:
					shockwave(hp3, 4.0, 0x9ff3ff, 0.3)
					sfx.play("boom")
					for i in range(8):
						fire(hpos, (i + wave * 0.5) / 8.0 * TAU, "wave", ok, 22.0, 30, {"r": 0.9, "life": 1.6})
					shake = maxf(shake, 0.3 * shake_mul()))
		"rei":
			var tops := _strongest(1)
			var ang := randf() * TAU
			if not tops.is_empty():
				ang = atan2(tops[0].pos.x - h.x, tops[0].pos.z - h.z)
			var dx := sin(ang)
			var dz := cos(ang)
			var orr := opt_from(s, h, {"dmg": 400.0, "type": "magic"})
			_aim(h, h.x + dx, h.z + dz)
			# Charge up, then release
			rune_fx(hp3, 2.6, 0xffb02e, 0.5)
			after(0.4, func() -> void:
				for e in enemies.duplicate():
					if not e.alive:
						continue
					var rx: float = e.pos.x - h.x
					var rz: float = e.pos.z - h.z
					if rx * dx + rz * dz > 0.0 and absf(rx * dz - rz * dx) <= 2.4 + e.r:
						hit_enemy(e, orr)
						burst(e.pos + Vector3(0, 1, 0), Defs.col(0xffd27a), 4, 5.0)
				for layer in range(2):
					var holder := Node3D.new()
					holder.rotation.y = ang
					var bm2 := Models.fx_mat(Defs.col(0xffb02e, 0.8) if layer == 0 else Color(1, 1, 0.9, 0.95), true)
					var wdt := 2.6 if layer == 0 else 1.1
					Models.add(holder, Models.cyl(1.0, 1.0, 1.0, 14), bm2, Vector3(0, 0, 40.0), Vector3(PI / 2, 0, 0), Vector3(wdt, 80.0, wdt))
					Models.add(holder, Models.sphere(1.0, 14), bm2, Vector3(0, 0, 1.0), Vector3.ZERO, Vector3.ONE * wdt * 1.3)
					add_effect(holder, Vector3(h.x, 1.6, h.z), 0.7 - layer * 0.15, "beam", 1.0, bm2)
				for k in range(5):
					shockwave(Vector3(h.x + dx * (6.0 + k * 9.0), 0, h.z + dz * (6.0 + k * 9.0)), 3.5, 0xffb02e, 0.4 + k * 0.05, 0.35)
				sfx.play("boom")
				shake = 0.6 * shake_mul())
		"ichika":
			var oi := opt_from(s, h, {"dmg": 30.0, "type": "magic"})
			rune_fx(hp3, 12.0, 0xd81b60, 2.0)
			shockwave(hp3, 12.0, 0xd81b60, 0.6, 0.3)
			for e in enemies_near(h.x, h.z, 12.0, true):
				e.stun = maxf(e.stun, 1.5 if e.boss else 3.0)
				hit_enemy(e, oi)
				if e.alive:
					pillar(e.pos, 0xd81b60, 0.6, 0.6, 8.0)
		"gen":
			var og := opt_from(s, h, {"dmg": 25.0, "type": "magic", "stun": 1.0, "stun_boss": true})
			var marks5 := _strongest(12)
			for i in range(marks5.size()):
				var to5 := predict(marks5[i], 0.05 * i + 0.45)
				to5.y = 0.5
				after(0.05 * i, func() -> void:
					var g := Models.mi(Models.sphere(0.28, 8), Models.toon(0x4a5568))
					var gh := Node3D.new()
					gh.add_child(g)
					drop(gh, Vector3(h.x, 9.0, h.z), to5, 0.45, func() -> void:
						explode(to5.x, to5.z, {"r": 3.0, "pierce": 30}, og, false)
						shockwave(to5, 3.6, 0xffffff, 0.2, 0.8)))
		"lumi":
			encore_t = 8.0
			if mode != "sandbox":
				lives += 10
				ui.update_hud()
			rune_fx(hp3, 4.0, 0xff6fae, 1.4)
			shockwave(hp3, 40.0, 0xff9fd0, 0.9, 0.2)
			for o in heroes:
				pillar(Vector3(o.x, 0, o.z), 0xff6fae, 0.9, 0.8, 12.0)
				burst(Vector3(o.x, 2.5, o.z), Defs.col(0xff6fae), 10, 4.0)
		"idol":
			encore_t = 10.0
			shockwave(hp3, 40.0, 0xffd34d, 0.9, 0.2)
			for o in heroes:
				pillar(Vector3(o.x, 0, o.z), 0xffd34d, 0.9, 0.8, 12.0)
				burst(Vector3(o.x, 2.5, o.z), Defs.col(0xffd34d), 10, 4.0)
	float_text(String(ABILITIES[h.key]["name"]).to_upper(), Vector3(h.x, 4.0, h.z), false)
	sfx.play("upgrade")
	if _tracking():
		progress.add("abilities")
	ui.refresh_abilities()

# =====================================================================
# Powers: one-shot items bought with Spirit Gems in the Store
# =====================================================================
const POWER_KEYS := [KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L]
const POWER_LIMIT := 3  # per game, so powers help without trivialising a run

func can_use_power(id: String) -> bool:
	if over or paused or attract:
		return false
	if mode != "sandbox" and powers_used_game >= power_limit():
		return false
	return mode == "sandbox" or progress.power_count(id) > 0

func use_power(id: String) -> bool:
	if not can_use_power(id):
		sfx.play("error")
		return false
	if mode != "sandbox":
		progress.take_power(id)
		powers_used_game += 1
	var pw: Array = Progress.power_def(id)
	match id:
		"time_stop":
			for e in enemies:
				if e.alive:
					e.stun = maxf(e.stun, 2.0 if e.boss else 6.0)
					e.frozen = true
			shockwave(cam_target, 80.0, 0x7fd6ff, 1.1, 0.3)
			rune_fx(cam_target, 9.0, 0x7fd6ff, 1.6)
			for e in enemies:
				if e.alive:
					burst(e.pos + Vector3(0, 1, 0), Color(0.8, 0.95, 1.0), 3, 3.0)
			sfx.play("freeze")
		"shrine_bomb":
			var o := {"dmg": 20.0 + round_num * 1.5, "type": "magic", "boss_mul": 2.0}
			for e in enemies.duplicate():
				if e.alive:
					hit_enemy(e, o)
			shake = 0.6 * shake_mul()
			for e in enemies:
				if e.alive:
					pillar(e.pos, 0xff6b5b, 0.8, 0.5, 14.0)
			pillar(pos_at(path_len), 0xff6b5b, 4.0, 0.9, 60.0)
			shockwave(pos_at(path_len), 90.0, 0xff6b5b, 1.0, 0.3)
			sfx.play("boom")
		"cash_drop":
			add_cash(1500.0)
			float_text("+$1500", cam_target + Vector3(0, 3, 0), false)
		"heal":
			lives += 50.0
			float_text("+50 LIVES", cam_target + Vector3(0, 3, 0), false)
			pillar(pos_at(path_len), 0xff7ac8, 3.0, 1.0)
			shockwave(pos_at(path_len), 8.0, 0xff7ac8, 0.8)
		"battle_cry":
			encore_t = maxf(encore_t, 15.0)
			for o in heroes:
				pillar(Vector3(o.x, 0, o.z), 0xffa53c, 0.9, 0.8, 12.0)
		"golden_touch":
			golden_t = 20.0
			shockwave(cam_target, 80.0, 0xffe066, 1.2, 0.25)
	sfx.play("power")
	ui.banner(String(pw[1]).to_upper(), String(pw[2]))
	ui.update_hud()
	ui.refresh_powers()
	return true

# =====================================================================
# Tutorial: a short coach for the very first game
# =====================================================================
const TUTORIAL := [
	"Pick a hero from the shop on the right. Kaede, Hana and Rin are ready from the start.",
	"Now tap on the grass near the stone path to place your hero.",
	"Press the green PLAY button (or Space) to send the first round of spirits.",
	"Tap your hero to open their upgrades.",
	"Buy an upgrade with the money you earn from popping spirits.",
	"Great job! Hold the gate for 40 rounds. Tier 3 upgrades unlock abilities, and gems from wins buy powers in the Store. Good luck!",
]
var tutorial_step := -1
var tutorial_t := 0.0

func start_tutorial() -> void:
	tutorial_step = 0
	tutorial_t = 0.0
	ui.show_tutorial(0, TUTORIAL.size(), TUTORIAL[0])

func end_tutorial() -> void:
	if tutorial_step < 0:
		return
	tutorial_step = -1
	ui.hide_tutorial()
	save.set_value("settings", "tutorial_seen", true)
	progress.set_max("tutorial_done", 1.0)
	progress.check()
	save.save(SAVE_PATH)

func _update_tutorial(dt: float) -> void:
	if tutorial_step < 0 or attract:
		return
	var done := false
	match tutorial_step:
		0: done = placing != "" or not heroes.is_empty()
		1: done = not heroes.is_empty()
		2: done = running or round_num > 0
		3: done = selected != null
		4:
			for h in heroes:
				if h.tiers[0] + h.tiers[1] + h.tiers[2] > 0:
					done = true
		5:
			tutorial_t += dt
			done = tutorial_t > 7.0
	if done:
		tutorial_step += 1
		if tutorial_step >= TUTORIAL.size():
			end_tutorial()
		else:
			sfx.play("place")
			ui.show_tutorial(tutorial_step, TUTORIAL.size(), TUTORIAL[tutorial_step])

func cycle_priority(h: Hero) -> void:
	h.priority = PRIORITIES[(PRIORITIES.find(h.priority) + 1) % PRIORITIES.size()]
	ui.build_panel(h)

func _refresh_hero_look(h: Hero) -> void:
	var mx := 0
	var total := 0
	for v in h.tiers:
		mx = maxi(mx, v)
		total += v
	var col := Defs.col(RING_COLORS[mx])
	(h.model["ring_mat"] as StandardMaterial3D).albedo_color = col
	var main_path: int = h.tiers.find(mx)
	if mx >= 3:
		col = Defs.col(Models.PATH_COLORS[main_path])
	(h.model["body"] as Node3D).scale = Vector3.ONE * (1.0 + total * 0.025)
	var root: Node3D = h.model["root"]
	if mx >= 3 and h.aura == null:
		# A soft glowing disc on the ground marks a tier 3+ hero
		h.aura = Models.add(root, Models.cyl(1.45, 1.45, 0.02, 40), Models.fx_mat(Color(col, 0.3), true), Vector3(0, 0.03, 0))
		h.aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if h.aura:
		(h.aura.material_override as StandardMaterial3D).albedo_color = Color(col, 0.3)

func recalc_buffs() -> void:
	for t in heroes:
		t.buff = {"rate": 1.0, "dmg": 0.0, "pierce": 0, "camo": false}
		for i in heroes:
			if i == t or i.stats["kind"] != "support":
				continue
			if Vector2(i.x, i.z).distance_to(Vector2(t.x, t.z)) > i.stats["range"]:
				continue
			t.buff["rate"] = minf(t.buff["rate"], i.stats["buff_rate"])
			t.buff["dmg"] = maxf(t.buff["dmg"], i.stats["buff_dmg"])
			t.buff["pierce"] = maxi(t.buff["pierce"], i.stats["buff_pierce"])
			t.buff["camo"] = t.buff["camo"] or i.stats["buff_camo"]

func eff(h: Hero) -> Dictionary:
	var s: Dictionary = h.stats.duplicate()
	s["rate"] = float(s["rate"]) * float(h.buff["rate"]) * (0.5 if encore_t > 0.0 else 1.0)
	if float(s.get("dmg", 0.0)) > 0.0:
		s["dmg"] = float(s["dmg"]) + float(h.buff["dmg"])
	s["pierce"] = int(s.get("pierce", 0)) + int(h.buff["pierce"])
	s["camo"] = bool(s.get("camo", false)) or bool(h.buff["camo"])
	return s

# =====================================================================
# Spirits
# =====================================================================
func _template(k: String, camo: bool) -> Node3D:
	var key := k + ("_c" if camo else "")
	if not templates.has(key):
		templates[key] = Models.build_enemy(k, camo, rainbow_mat, rainbow_camo)
	return templates[key]

func spawn_enemy(k: String, d: float = 0.0, camo: bool = false, fort: bool = false, regrow: bool = false, regrow_top: String = "") -> Enemy:
	var def: Dictionary = Defs.ENEMIES[k]
	var e := Enemy.new()
	e.type = k
	e.def = def
	e.d = maxf(0.0, d)
	e.camo = camo
	e.boss = def.get("boss", false)
	var hp_mul := 1.0 + (round_num - 40) * 0.12 if e.boss and round_num > 40 else 1.0
	if e.boss and mode == "boss_rush":
		hp_mul *= 1.25
	e.fortified = fort or mode == "fortified"
	e.hp = float(def["hp"]) * hp_mul * (2.0 if e.fortified else 1.0)
	e.max_hp = e.hp
	e.regrow = regrow and (REGROW_PARENT.has(k) or REGROW_PARENT.values().has(k))
	e.regrow_top = regrow_top if regrow_top != "" else k
	e.regrow_t = REGROW_DELAY
	e.r = float(def["size"]) * (1.05 if e.boss else 1.0)
	e.rank = Defs.rank(k)
	e.bob = randf() * TAU
	e.speed_mul = 1.0 + minf(0.6, (round_num - 40) * 0.02) if round_num > 40 else 1.0
	if mode == "rush":
		e.speed_mul *= 1.25
	e.node = _template(k, camo).duplicate() as Node3D
	_decorate_enemy(e)
	add_child(e.node)
	if def.has("segments"):
		for i in range(int(def["segments"])):
			var sm := Models.mi(Models.sphere(1.4, 18), seg_mats[i % 2], Vector3.ZERO, Vector3.ZERO, Vector3.ONE * (1.0 - i * 0.09))
			Models.add(sm, Models.cone(0.35, 0.9, 6), Models.toon(0xffd34d), Vector3(0, 1.4, 0))
			add_child(sm)
			e.segs.append(sm)
	e.pos = pos_at(e.d)
	_place_enemy_node(e)
	enemies.append(e)
	return e

# Visual markers: a steel band for fortified spirits, a pink halo for regrowing ones.
func _decorate_enemy(e: Enemy) -> void:
	var size: float = e.def["size"]
	if e.fortified:
		Models.add(e.node, Models.torus(size * 1.02, 0.09), Models.toon(0x9aa7b4), Vector3(0, -size * 0.1, 0))
		Models.add(e.node, Models.torus(size * 0.8, 0.07), Models.toon(0x9aa7b4), Vector3(0, size * 0.45, 0))
	if e.regrow:
		Models.add(e.node, Models.torus(size * 0.55, 0.06), Models.flat(0xff6fae), Vector3(0, size * 1.35, 0))

# Regrowing spirits that go untouched for REGROW_DELAY seconds grow back a layer.
func _regrow(e: Enemy) -> void:
	var up: String = REGROW_PARENT.get(e.type, "")
	if up == "" or Defs.rank(up) > Defs.rank(e.regrow_top):
		return
	var def: Dictionary = Defs.ENEMIES[up]
	var old_node := e.node
	e.type = up
	e.def = def
	e.rank = Defs.rank(up)
	e.hp = float(def["hp"]) * (2.0 if e.fortified else 1.0)
	e.max_hp = e.hp
	e.r = float(def["size"])
	e.node = _template(up, e.camo).duplicate() as Node3D
	_decorate_enemy(e)
	add_child(e.node)
	old_node.queue_free()
	_place_enemy_node(e)
	burst(e.node.position, Defs.col(0xff6fae), 6, 3.0)

func _place_enemy_node(e: Enemy) -> void:
	var size: float = e.def["size"]
	var y := size + 0.7 if e.boss else size + 0.45
	e.node.position = Vector3(e.pos.x, y + sin(e.bob) * (0.25 if e.boss else 0.12), e.pos.z)
	e.node.rotation.y = dir_at(e.d)
	if not e.boss:
		var sq := 1.0 + sin(e.bob * 2.0 + 1.0) * 0.045
		e.node.scale = Vector3(2.0 - sq, sq, 2.0 - sq)
	for i in range(e.segs.size()):
		var sd := e.d - (i + 1) * 1.7
		var p := pos_at(maxf(0.0, sd))
		var seg: Node3D = e.segs[i]
		seg.position = Vector3(p.x, y - 0.4 + sin(e.bob - i * 0.8) * 0.4, p.z)
		seg.visible = sd > 0.0

func _remove_enemy(e: Enemy) -> void:
	e.alive = false
	e.node.queue_free()
	for s in e.segs:
		(s as Node3D).queue_free()
	e.segs.clear()
	if e.ice:
		e.ice.queue_free()
		e.ice = null

func apply_slow(e: Enemy, f: float, dur: float) -> void:
	if e.slow_t <= 0.0 or f <= e.slow_f:
		e.slow_f = f
	e.slow_t = maxf(e.slow_t, dur)

# Returns false if the spirit was immune to the hit.
func hit_enemy(e: Enemy, o: Dictionary) -> bool:
	if not e.alive:
		return false
	var typ: String = o["type"]
	if typ != "magic" and e.def.get("immune", "") == typ:
		burst(e.node.position, Color(0.6, 0.6, 0.6), 3, 2.0)
		return false
	var stun: float = o.get("stun", 0.0)
	if stun > 0.0 and (not e.boss or o.get("stun_boss", false)):
		e.stun = maxf(e.stun, stun)
		e.frozen = o.get("freeze", false)
	var slow: float = o.get("slow", 0.0)
	if slow > 0.0:
		apply_slow(e, slow, o.get("slow_dur", 1.0))
	var dmg: float = o.get("dmg", 0.0)
	if dmg <= 0.0:
		return true
	if e.boss:
		dmg *= float(o.get("boss_mul", 1.0)) * (1.1 if blessed("bane") else 1.0)
	if e.def.get("mask", false):
		dmg += float(o.get("mask_bonus", 0.0))
	damage_enemy(e, dmg, o)
	return true

func damage_enemy(e: Enemy, dmg: float, o: Dictionary) -> void:
	e.regrow_t = REGROW_DELAY
	if e.hp > dmg + 0.000001:
		e.hp -= dmg
		if e.boss or e.def.get("mask", false):
			burst(e.node.position, Defs.col(e.def["color"]), 2, 3.0)
		return
	var left := dmg - e.hp
	var kids := pop_enemy(e, o.get("hero"))
	if left > 0.001 and kids.size() > 0:
		var k: Enemy = kids[0]
		if o["type"] == "magic" or k.def.get("immune", "") != o["type"]:
			damage_enemy(k, left, o)

func pop_enemy(e: Enemy, hero) -> Array:
	var where := e.node.position
	_remove_enemy(e)
	earn((0.5 if round_num > 30 else 1.0) * (5.0 if golden_t > 0.0 else 1.0))
	game_pops += 1
	if _tracking():
		progress.add("pops", 1.0, false)
		progress.add_xp(0.25)
		if e.boss:
			progress.add(e.type + "_pops")
		progress.add_to_set("spirits_seen", e.type)
		if hero != null:
			progress.add_hero_xp(hero.key, 1.0)
			progress.add("hero_pops_" + hero.key, 1.0, false)
	if hero != null:
		hero.pops += 1
	var col := Color.from_hsv(randf(), 0.7, 1.0) if e.def.get("rainbow", false) else Defs.col(e.def["color"])
	burst(where, col, 40 if e.boss else 7, 9.0 if e.boss else 5.0)
	if effects.size() < 70:
		# A quick puff where the spirit popped
		var puff := Models.fx_mat(Color(col.lerp(Color.WHITE, 0.55), 0.7), true)
		add_effect(Models.mi(Models.sphere(1.0, 10), puff), where, 0.16, "blast", float(e.def["size"]) * (1.9 if e.boss else 1.5))
	if e.boss:
		sfx.play("boom")
		shake = 0.5 * shake_mul()
	else:
		sfx.play("pop")
	var kids: Array = []
	var i := 0
	for c in e.def["children"]:
		var child_fort: bool = e.fortified and float(Defs.ENEMIES[c]["hp"]) > 1.0
		var k := spawn_enemy(c, e.d - i * 0.55, e.camo, child_fort, e.regrow, e.regrow_top)
		kids.append(k)
		i += 1
	return kids

func _leak(e: Enemy) -> void:
	_remove_enemy(e)
	var lost := int(ceil(Defs.rbe(e.type) - (float(e.def["hp"]) - e.hp)))
	lives -= lost
	float_text("-%d" % lost, e.pos + Vector3(0, 2, 0), true)
	sfx.play("leak")
	shake = minf(0.6, 0.15 + lost * 0.01) * shake_mul()
	if lives <= 0:
		lives = 0
		game_over()
	ui.update_hud()

# =====================================================================
# Targeting
# =====================================================================
func enemies_near(x: float, z: float, rng: float, camo: bool) -> Array:
	var out: Array = []
	for e in enemies:
		if not e.alive or (e.camo and not camo):
			continue
		var dx: float = e.pos.x - x
		var dz: float = e.pos.z - z
		var rr: float = rng + e.r
		var dd := dx * dx + dz * dz
		if dd <= rr * rr:
			e.dd = dd
			out.append(e)
	return out

func sort_priority(list: Array, pr: String) -> Array:
	match pr:
		"first": list.sort_custom(func(a, b): return a.d > b.d)
		"last": list.sort_custom(func(a, b): return a.d < b.d)
		"strong": list.sort_custom(func(a, b): return a.rank > b.rank or (a.rank == b.rank and a.d > b.d))
		_: list.sort_custom(func(a, b): return a.dd < b.dd)
	return list

func predict(e: Enemy, tt: float) -> Vector3:
	var sp := 0.0
	if e.stun <= 0.0:
		sp = float(e.def["speed"]) * SPEED_UNIT * e.speed_mul * (e.slow_f if e.slow_t > 0.0 else 1.0)
	return pos_at(minf(path_len, e.d + sp * tt))

# =====================================================================
# Combat
# =====================================================================
func opt_from(s: Dictionary, h: Hero, over_opts: Dictionary = {}) -> Dictionary:
	var o := {
		"dmg": float(s.get("dmg", 0.0)), "type": s.get("type", "sharp"), "boss_mul": float(s.get("boss_mul", 1.0)),
		"mask_bonus": float(s.get("mask_bonus", 0.0)), "stun": float(s.get("stun", 0.0)), "stun_boss": s.get("stun_boss", false),
		"slow": float(s.get("slow", 0.0)), "slow_dur": float(s.get("slow_dur", 0.0)), "hero": h,
	}
	o.merge(over_opts, true)
	return o

func fire(from: Vector2, angle: float, kind: String, opt: Dictionary, spd: float, pierce: int, extra: Dictionary = {}) -> Proj:
	var p := Proj.new()
	p.node = Models.projectile(kind)
	p.node.position = Vector3(from.x, 1.6, from.y)
	p.node.rotation.y = angle
	add_child(p.node)
	p.x = from.x
	p.z = from.y
	p.speed = spd
	p.vx = sin(angle) * spd
	p.vz = cos(angle) * spd
	p.life = extra.get("life", 1.0)
	p.pierce = pierce
	p.opt = opt
	p.r = extra.get("r", 0.45)
	p.homing = extra.get("homing", false)
	p.explode = extra.get("explode", null)
	p.target = extra.get("target", null)
	projectiles.append(p)
	return p

func explode(x: float, z: float, ex: Dictionary, opt: Dictionary, allow_cluster: bool = true) -> void:
	var list := enemies_near(x, z, ex["r"], true)
	list.sort_custom(func(a, b): return a.dd < b.dd)
	var n := 0
	for e in list:
		if n >= int(ex["pierce"]):
			break
		hit_enemy(e, opt)
		n += 1
	add_effect(Models.mi(Models.sphere(1.0, 16), Models.fx_mat(Defs.col(0xffa040, 0.75), true)), Vector3(x, 1, z), 0.3, "blast", ex["r"])
	add_effect(Models.mi(Models.sphere(1.0, 12), Models.fx_mat(Color(1, 0.97, 0.8, 0.9), true)), Vector3(x, 1, z), 0.16, "blast", float(ex["r"]) * 0.55)
	if not ex.get("sub", false):
		shockwave(Vector3(x, 0, z), float(ex["r"]) * 1.25, 0xffb84a, 0.35, 0.4)
	burst(Vector3(x, 1, z), Defs.col(0xffcc44), 6, 5.0)
	sfx.play("boom")
	var cluster := int(ex.get("cluster", 0))
	if allow_cluster and cluster > 0:
		for i in range(cluster):
			var a := float(i) / cluster * TAU
			fire(Vector2(x, z), a, "frag", opt, 14.0, 1, {"explode": {"r": 1.3, "pierce": 8, "sub": true}, "life": 0.25, "r": 0.3})

# =====================================================================
# Ability effects: things that fall, strike and glow. Timers and falling objects
# run on game time (in _step), so damage lands when the effect lands.
# =====================================================================
var pack_abilities := {}   # hero key -> pack object (scripts/packs.gd)
var timers: Array = []   # [seconds left, Callable]
var drops: Array = []    # falling objects {node, from, to, t, dur, hit}

func after(t: float, fn: Callable) -> void:
	timers.append([t, fn])

## Send `node` from `from` to `to` (speeding up), then call `on_hit`.
func drop(node: Node3D, from: Vector3, to: Vector3, dur: float, on_hit: Callable) -> void:
	var dir := (from - to).normalized()
	node.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)) * node.transform.basis, from)
	add_child(node)
	drops.append({"node": node, "from": from, "to": to, "t": 0.0, "dur": dur, "hit": on_hit})

func _update_fx_sim(dt: float) -> void:
	for i in range(timers.size() - 1, -1, -1):
		timers[i][0] -= dt
		if timers[i][0] <= 0.0:
			var fn: Callable = timers[i][1]
			timers.remove_at(i)
			fn.call()
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d["t"] += dt
		var k := minf(1.0, float(d["t"]) / float(d["dur"]))
		var node: Node3D = d["node"]
		node.position = (d["from"] as Vector3).lerp(d["to"], k * (0.35 + 0.65 * k))
		if k >= 1.0:
			drops.remove_at(i)
			node.queue_free()
			(d["hit"] as Callable).call()

func _clear_fx() -> void:
	timers.clear()
	for d in drops:
		(d["node"] as Node3D).queue_free()
	drops.clear()

## A flat disc of light that spreads across the ground and fades.
func shockwave(pos: Vector3, radius: float, hex: int, life: float = 0.45, alpha: float = 0.55) -> void:
	var m := Models.fx_mat(Defs.col(hex, alpha), true)
	add_effect(Models.mi(Models.cyl(1.0, 1.0, 0.04, 40), m), Vector3(pos.x, 0.35, pos.z), life, "ring", radius)
	_ring_fx(Vector3(pos.x, 0.4, pos.z), radius * 1.05, hex, life * 1.1)

## A column of light from the ground into the sky.
func pillar(pos: Vector3, hex: int, width: float = 1.0, life: float = 0.5, height: float = 26.0) -> void:
	var m := Models.fx_mat(Defs.col(hex, 0.6), true)
	add_effect(Models.mi(Models.cyl(1.0, 1.0, 1.0, 16), m, Vector3.ZERO, Vector3.ZERO, Vector3(width, height, width)), Vector3(pos.x, height / 2.0, pos.z), life, "pillar", width)
	var m2 := Models.fx_mat(Color(1, 1, 1, 0.8), true)
	add_effect(Models.mi(Models.cyl(1.0, 1.0, 1.0, 10), m2, Vector3.ZERO, Vector3.ZERO, Vector3(width * 0.35, height, width * 0.35)), Vector3(pos.x, height / 2.0, pos.z), life * 0.8, "pillar", width * 0.35)

func lightning_strike(pos: Vector3, hex: int = 0xfff36b) -> void:
	var bolt := Models.lightning(24.0, randi(), hex)
	add_effect(bolt, Vector3(pos.x, 0.3, pos.z), 0.22, "flicker")
	shockwave(pos, 2.6, hex, 0.3, 0.7)
	burst(Vector3(pos.x, 1.0, pos.z), Defs.col(hex), 10, 6.0)

func rune_fx(pos: Vector3, radius: float, hex: int, life: float) -> void:
	var node := Models.rune_circle(radius, hex)
	add_effect(node, Vector3(pos.x, 0.42, pos.z), life, "rune", 1.0, node.get_meta("mat"))

## A slash: two crossing arcs of light.
func slash_fx(pos: Vector3, size: float, hex: int = 0xe8f4ff) -> void:
	for i in range(2):
		var arc := Models.mi(Models.torus(1.0, 0.1), Models.fx_mat(Defs.col(hex, 0.95), true), Vector3.ZERO, Vector3(0.5 if i == 0 else -0.5, 0, 0.3))
		add_effect(arc, Vector3(pos.x, 1.4, pos.z), 0.28 + i * 0.06, "slash", size, null, randf() * TAU)

func add_effect(node: Node3D, pos: Vector3, life: float, kind: String, size: float = 1.0, mat: StandardMaterial3D = null, rot: float = 0.0) -> Dictionary:
	node.position = pos
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var m: StandardMaterial3D = mat
	if m == null and node is MeshInstance3D:
		m = (node as MeshInstance3D).material_override as StandardMaterial3D
	var f := {"node": node, "mat": m, "life": life, "max": life, "kind": kind, "size": size, "rot": rot, "a0": m.albedo_color.a if m else 1.0}
	effects.append(f)
	return f

func _update_effects(dt: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var f: Dictionary = effects[i]
		f["life"] -= dt
		var k := 1.0 - float(f["life"]) / float(f["max"])
		var node: Node3D = f["node"]
		var m: StandardMaterial3D = f["mat"]
		var size: float = f["size"]
		match f["kind"]:
			"blast":
				node.scale = Vector3.ONE * (0.3 + k * size)
			"ring":
				var sc := 0.2 + k * size
				node.scale = Vector3(sc, 1, sc)
			"slash":
				var sc2 := size * (0.6 + k * 0.5)
				node.scale = Vector3(sc2, 1, sc2)
				node.rotation.y = float(f["rot"]) + (k - 0.5) * 1.2
			"pillar":
				var w := size * (1.0 - k * 0.75)
				node.scale = Vector3(w, node.scale.y, w)
			"rune":
				node.rotation.y += dt * 1.6
				var grow := minf(1.0, k * 5.0)
				node.scale = Vector3(grow, 1, grow)
			"flicker":
				node.visible = int(k * 6.0) % 2 == 0 or k < 0.3
		if m:
			m.albedo_color.a = float(f["a0"]) * (1.0 - k)
		if float(f["life"]) <= 0.0:
			node.queue_free()
			effects.remove_at(i)

func _ring_fx(pos: Vector3, size: float, hex: int, life: float) -> void:
	var m := Models.fx_mat(Defs.col(hex, 0.8))
	add_effect(Models.mi(Models.torus(1.0, 0.06), m), pos, life, "ring", size)

# =====================================================================
# Farm coin bundles
# =====================================================================
func _grow_crop(h: Hero, s: Dictionary, mul: float = 1.0) -> void:
	var a := randf() * TAU
	var r := randf_range(1.4, 2.6)
	var target := Vector3(h.x + cos(a) * r, 0.0, h.z + sin(a) * r)
	var node := Models.crop_bundle()
	node.position = Vector3(h.x, 1.0, h.z)
	add_child(node)
	var c := {"node": node, "value": float(s["coin_value"]) * mul * (1.1 if blessed("soil") else 1.0), "t": float(s["collect_time"]), "auto": bool(s.get("auto_collect", false)),
		"from": Vector3(h.x, 1.0, h.z), "to": target, "fly": 0.0, "hero": h}
	if c["auto"]:
		c["t"] = 0.9
	crops.append(c)
	h.anim = 0.3
	sfx.play("place")

func _collect_crop(c: Dictionary, by_tap: bool) -> void:
	if not crops.has(c):
		return
	crops.erase(c)
	var node: Node3D = c["node"]
	var pos := node.position
	earn(c["value"])
	float_text("+$%d" % int(c["value"]), pos + Vector3(0, 1.2, 0), false)
	burst(pos + Vector3(0, 0.5, 0), Color(1.0, 0.85, 0.3), 8, 3.0)
	node.queue_free()
	sfx.play("coin")
	if _tracking():
		progress.add("crops")
		if by_tap:
			progress.add("crops_tapped")

func _update_crops(dt: float) -> void:
	for c in crops.duplicate():
		var node: Node3D = c["node"]
		if c["fly"] < 1.0:
			c["fly"] = minf(1.0, c["fly"] + dt * 2.5)
			var f: float = c["fly"]
			var p: Vector3 = (c["from"] as Vector3).lerp(c["to"], f)
			p.y = (1.0 - f) * 1.0 + sin(f * PI) * 2.0
			node.position = p
			continue
		node.rotation.y += dt * 1.5
		node.position.y = absf(sin(time * 3.0 + node.position.x)) * 0.15
		c["t"] -= dt
		if c["t"] <= 0.0:
			_collect_crop(c, false)

func _crop_at(p: Vector3):
	var best = null
	var bd := CROP_PICK
	for c in crops:
		var n: Node3D = c["node"]
		var dd := Vector2(n.position.x, n.position.z).distance_to(Vector2(p.x, p.z))
		if dd < bd:
			bd = dd
			best = c
	return best

func collect_all_crops() -> void:
	for c in crops.duplicate():
		_collect_crop(c, false)

func _clear_crops() -> void:
	for c in crops:
		(c["node"] as Node3D).queue_free()
	crops.clear()

func _aim(h: Hero, x: float, z: float) -> void:
	(h.model["body"] as Node3D).rotation.y = atan2(x - h.x, z - h.z)

func _hero_update(h: Hero, dt: float) -> void:
	var s := eff(h)
	h.cool -= dt
	var rng: float = s["range"]
	if float(s.get("aura_slow", 0.0)) > 0.0:
		for e in enemies_near(h.x, h.z, rng, true):
			apply_slow(e, s["aura_slow"], 0.2)
	if s.get("farm", false) and running:
		h.crop_t -= dt
		if h.crop_t <= 0.0:
			h.crop_t = float(s["crop_rate"])
			_grow_crop(h, s)
	if h.cool > 0.0:
		return
	var kind: String = s["kind"]
	var hpos := Vector2(h.x, h.z)

	if kind == "support":
		if float(s.get("pulse_dmg", 0.0)) <= 0.0:
			return
		var near := enemies_near(h.x, h.z, s["pulse_range"], s["camo"])
		if near.is_empty():
			return
		h.cool = s["rate"]
		sort_priority(near, "close")
		var o := opt_from(s, h, {"dmg": float(s["pulse_dmg"]), "type": "magic"})
		for i in range(mini(near.size(), int(s["pierce"]))):
			hit_enemy(near[i], o)
		_ring_fx(Vector3(h.x, 0.6, h.z), s["pulse_range"], 0xff7ac8, 0.4)
		h.anim = 0.3
		sfx.play("wave")
		return

	if kind == "pulse":
		var near2: Array = []
		for e in enemies_near(h.x, h.z, rng, s["camo"]):
			if s["type"] == "magic" or e.def.get("immune", "") != "cold":
				near2.append(e)
		if near2.is_empty():
			return
		h.cool = s["rate"]
		sort_priority(near2, "close")
		var o2 := opt_from(s, h, {"stun": float(s["freeze"]), "freeze": true})
		for i in range(mini(near2.size(), int(s["pierce"]))):
			hit_enemy(near2[i], o2)
		_ring_fx(Vector3(h.x, 0.5, h.z), rng, 0x9ff3ff, 0.45)
		burst(Vector3(h.x, 1.5, h.z), Defs.col(0xe0f7ff), 10, 6.0)
		h.anim = 0.3
		sfx.play("freeze")
		return

	var list := sort_priority(enemies_near(h.x, h.z, rng, s["camo"]), h.priority)
	if list.is_empty():
		return
	var target: Enemy = list[0]
	h.cool = s["rate"]
	h.anim = 0.18
	h.counter += 1

	if kind == "proj":
		var spd: float = s["proj_speed"]
		var homing: bool = s.get("homing", false)
		var lead := target.pos if homing else predict(target, sqrt(target.dd) / spd)
		var ang := atan2(lead.x - h.x, lead.z - h.z)
		_aim(h, lead.x, lead.z)
		var o3 := opt_from(s, h)
		var count := int(s["count"])
		var life := (rng + 2.0) * 1.6 / spd
		for i in range(count):
			var off := 0.0
			if count > 1:
				off = (float(i) / (count - 1) - 0.5) * float(s["spread"]) * 2.0
			var ex = null
			if s.has("explode"):
				ex = (s["explode"] as Dictionary).duplicate()
			fire(hpos, ang + off, s["proj"], o3, spd, 1 if ex != null else int(s["pierce"]), {"homing": homing, "target": target, "explode": ex, "life": life})
		var fe := int(s.get("flash_every", 0))
		if fe > 0 and h.counter % fe == 0:
			fire(hpos, ang, "flash", opt_from(s, h, {"type": "blast", "stun": 0.4}), spd, 1, {"explode": {"r": 2.4, "pierce": 20}, "homing": true, "target": target, "life": life})
		sfx.play("cast" if s["proj"] == "fireball" else "throw")
	elif kind == "slash":
		_aim(h, target.pos.x, target.pos.z)
		var o4 := opt_from(s, h)
		for i in range(mini(list.size(), int(s["pierce"]))):
			hit_enemy(list[i], o4)
		var ang2 := atan2(target.pos.x - h.x, target.pos.z - h.z)
		var arc := Models.mi(Models.torus(1.0, 0.07), Models.fx_mat(Defs.col(int(s.get("slash_color", 0xe8f4ff)))))
		add_effect(arc, Vector3(h.x, 1.3, h.z), 0.2, "slash", rng * 0.9, null, ang2)
		if s.has("wave"):
			var w: Dictionary = s["wave"]
			fire(hpos, ang2, "wave", opt_from(s, h, {"dmg": float(w["dmg"])}), w["speed"], int(w["pierce"]), {"r": 0.9, "life": 1.1})
		h.spin = 0.25
		sfx.play("slash")
	elif kind == "beam":
		var used := {}
		var targets: Array = [target]
		for e in list:
			if targets.size() >= int(s["count"]):
				break
			if e != target:
				targets.append(e)
		var width: float = s["width"]
		var blen := minf(rng + 1.0, 60.0)
		var o5 := opt_from(s, h)
		for tg in targets:
			var ang3 := atan2(tg.pos.x - h.x, tg.pos.z - h.z)
			_aim(h, tg.pos.x, tg.pos.z)
			var dx := sin(ang3)
			var dz := cos(ang3)
			var hits: Array = []
			for e in enemies:
				if not e.alive or used.has(e) or (e.camo and not s["camo"] and e != tg):
					continue
				var rx: float = e.pos.x - h.x
				var rz: float = e.pos.z - h.z
				var along := rx * dx + rz * dz
				if along < 0.0 or along > blen + e.r:
					continue
				if absf(rx * dz - rz * dx) <= width + e.r:
					hits.append([along, e])
			hits.sort_custom(func(a, b): return a[0] < b[0])
			for i in range(mini(hits.size(), int(s["pierce"]))):
				used[hits[i][1]] = true
				hit_enemy(hits[i][1], o5)
			var holder := Node3D.new()
			holder.rotation.y = ang3
			var bm := Models.fx_mat(Defs.col(int(s.get("beam_color", 0x66f6ff)), 0.9), true)
			var thick := 0.12 + width * 0.2
			Models.add(holder, Models.cyl(1.0, 1.0, 1.0, 8), bm, Vector3(0, 0, blen / 2.0), Vector3(PI / 2, 0, 0), Vector3(thick, blen, thick))
			add_effect(holder, Vector3(h.x, 1.6, h.z), 0.12, "beam", 1.0, bm)
		var me := int(s.get("missile_every", 0))
		if me > 0 and h.counter % me == 0:
			var body: Node3D = h.model["body"]
			for i in range(4):
				fire(hpos, body.rotation.y + (i - 1.5) * 0.5, "missile", opt_from(s, h, {"dmg": float(s["dmg"]) + 2.0, "type": "blast"}), 16.0, 1,
					{"homing": true, "target": list[i % list.size()], "explode": {"r": 1.6, "pierce": 10}, "life": 2.5})
			sfx.play("cast")
		sfx.play("beam")

func _update_projectiles(dt: float) -> void:
	for p in projectiles:
		if p.dead:
			continue
		if p.homing:
			if p.target == null or not p.target.alive:
				var best: Enemy = null
				var bd := 100.0
				for e in enemies:
					if not e.alive or p.hit.has(e):
						continue
					var dd: float = (e.pos.x - p.x) * (e.pos.x - p.x) + (e.pos.z - p.z) * (e.pos.z - p.z)
					if dd < bd:
						bd = dd
						best = e
				p.target = best
			if p.target:
				var want := atan2(p.target.pos.x - p.x, p.target.pos.z - p.z)
				var cur := atan2(p.vx, p.vz)
				var da := wrapf(want - cur, -PI, PI)
				var na := cur + clampf(da, -9.0 * dt, 9.0 * dt)
				p.vx = sin(na) * p.speed
				p.vz = cos(na) * p.speed
		p.x += p.vx * dt
		p.z += p.vz * dt
		p.node.position = Vector3(p.x, 1.6, p.z)
		p.node.rotation.y = atan2(p.vx, p.vz)
		if p.node.has_meta("spin"):
			(p.node.get_meta("spin") as Node3D).rotation.y += dt * 25.0
		p.life -= dt
		if p.life <= 0.0:
			if p.explode != null and p.explode.get("sub", false):
				explode(p.x, p.z, p.explode, p.opt, false)
			p.dead = true
			continue
		for e in enemies:
			if not e.alive or p.hit.has(e):
				continue
			var dx: float = e.pos.x - p.x
			var dz: float = e.pos.z - p.z
			var rr: float = e.r + p.r
			if dx * dx + dz * dz > rr * rr:
				continue
			p.hit[e] = true
			if p.explode != null:
				explode(p.x, p.z, p.explode, p.opt, not p.explode.get("sub", false))
				p.dead = true
				break
			hit_enemy(e, p.opt)
			p.pierce -= 1
			if p.pierce <= 0:
				p.dead = true
				break
	for i in range(projectiles.size() - 1, -1, -1):
		if projectiles[i].dead:
			projectiles[i].node.queue_free()
			projectiles.remove_at(i)

# =====================================================================
# Particles / floating text
# =====================================================================
func burst(pos: Vector3, col: Color, n: int, power: float) -> void:
	var mm := pmm.multimesh
	for k in range(n):
		var a := randf() * TAU
		var u := randf()
		p_pos[p_idx] = pos
		p_vel[p_idx] = Vector3(cos(a) * power * (0.4 + u), 2.0 + randf() * power, sin(a) * power * (0.4 + u))
		p_life[p_idx] = 0.5 + randf() * 0.4
		p_max[p_idx] = p_life[p_idx]
		mm.set_instance_color(p_idx, col)
		p_idx = (p_idx + 1) % PCOUNT

func _update_particles(dt: float) -> void:
	var mm := pmm.multimesh
	for i in range(PCOUNT):
		if p_life[i] <= 0.0:
			continue
		p_life[i] -= dt
		var v: Vector3 = p_vel[i]
		v.y -= 14.0 * dt
		p_vel[i] = v
		var p: Vector3 = p_pos[i] + v * dt
		p.y = maxf(0.1, p.y)
		p_pos[i] = p
		var sc := maxf(0.0, p_life[i] / p_max[i]) * 1.4
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), p))

func float_text(text: String, pos: Vector3, bad: bool) -> void:
	if attract:
		return
	var l := Label3D.new()
	l.text = text
	if ui and ui.font:
		l.font = ui.font
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.012
	l.modulate = Defs.col(0xff4d6d) if bad else Defs.col(0xffd34d)
	l.outline_modulate = Models.INK
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 2.2, 1.3)
	tw.tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.tween_property(l, "outline_modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

# =====================================================================
# Rounds
# =====================================================================
func build_round(r: int) -> Array:
	_rq = []
	_rt = 0.0
	match r:
		1: grp("pink", 20, 0.9)
		2: grp("pink", 32, 0.6)
		3:
			grp("pink", 20, 0.6)
			grp("blue", 6, 0.9, false, 1.0)
		4:
			grp("pink", 25, 0.45)
			grp("blue", 16, 0.7)
		5:
			grp("blue", 22, 0.55)
			grp("pink", 12, 0.3)
		6:
			grp("pink", 15, 0.4)
			grp("blue", 15, 0.5)
			grp("green", 6, 0.9)
		7:
			grp("blue", 25, 0.4)
			grp("green", 10, 0.7)
		8: grp("green", 22, 0.55)
		9: grp("green", 30, 0.35)
		10: grp("blue", 70, 0.13)
		11:
			grp("gold", 10, 0.8)
			grp("green", 20, 0.4)
		12:
			grp("gold", 18, 0.6)
			grp("blue", 30, 0.2)
		_:
			var rng := RandomNumberGenerator.new()
			rng.seed = r * 7919 + 13
			var pool := ["blue", "green", "gold"]
			if r >= 13: pool.append("violet")
			if r >= 15: pool.append_array(["shadow", "frost"])
			if r >= 19: pool.append("prism")
			if r >= 17: pool.append("kitsune")
			if r >= 21: pool.append("crane")
			if r >= 22: pool.append("mask")
			if r >= 24: pool.append("lantern")
			var budget := (30.0 + r * r * (3.4 if r > 20 else 2.1)) * (1.0 + (r - 40) * 0.1 if r > 40 else 1.0)
			var camo_chance := minf(0.35, 0.12 + (r - 14) * 0.01) if r >= 14 else 0.0
			var gap_base := clampf(0.8 - r * 0.014, 0.1, 0.8)
			var groups := 0
			while budget > 0.0 and groups < 7:
				var idx := pool.size() - 1 - int(floor(pow(rng.randf(), 1.6) * pool.size()))
				var type: String = pool[clampi(idx, 0, pool.size() - 1)]
				var cost := Defs.rbe(type)
				var count := clampi(int(round(budget * (0.25 + rng.randf() * 0.3) / cost)), 1, 70)
				var regrow := r >= 16 and REGROW_PARENT.values().has(type) and rng.randf() < 0.25
				var fort := r >= 28 and type == "mask" and rng.randf() < 0.35
				grp(type, count, gap_base * (2.2 if cost > 30.0 else 1.0), rng.randf() < camo_chance, 0.6 if groups == 0 else 0.3, fort, regrow)
				budget -= count * cost
				groups += 1
			var bosses := {25: ["oni"], 30: ["oni", "oni"], 32: ["shogun"], 33: ["oni"], 35: ["oni", "oni", "oni"], 36: ["shogun"], 37: ["oni", "oni"], 38: ["oni", "oni", "oni", "oni"], 40: ["dragon"]}
			if bosses.has(r):
				var b: Array = bosses[r]
				grp(b[0], b.size(), 3.5, false, 1.0)
			if r > 40:
				if r % 7 == 3:
					grp("shogun", maxi(1, int((r - 38) / 12)), 4.0, false, 2.0, r >= 60)
				if r % 5 == 0:
					grp("dragon", maxi(1, int((r - 35) / 10)), 6.0, false, 1.0, r >= 50)
				elif (r - 38) / 3 > 0:
					grp("oni", int((r - 38) / 3), 2.5, false, 1.0, r >= 45)
	if mode == "boss_rush" and r >= 10 and r <= 40 and r % 5 == 0 and not r in [25, 30, 35, 40]:
		grp("shogun" if r >= 30 else "oni", 1, 3.5, false, 1.0)
	var q: Array = _rq
	q.sort_custom(func(a, b): return a["t"] < b["t"])
	return q

var _rq: Array = []
var _rt := 0.0

func grp(type: String, count: int, gap: float, camo: bool = false, delay: float = 0.6, fort: bool = false, regrow: bool = false) -> void:
	_rt += delay
	for i in range(count):
		_rq.append({"t": _rt, "type": type, "camo": camo, "fort": fort, "regrow": regrow})
		_rt += gap

func start_round() -> void:
	if running or over:
		return
	round_num += 1
	queue = build_round(round_num)
	round_time = 0.0
	running = true
	var has_boss := false
	for s in queue:
		if Defs.ENEMIES[s["type"]].get("boss", false):
			has_boss = true
	var sub := ""
	if has_boss:
		sub = "A boss approaches!"
	elif round_num == 1:
		sub = "Protect the shrine!"
	ui.banner("ROUND %d" % round_num, sub)
	ui.update_next_round()
	sfx.play("boss" if has_boss else "round")
	ui.update_hud()

func _end_round() -> void:
	running = false
	collect_all_crops()
	var bonus := int((100 + round_num) * (1.15 if blessed("guild") else 1.0))
	if _tracking():
		progress.add("rounds", 1.0, false)
		progress.add_xp(10.0 + round_num)
		progress.set_max("best_round", round_num)
		for k in squad:
			progress.add_hero_xp(k, 5.0 + round_num)
	var income := 0
	var interest := 0
	for h in heroes:
		if h.stats["kind"] != "support":
			continue
		income += int(h.stats["income"])
		if int(h.stats["income"]) > 0:
			float_text("+$%d" % int(h.stats["income"]), Vector3(h.x, 3.5, h.z), false)
		var regen := int(h.stats.get("lives_regen", 0))
		if regen > 0 and mode != "sandbox":
			lives += regen
			float_text("+%d LIVES" % regen, Vector3(h.x, 4.5, h.z), false)
		h.anim = 0.5
		if h.stats.get("interest", false):
			interest = mini(800, int(cash * 0.05))
	earn(bonus + income + interest)
	_record_best()
	if round_num >= max_round and not freeplay:
		victory()
		return
	_save_run()
	if mode == "rush":
		auto_timer = 0.05
	elif auto_start:
		auto_timer = 1.0
	ui.update_hud()
	ui.update_next_round()

# =====================================================================
# Continue: the game is saved between rounds and can be resumed from the menu
# =====================================================================
func _save_run() -> void:
	if attract or over:
		return
	var hs: Array = []
	for h in heroes:
		hs.append({"k": h.key, "x": h.x, "z": h.z, "t": h.tiers.duplicate(), "pr": h.priority, "spent": h.spent, "pops": h.pops})
	save.set_value("run", "data", {
		"map": map_index, "diff": difficulty, "mode": mode, "round": round_num, "cash": cash, "lives": lives,
		"heroes": hs, "daily": daily_active, "powers": powers_used_game, "class": locked_class,
		"start_lives": start_lives, "squad": squad.keys(), "pops": game_pops, "earned": cash_earned,
		"freeplay": freeplay,
	})
	save.save(SAVE_PATH)

func clear_run() -> void:
	if save.has_section("run"):
		save.erase_section("run")

func saved_run() -> Dictionary:
	return save.get_value("run", "data", {})

func continue_run() -> bool:
	var r: Dictionary = saved_run()
	if r.is_empty():
		return false
	save.set_value("settings", "tutorial_seen", true)
	new_game(r["diff"], int(r["map"]), r["mode"])
	daily_active = bool(r.get("daily", false))
	cash = 1.0e12
	for hd in r["heroes"]:
		var h := place_hero(hd["k"], float(hd["x"]), float(hd["z"]))
		if h == null:
			continue
		var tiers: Array = hd["t"]
		# Re-buy upgrades in the order that keeps path rules happy: the deep path first
		var order := [0, 1, 2]
		order.sort_custom(func(a, b): return int(tiers[a]) > int(tiers[b]))
		for p in order:
			for i in range(int(tiers[p])):
				_force_upgrade(h, p)
		h.priority = hd["pr"]
		h.spent = int(hd["spent"])
		h.pops = int(hd["pops"])
	cash = float(r["cash"])
	lives = float(r["lives"])
	round_num = int(r["round"])
	powers_used_game = int(r.get("powers", 0))
	locked_class = String(r.get("class", ""))
	start_lives = float(r.get("start_lives", lives))
	for k in r.get("squad", []):
		squad[k] = true
	game_pops = int(r.get("pops", 0))
	cash_earned = float(r.get("earned", 0.0))
	freeplay = bool(r.get("freeplay", false))
	select_hero(null)
	ui.rebuild_shop()
	ui.refresh_abilities()
	ui.update_hud()
	ui.update_next_round()
	ui.banner("ROUND %d" % (round_num + 1), "Welcome back!")
	return true

## Apply an upgrade without paying or checking XP unlocks (used when resuming).
func _force_upgrade(h: Hero, p: int) -> void:
	if h.tiers[p] >= 4:
		return
	var up: Array = h.def["paths"][p][h.tiers[p]]
	Defs.apply_upgrade(h.stats, up[3])
	h.tiers[p] += 1
	Models.apply_upgrade_look(h.model, p, h.tiers[p])
	_refresh_hero_look(h)
	recalc_buffs()
	if h.ability_cd < 0.0 and h.tiers.max() >= ABILITY_TIER:
		h.ability_cd = 0.0

## Money earned from pops and rounds goes through the game mode's rules.
func earn(n: float) -> void:
	match mode:
		"half_cash":
			n *= 0.5
		"deflation":
			n = 0.0
	cash_earned += n
	if _tracking() and n > 0.0:
		progress.add("cash_earned", n, false)
	add_cash(n)

func add_cash(n: float) -> void:
	cash += n
	if ui:
		ui.cash_dirty = true

# =====================================================================
# UI hooks
# =====================================================================
func on_play() -> void:
	if over:
		return
	if not running:
		start_round()
	else:
		speed = 1 if speed >= 3 else speed + 1
	ui.update_hud()

func toggle_auto() -> void:
	auto_start = not auto_start
	if auto_start and not running and round_num > 0:
		auto_timer = 0.5
	ui.update_hud()

func toggle_mute() -> void:
	set_setting("sound", not get_setting("sound"))
	ui.update_hud()

func new_game(diff: String, map_i: int = -1, game_mode: String = "", demo: bool = false) -> void:
	attract = demo
	sfx.suppressed = demo
	_show_hub(false)
	if not demo:
		daily_active = daily_active and game_mode != "" and map_i >= 0
	menu.visible = demo
	ui.set_hud_visible(not demo)
	squad = {}
	difficulty = diff
	if game_mode != "":
		mode = game_mode
	paused = false
	encore_t = 0.0
	golden_t = 0.0
	powers_used_game = 0
	locked_class = ""
	game_pops = 0
	cash_earned = 0.0
	if map_i >= 0 and map_i != map_index:
		load_map(map_i)
	if not demo:
		save.set_value("settings", "last_map", map_index)
		save.save(SAVE_PATH)
	for e in enemies:
		_remove_enemy(e)
	enemies.clear()
	for p in projectiles:
		p.node.queue_free()
	projectiles.clear()
	for h in heroes:
		(h.model["root"] as Node3D).queue_free()
	heroes.clear()
	_clear_crops()
	_clear_fx()
	cancel_placing()
	select_hero(null)
	var d: Dictionary = DIFFS[diff]
	cash = 650.0
	lives = d["lives"]
	match mode:
		"deflation":
			cash = 20000.0
		"sandbox":
			cash = 1.0e9
			lives = 1.0e9
	cost_mul = d["cost"]
	if mode not in ["sandbox", "deflation"]:
		cash += (100.0 if blessed("cash_1") else 0.0) + (200.0 if blessed("cash_2") else 0.0)
	if mode != "sandbox" and diff != "nightmare":
		lives += (10.0 if blessed("lives_1") else 0.0) + (20.0 if blessed("lives_2") else 0.0)
	round_num = 0
	speed = 1
	running = false
	over = false
	freeplay = false
	queue = []
	auto_timer = -1.0
	auto_start = get_setting("autostart") and not demo
	start_lives = lives
	ui.rebuild_shop()
	ui.refresh_abilities()
	ui.refresh_powers()
	if not demo:
		music.play_song("game")
	tutorial_step = -1
	ui.hide_tutorial()
	if not demo:
		clear_run()
	if not demo and mode != "sandbox" and not bool(save.get_value("settings", "tutorial_seen", false)):
		start_tutorial()
	ui.set_hud_visible(not demo)
	ui.update_hud()
	ui.update_next_round()
	ui.show_pause(false)
	ui.show_sandbox(mode == "sandbox" and not demo)
	if not demo:
		if _tracking():
			progress.add("games")
			progress.add_to_set("themes_played", String(current_map()["theme"]))
		ui.banner(String(current_map()["name"]).to_upper(), "%s - %s%s" % [diff.capitalize(), MODES[mode]["name"], "  (DAILY)" if daily_active else ""])

func restart() -> void:
	new_game(difficulty, map_index, mode)

## Map select, shown over the village menu scene.
func to_menu() -> void:
	_enter_menus()
	menu.visible = false
	ui.show_menu()

## Main menu: the village scene with the player's heroes.
func to_home() -> void:
	_enter_menus()
	ui.start_screen.visible = false
	menu.show_home()

# Leave any running game and switch to the menu scene.
func _enter_menus() -> void:
	music.play_song("menu")
	paused = false
	daily_active = false
	attract = true
	over = true
	running = false
	sfx.suppressed = false
	ui.show_pause(false)
	ui.end_screen.visible = false
	for e in enemies:
		_remove_enemy(e)
	enemies.clear()
	for p in projectiles:
		p.node.queue_free()
	projectiles.clear()
	for h in heroes:
		(h.model["root"] as Node3D).queue_free()
	heroes.clear()
	_clear_crops()
	cancel_placing()
	select_hero(null)
	ui.set_hud_visible(false)
	ui.hide_boss()
	_show_hub(true)

func _show_hub(on: bool) -> void:
	hub.visible = on
	level.visible = not on
	if on:
		var keys: Array = []
		for k in Defs.HERO_ORDER:
			if progress.level() >= int(Defs.UNLOCK_LEVEL[k]) and keys.size() < 7:
				keys.append(k)
		hub.set_heroes(keys)
		hub.camera.make_current()
	else:
		camera.make_current()

func start_daily() -> void:
	var d: Dictionary = progress.daily()
	daily_active = true
	menu.visible = false
	new_game(d["diff"], d["map"], d["mode"])

func reset_progress() -> void:
	progress.reset()
	save.save(SAVE_PATH)

func _on_level_up(lv: int) -> void:
	ui.toast("LEVEL UP!", "You reached level %d" % lv)
	for k in Defs.UNLOCK_LEVEL:
		if int(Defs.UNLOCK_LEVEL[k]) == lv:
			ui.toast("NEW HERO UNLOCKED", "%s the %s" % [Defs.HEROES[k]["name"], Defs.HEROES[k]["role"]])
	ui.rebuild_shop()

## Progress only counts in real games (not the menu demo or sandbox).
func _tracking() -> bool:
	return not attract and mode != "sandbox"

# ---------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------
const SETTING_DEFAULTS := {"music": true, "sound": true, "shake": true, "shadows": true, "autostart": false}

func get_setting(key: String) -> bool:
	return bool(save.get_value("settings", key, SETTING_DEFAULTS.get(key, true)))

func set_setting(key: String, value: bool) -> void:
	save.set_value("settings", key, value)
	save.save(SAVE_PATH)
	_apply_settings()

func _apply_settings() -> void:
	sfx.muted = not get_setting("sound")
	if music:
		music.set_enabled(get_setting("music"))
	sun.shadow_enabled = get_setting("shadows")
	if ui:
		ui.update_hud()

func shake_mul() -> float:
	return 1.0 if get_setting("shake") else 0.0

# ---------------------------------------------------------------------
# Sandbox tools and next-round preview
# ---------------------------------------------------------------------
func sandbox_spawn(type: String, camo: bool, fort: bool, regrow: bool) -> void:
	if mode != "sandbox" or over:
		return
	spawn_enemy(type, 0.0, camo, fort, regrow, type)

func sandbox_clear() -> void:
	for e in enemies.duplicate():
		_remove_enemy(e)
	enemies.clear()

## Spirit counts of round `r`, strongest first: [[type, count], ...].
func preview_round(r: int) -> Array:
	var counts := {}
	for s in build_round(r):
		counts[s["type"]] = int(counts.get(s["type"], 0)) + 1
	var out: Array = []
	for k in counts:
		out.append([k, counts[k]])
	out.sort_custom(func(a, b): return Defs.rank(a[0]) > Defs.rank(b[0]))
	return out

func toggle_pause() -> void:
	if over:
		return
	paused = not paused
	ui.show_pause(paused)

func continue_freeplay() -> void:
	over = false
	freeplay = true
	ui.update_hud()
	ui.banner("FREEPLAY", "How long can you last?")

func game_over() -> void:
	if over:
		return
	over = true
	running = false
	clear_run()
	sfx.play("lose")
	var gems := 0
	if _tracking():
		gems = (round_num / 10) * 5
		progress.add_gems(gems)
	_record_best()
	ui.show_end(false, "The spirits reached the shrine on round %d.\n%s%s" % [round_num, _stats_text(), "\n+%d Spirit Gems" % gems if gems > 0 else ""])

func victory() -> void:
	over = true
	clear_run()
	var win_gems := 0
	var charm_txt := ""
	sfx.play("win")
	var medal := mode != "sandbox"
	if medal:
		save.set_value("medals", _save_key(), true)
	if _tracking():
		var m := current_map()
		progress.add("wins", 1.0, false)
		if difficulty == "hard":
			progress.add("hard_wins", 1.0, false)
		if lives >= start_lives:
			progress.add("perfect_wins", 1.0, false)
		progress.add("won_tier_" + String(m["tier"]), 1.0, false)
		progress.add_to_set("modes_won", mode)
		progress.add_to_set("maps_won", String(m["id"]))
		progress.add_xp({"easy": 300.0, "normal": 500.0, "hard": 800.0, "nightmare": 1500.0}[difficulty])
		if difficulty == "nightmare":
			progress.add("nightmare_wins", 1.0, false)
		win_gems = int({"easy": 15, "normal": 25, "hard": 40, "nightmare": 80}[difficulty] * (1.5 if String(current_map()["tier"]) == "expert" else 1.0) * (1.2 if blessed("finder") else 1.0))
		progress.add_gems(win_gems)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in range(2 if difficulty in ["hard", "nightmare"] else 1):
			var ck: String = progress.roll_charm(Defs.HERO_ORDER, rng)
			progress.add_charm(ck)
			charm_txt += "\nHero Charm: %s %s" % [Defs.HEROES[Progress.parse_charm(ck)["hero"]]["name"], charm_label(ck)]
		for k in squad:
			progress.add_hero_xp(k, 200.0)
		if daily_active:
			progress.complete_daily()
		progress.check()
	_record_best()
	ui.show_end(true, "You held the gate for all %d rounds%s.\n%s%s" % [max_round, "" if mode == "sandbox" else " with %d lives left" % int(ceil(lives)), _stats_text(), ("\nMedal earned!" if medal else "") + ("  +%d Spirit Gems" % win_gems if win_gems > 0 else "") + charm_txt])

func _save_key(map_i: int = -1, diff: String = "", m: String = "") -> String:
	var mi := map_index if map_i < 0 else map_i
	return "%s|%s|%s" % [Maps.MAPS[mi]["id"], difficulty if diff == "" else diff, mode if m == "" else m]

func _record_best() -> void:
	if mode == "sandbox":
		return
	var key := _save_key()
	if round_num > int(save.get_value("best", key, 0)):
		save.set_value("best", key, round_num)
	save.set_value("stats", "total_pops", int(save.get_value("stats", "total_pops", 0)) + game_pops)
	game_pops = 0
	save.save(SAVE_PATH)

func best_round(map_i: int, diff: String, m: String) -> int:
	return int(save.get_value("best", _save_key(map_i, diff, m), 0))

func has_medal(map_i: int, diff: String, m: String) -> bool:
	return bool(save.get_value("medals", _save_key(map_i, diff, m), false))

func _stats_text() -> String:
	return "Spirits popped: %d   Money earned: $%d   Heroes: %d" % [game_pops, int(cash_earned), heroes.size()]

# =====================================================================
# Main loop
# =====================================================================
func _step(dt: float) -> void:
	_update_fx_sim(dt)
	if running:
		round_time += dt
		while not queue.is_empty() and queue[0]["t"] <= round_time:
			var s: Dictionary = queue.pop_front()
			spawn_enemy(s["type"], 0.0, s["camo"], s.get("fort", false), s.get("regrow", false), s["type"])
	elif auto_timer > 0.0:
		auto_timer -= dt
		if auto_timer <= 0.0:
			auto_timer = -1.0
			if auto_start or mode == "rush":
				start_round()

	if encore_t > 0.0:
		encore_t -= dt
	if golden_t > 0.0:
		golden_t -= dt
	for h in heroes:
		if h.ability_cd > 0.0:
			h.ability_cd = maxf(0.0, h.ability_cd - dt)
	for e in enemies.duplicate():
		if not e.alive:
			continue
		if e.regrow:
			e.regrow_t -= dt
			if e.regrow_t <= 0.0:
				e.regrow_t = REGROW_DELAY
				_regrow(e)
		if e.stun > 0.0:
			e.stun -= dt
		else:
			e.frozen = false
			var sp: float = float(e.def["speed"]) * SPEED_UNIT * e.speed_mul
			if e.slow_t > 0.0:
				e.slow_t -= dt
				sp *= e.slow_f
			e.d += sp * dt
			e.bob += dt * 6.0
		if e.d >= path_len:
			_leak(e)
			if over:
				return
			continue
		e.pos = pos_at(e.d)

	for h in heroes:
		_hero_update(h, dt)
	_update_projectiles(dt)
	enemies = enemies.filter(func(e): return e.alive)

	if running and queue.is_empty() and enemies.is_empty():
		_end_round()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	if paused:
		dt = 0.0
	if not over and not paused:
		var n := speed if running else 1
		for i in range(n):
			_step(dt)
			if over:
				break
	var sim_dt := dt * (speed if running else 1)

	for e in enemies:
		if not e.alive:
			continue
		_place_enemy_node(e)
		if e.frozen and e.stun > 0.0:
			if e.ice == null:
				e.ice = Models.mi(Models.box(1, 1, 1), ice_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * e.r * 2.3)
				add_child(e.ice)
			e.ice.visible = true
			e.ice.position = e.node.position
		elif e.ice:
			e.ice.visible = false
	rainbow_mat.albedo_color = Color.from_hsv(fmod(time * 0.4, 1.0), 0.75, 1.0)
	rainbow_camo.albedo_color = Color(rainbow_mat.albedo_color, 0.4)

	for h in heroes:
		var body: Node3D = h.model["body"]
		var rarm: Node3D = h.model["rarm"]
		h.anim = maxf(0.0, h.anim - sim_dt)
		var a: float = h.anim
		rarm.rotation.x = -0.9 - (sin(a / 0.18 * PI) * 1.3 if a > 0.0 else 0.0)
		var bounce := sin(a * 20.0) * 0.15 if a > 0.0 and h.stats["kind"] == "support" else 0.0
		body.position.y = 0.36 + absf(sin(time * 2.4 + h.x)) * 0.05 + bounce
		if h.spin > 0.0:
			h.spin -= sim_dt
			body.rotation.y += sim_dt * 30.0
		if h.aura:
			h.aura.rotation.y += dt
		for sp in h.model["spinners"]:
			(sp as Node3D).rotation.y += dt * 2.2
		if h.stats["kind"] == "support" and float(h.stats.get("pulse_dmg", 0.0)) <= 0.0:
			body.rotation.y = sin(time * 1.3 + h.z) * 0.6
	if not ghost.is_empty():
		(ghost["body"] as Node3D).position.y = 0.36 + sin(time * 5.0) * 0.1

	_update_effects(sim_dt)
	_update_crops(sim_dt)
	_update_tutorial(dt)
	_update_particles(dt)
	for fn in animated:
		fn.call(time, dt)

	var boss: Enemy = null
	for e in enemies:
		if e.alive and e.boss and (boss == null or e.rank > boss.rank or (e.rank == boss.rank and e.d > boss.d)):
			boss = e
	if boss:
		ui.show_boss(boss.def["name"], boss.hp / boss.max_hp)
	else:
		ui.hide_boss()

	shake = maxf(0.0, shake - dt)
	_update_camera()
