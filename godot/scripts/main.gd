# Sakura Spirit Defense — main game controller.
# Everything (map, models, UI) is generated from code; main.tscn is just this node.
extends Node3D

const Defs = preload("res://scripts/defs.gd")
const Models = preload("res://scripts/models.gd")
const GameUI = preload("res://scripts/ui.gd")
const Sfx = preload("res://scripts/sfx.gd")
const LevelScene = preload("res://scenes/level/level.tscn")

const PATH_W := 4.0  # stone track width including its low barriers
const SPEED_UNIT := 3.4
const HERO_SCALE := 1.25
const CORNER_RADIUS := 1.3  # spirits round the 90-degree corners slightly
const RING_COLORS := [0xffffff, 0x9be15d, 0x4fc3f7, 0xb388ff, 0xffd54f]
const PRIORITIES := ["first", "last", "strong", "close"]
const DIFFS := {"easy": {"lives": 200, "cost": 0.85}, "normal": {"lives": 150, "cost": 1.0}, "hard": {"lives": 100, "cost": 1.08}}

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

var enemies: Array = []
var heroes: Array = []
var projectiles: Array = []
var effects: Array = []
var blockers: Array = []  # Vector3(x, z, radius)
var animated: Array = []  # Callables(t, dt)

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
var level

var ghost: Dictionary = {}
var range_root: Node3D
var range_ring_mat: StandardMaterial3D
var range_disk_mat: StandardMaterial3D

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
	rainbow_mat = Models.make_toon(Color.RED)
	rainbow_camo = Models.make_toon(Color(1, 0, 0, 0.4))
	ice_mat = Models.make_toon(Defs.col(0xbff4ff, 0.55), false)
	seg_mats = [Models.toon(0x26a69a), Models.toon(0x4dd0b8)]
	_setup_env()
	level = LevelScene.instantiate()
	level.name = "Level"
	add_child(level)
	blockers = level.blockers
	_build_path()
	_setup_particles()
	_setup_range()
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Defs.col(0x3d9df2)
	sm.sky_horizon_color = Defs.col(0xbfe8ff)
	sm.ground_horizon_color = Defs.col(0xbfe8ff)
	sm.ground_bottom_color = Defs.col(0x1f9ad6)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.98, 0.92)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Defs.col(0xfff1dc)
	sun.light_energy = 0.8
	sun.shadow_blur = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.rotation_degrees = Vector3(-62, -28, 0)
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 900.0
	add_child(camera)
	camera.make_current()

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
	var sm := Models.sphere(0.13, 4)
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
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist *= 0.9
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist *= 1.1
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				pressing = true
				dragging = false
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
		if pressing and dragging:
			if press_button == MOUSE_BUTTON_LEFT:
				cam_yaw -= mm.relative.x * 0.006
				cam_pitch += mm.relative.y * 0.005
			else:
				var right := camera.global_transform.basis.x
				var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
				cam_target += (-right * mm.relative.x + fwd * mm.relative.y) * cam_dist * 0.0015
		_update_ghost(mm.position)
	elif event is InputEventMagnifyGesture:
		cam_dist /= (event as InputEventMagnifyGesture).factor
	elif event is InputEventPanGesture:
		cam_dist *= 1.0 + (event as InputEventPanGesture).delta.y * 0.05
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		_on_key(event as InputEventKey)

func _on_key(k: InputEventKey) -> void:
	if over:
		return
	var code := k.keycode
	if code >= KEY_1 and code <= KEY_7:
		begin_placing(Defs.HERO_ORDER[code - KEY_1])
	elif code == KEY_ESCAPE:
		cancel_placing()
		select_hero(null)
	elif code == KEY_SPACE:
		on_play()
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
		if valid_spot(p.x, p.z):
			var k := placing
			var h := place_hero(k, p.x, p.z)
			if h and shift and cash >= price(Defs.HEROES[k]["cost"]):
				ui.refresh()
				return
			cancel_placing()
			if h:
				select_hero(h)
		else:
			sfx.play("error")
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
	if cash < price(Defs.HEROES[k]["cost"]):
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

func cancel_placing() -> void:
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
func place_hero(k: String, x: float, z: float) -> Hero:
	var def: Dictionary = Defs.HEROES[k]
	var cost := price(def["cost"])
	if cash < cost:
		return null
	add_cash(-cost)
	var h := Hero.new()
	h.key = k
	h.def = def
	h.x = x
	h.z = z
	h.model = Models.build_hero(k)
	h.stats = (def["base"] as Dictionary).duplicate(true)
	h.spent = cost
	h.tiers = [0, 0, 0]
	var root: Node3D = h.model["root"]
	root.position = Vector3(x, 0, z)
	root.scale = Vector3.ONE * HERO_SCALE
	(h.model["body"] as Node3D).rotation.y = atan2(-x, 20.0 - z)
	add_child(root)
	heroes.append(h)
	recalc_buffs()
	burst(Vector3(x, 0.4, z), Color.WHITE, 14, 4.0)
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
	select_hero(null)

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
	return ""

func buy_upgrade(h: Hero, p: int) -> void:
	if can_upgrade(h, p) != "":
		return
	var up: Array = h.def["paths"][p][h.tiers[p]]
	var cost := price(up[1])
	if cash < cost:
		sfx.play("error")
		return
	add_cash(-cost)
	Defs.apply_upgrade(h.stats, up[3])
	h.tiers[p] += 1
	h.spent += cost
	_refresh_hero_look(h)
	recalc_buffs()
	burst(Vector3(h.x, 2, h.z), Defs.col(RING_COLORS[h.tiers[p]]), 24, 6.0)
	sfx.play("upgrade")
	if selected == h:
		show_range(h.x, h.z, h.stats["range"], true)
		ui.build_panel(h)

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
	(h.model["body"] as Node3D).scale = Vector3.ONE * (1.0 + total * 0.025)
	var root: Node3D = h.model["root"]
	if mx >= 3 and h.aura == null:
		h.aura = Models.add(root, Models.cyl(1.1, 1.1, 2.8, 24), Models.fx_mat(Color(col, 0.18), true), Vector3(0, 1.6, 0))
		h.aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if h.aura:
		(h.aura.material_override as StandardMaterial3D).albedo_color = Color(col, 0.18)
	if mx >= 4 and h.halo == null:
		h.halo = Models.add(root, Models.torus(0.5, 0.05), Models.flat(0xffe066), Vector3(0, 3.25, 0))

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
	s["rate"] = float(s["rate"]) * float(h.buff["rate"])
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

func spawn_enemy(k: String, d: float = 0.0, camo: bool = false) -> Enemy:
	var def: Dictionary = Defs.ENEMIES[k]
	var e := Enemy.new()
	e.type = k
	e.def = def
	e.d = maxf(0.0, d)
	e.camo = camo
	e.boss = def.get("boss", false)
	var hp_mul := 1.0 + (round_num - 40) * 0.12 if e.boss and round_num > 40 else 1.0
	e.hp = float(def["hp"]) * hp_mul
	e.max_hp = e.hp
	e.r = float(def["size"]) * (1.05 if e.boss else 1.0)
	e.rank = Defs.rank(k)
	e.bob = randf() * TAU
	e.speed_mul = 1.0 + minf(0.6, (round_num - 40) * 0.02) if round_num > 40 else 1.0
	e.node = _template(k, camo).duplicate() as Node3D
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

func _place_enemy_node(e: Enemy) -> void:
	var size: float = e.def["size"]
	var y := size + 0.7 if e.boss else size + 0.45
	e.node.position = Vector3(e.pos.x, y + sin(e.bob) * (0.25 if e.boss else 0.12), e.pos.z)
	e.node.rotation.y = dir_at(e.d)
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
		dmg *= float(o.get("boss_mul", 1.0))
	if e.def.get("mask", false):
		dmg += float(o.get("mask_bonus", 0.0))
	damage_enemy(e, dmg, o)
	return true

func damage_enemy(e: Enemy, dmg: float, o: Dictionary) -> void:
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
	add_cash(0.5 if round_num > 30 else 1.0)
	if hero != null:
		hero.pops += 1
	var col := Color.from_hsv(randf(), 0.7, 1.0) if e.def.get("rainbow", false) else Defs.col(e.def["color"])
	burst(where, col, 40 if e.boss else 7, 9.0 if e.boss else 5.0)
	if e.boss:
		sfx.play("boom")
		shake = 0.5
	else:
		sfx.play("pop")
	var kids: Array = []
	var i := 0
	for c in e.def["children"]:
		var k := spawn_enemy(c, e.d - i * 0.55, e.camo)
		kids.append(k)
		i += 1
	return kids

func _leak(e: Enemy) -> void:
	_remove_enemy(e)
	var lost := int(ceil(Defs.rbe(e.type) - (float(e.def["hp"]) - e.hp)))
	lives -= lost
	float_text("-%d" % lost, e.pos + Vector3(0, 2, 0), true)
	sfx.play("leak")
	shake = minf(0.6, 0.15 + lost * 0.01)
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
	add_effect(Models.mi(Models.sphere(1.0, 16), Models.fx_mat(Defs.col(0xffa040, 0.8))), Vector3(x, 1, z), 0.28, "blast", ex["r"])
	burst(Vector3(x, 1, z), Defs.col(0xffcc44), 6, 5.0)
	sfx.play("boom")
	var cluster := int(ex.get("cluster", 0))
	if allow_cluster and cluster > 0:
		for i in range(cluster):
			var a := float(i) / cluster * TAU
			fire(Vector2(x, z), a, "frag", opt, 14.0, 1, {"explode": {"r": 1.3, "pierce": 8, "sub": true}, "life": 0.25, "r": 0.3})

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
		if m:
			m.albedo_color.a = float(f["a0"]) * (1.0 - k)
		if float(f["life"]) <= 0.0:
			node.queue_free()
			effects.remove_at(i)

func _ring_fx(pos: Vector3, size: float, hex: int, life: float) -> void:
	var m := Models.fx_mat(Defs.col(hex, 0.8))
	add_effect(Models.mi(Models.torus(1.0, 0.06), m), pos, life, "ring", size)

func _aim(h: Hero, x: float, z: float) -> void:
	(h.model["body"] as Node3D).rotation.y = atan2(x - h.x, z - h.z)

func _hero_update(h: Hero, dt: float) -> void:
	var s := eff(h)
	h.cool -= dt
	var rng: float = s["range"]
	if float(s.get("aura_slow", 0.0)) > 0.0:
		for e in enemies_near(h.x, h.z, rng, true):
			apply_slow(e, s["aura_slow"], 0.2)
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
		var arc := Models.mi(Models.torus(1.0, 0.07), Models.fx_mat(Defs.col(0xe8f4ff)))
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
			var bm := Models.fx_mat(Defs.col(0x66f6ff, 0.9), true)
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
			if r >= 22: pool.append("mask")
			var budget := (30.0 + r * r * (3.4 if r > 20 else 2.1)) * (1.0 + (r - 40) * 0.1 if r > 40 else 1.0)
			var camo_chance := minf(0.35, 0.12 + (r - 14) * 0.01) if r >= 14 else 0.0
			var gap_base := clampf(0.8 - r * 0.014, 0.1, 0.8)
			var groups := 0
			while budget > 0.0 and groups < 7:
				var idx := pool.size() - 1 - int(floor(pow(rng.randf(), 1.6) * pool.size()))
				var type: String = pool[clampi(idx, 0, pool.size() - 1)]
				var cost := Defs.rbe(type)
				var count := clampi(int(round(budget * (0.25 + rng.randf() * 0.3) / cost)), 1, 70)
				grp(type, count, gap_base * (2.2 if cost > 30.0 else 1.0), rng.randf() < camo_chance, 0.6 if groups == 0 else 0.3)
				budget -= count * cost
				groups += 1
			var bosses := {25: ["oni"], 30: ["oni", "oni"], 33: ["oni"], 35: ["oni", "oni", "oni"], 37: ["oni", "oni"], 38: ["oni", "oni", "oni", "oni"], 40: ["dragon"]}
			if bosses.has(r):
				var b: Array = bosses[r]
				grp(b[0], b.size(), 3.5, false, 1.0)
			if r > 40:
				if r % 5 == 0:
					grp("dragon", maxi(1, int((r - 35) / 10)), 6.0, false, 1.0)
				elif (r - 38) / 3 > 0:
					grp("oni", int((r - 38) / 3), 2.5, false, 1.0)
	var q: Array = _rq
	q.sort_custom(func(a, b): return a["t"] < b["t"])
	return q

var _rq: Array = []
var _rt := 0.0

func grp(type: String, count: int, gap: float, camo: bool = false, delay: float = 0.6) -> void:
	_rt += delay
	for i in range(count):
		_rq.append({"t": _rt, "type": type, "camo": camo})
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
	sfx.play("boss" if has_boss else "round")
	ui.update_hud()

func _end_round() -> void:
	running = false
	var bonus := 100 + round_num
	var income := 0
	var interest := 0
	for h in heroes:
		if h.stats["kind"] != "support":
			continue
		income += int(h.stats["income"])
		float_text("+$%d" % int(h.stats["income"]), Vector3(h.x, 3.5, h.z), false)
		h.anim = 0.5
		if h.stats.get("interest", false):
			interest = mini(800, int(cash * 0.05))
	add_cash(bonus + income + interest)
	if round_num >= max_round and not freeplay:
		victory()
		return
	if auto_start:
		auto_timer = 1.0
	ui.update_hud()

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
	sfx.muted = not sfx.muted
	ui.update_hud()

func new_game(diff: String) -> void:
	difficulty = diff
	for e in enemies:
		_remove_enemy(e)
	enemies.clear()
	for p in projectiles:
		p.node.queue_free()
	projectiles.clear()
	for h in heroes:
		(h.model["root"] as Node3D).queue_free()
	heroes.clear()
	cancel_placing()
	select_hero(null)
	var d: Dictionary = DIFFS[diff]
	cash = 650.0
	lives = d["lives"]
	cost_mul = d["cost"]
	round_num = 0
	speed = 1
	running = false
	over = false
	freeplay = false
	queue = []
	auto_timer = -1.0
	ui.rebuild_shop()
	ui.update_hud()
	ui.banner("READY?", "Place heroes, then press START")

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
	sfx.play("lose")
	ui.show_end(false, "The spirits reached the shrine on round %d.\nTry new hero combos and upgrade paths!" % round_num)

func victory() -> void:
	over = true
	sfx.play("win")
	ui.show_end(true, "You held the gate for all %d rounds with %d lives left.\nKeep going in freeplay?" % [max_round, int(ceil(lives))])

# =====================================================================
# Main loop
# =====================================================================
func _step(dt: float) -> void:
	if running:
		round_time += dt
		while not queue.is_empty() and queue[0]["t"] <= round_time:
			var s: Dictionary = queue.pop_front()
			spawn_enemy(s["type"], 0.0, s["camo"])
	elif auto_timer > 0.0:
		auto_timer -= dt
		if auto_timer <= 0.0:
			auto_timer = -1.0
			if auto_start:
				start_round()

	for e in enemies.duplicate():
		if not e.alive:
			continue
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
	if not over:
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
		if h.halo:
			h.halo.position.y = 3.25 + sin(time * 2.0) * 0.08
		if h.stats["kind"] == "support" and float(h.stats.get("pulse_dmg", 0.0)) <= 0.0:
			body.rotation.y = sin(time * 1.3 + h.z) * 0.6
	if not ghost.is_empty():
		(ghost["body"] as Node3D).position.y = 0.36 + sin(time * 5.0) * 0.1

	_update_effects(sim_dt)
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
