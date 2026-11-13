# The main menu backdrop: a cosy shrine village on a small island, with the
# player's heroes hanging around the plaza. It lives far away from the
# game board and has its own camera.
extends Node3D

const Models = preload("res://scripts/models.gd")
const Defs = preload("res://scripts/defs.gd")
const HouseScene = preload("res://scenes/props/house.tscn")
const WindmillScene = preload("res://scenes/props/windmill.tscn")
const TreeScene = preload("res://scenes/props/tree.tscn")
const PalmScene = preload("res://scenes/props/palm.tscn")
const BushScene = preload("res://scenes/props/bush.tscn")
const DecoScene = preload("res://scenes/props/decoration.tscn")
const Ground = preload("res://scripts/ground.gd")
const LevelScript = preload("res://scripts/level/level.gd")
const ISLAND_R := 24.5

var camera: Camera3D
var heroes: Array = []   # [model dict, base position, phase, hop timer]
var _orb: Node3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _ground_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _shade: Array = []   # Vector3(x, z, radius) of props, for the ground's contact shade

func _ready() -> void:
	_rng.seed = 77
	_build_ground()
	_build_plaza()
	_build_village()
	_bake_ground()
	camera = Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.position = Vector3(0, 12.5, 21.0)
	camera.look_at(global_position + Vector3(0, 1.6, -1.0), Vector3.UP)

func _flat(hex: int) -> StandardMaterial3D:
	var m := Models.make_toon(Defs.col(hex), false, true)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_ground() -> void:
	# A round island: painted grass and sand over the animated sea, lit like the meadow maps.
	var theme: Dictionary = LevelScript.THEMES["meadow"]
	var origin := Vector2(global_position.x, global_position.z)
	_ground_mat = Ground.ground_material(theme, origin)
	_water_mat = Ground.water_material(theme, origin)
	var sea := PlaneMesh.new()
	sea.size = Vector2(900, 900)
	var sea_mi := Models.mi(sea, _water_mat, Vector3(0, -0.3, 0))
	sea_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea_mi)
	var land := Models.mi(Models.cyl(ISLAND_R + Ground.SAND_REACH, ISLAND_R + Ground.SAND_REACH, 0.02, 96), _ground_mat, Vector3(0, -0.01, 0))
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)
	# Flowers and grass tufts
	var flowers: Array = []
	var tufts: Array = []
	var grass_col := Defs.col(theme["grass"])
	for i in range(520):
		var a2 := _rng.randf() * TAU
		var r2 := _rng.randf_range(7.6, ISLAND_R - 1.0)
		var pos := Vector3(cos(a2) * r2, 0.05, sin(a2) * r2)
		if i % 3 == 0:
			flowers.append([Transform3D(Basis.from_scale(Vector3(1, 0.45, 1)), pos), Defs.col([0xffffff, 0xfff3a0, 0xffb3d1, 0xc9a6ff][i % 4])])
		else:
			var s2 := _rng.randf_range(0.8, 1.5)
			var tc: Color = Defs.col([0x4fa82a, 0x5fbb33, 0x3f9a24][i % 3]).lerp(grass_col, 0.55)
			tufts.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s2), Vector3(pos.x, 0, pos.z)), tc])
	add_child(Models.batch(Models.sphere(0.12, 8), flowers, false, false))
	var tm := Models.batch(Models.grass_tuft(), tufts, false, false)
	(tm.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(tm)

# Contact shade under the plaza and props, and the island's round shoreline.
func _bake_ground() -> void:
	var discs: Array = [Vector3(0, 0, 8.4)]
	for b in _shade:
		discs.append(b)
	var inland := func(x: float, z: float) -> float: return ISLAND_R - Vector2(x, z).length()
	var tex := Ground.bake(inland, [], discs)
	_ground_mat.set_shader_parameter("data", tex)
	_water_mat.set_shader_parameter("data", tex)

func _build_plaza() -> void:
	# Round plaza of chunky stones
	var stones: Array = []
	var grays := [0xe6dcc6, 0xdfd4bd, 0xebe2ce, 0xd8cdb6]
	for ring in range(1, 7):
		var r := ring * 1.05
		var n := int(TAU * r / 1.1)
		for i in range(n):
			var a := (i + ring * 0.5) * TAU / n
			var sz := Vector3(1.0, 0.18, 0.95)
			var b := Basis(Vector3.UP, -a) * Basis.from_scale(sz)
			stones.append([Transform3D(b, Vector3(cos(a) * r, 0.1, sin(a) * r)), Defs.col(grays[(i + ring) % grays.size()])])
	add_child(Models.batch(Models.chamfer_box(0.08), stones))
	add_child(Models.mi(Models.cyl(7.2, 7.2, 0.12, 48), _flat(0xb3a88f), Vector3(0, 0.02, 0)))
	# Fountain shrine in the middle
	add_child(Models.mi(Models.cyl(1.9, 2.1, 0.7, 24), Models.soft(0xb8b4ac), Vector3(0, 0.45, 0)))
	add_child(Models.mi(Models.cyl(1.6, 1.6, 0.1, 24), Models.flat(0x6fd8f5), Vector3(0, 0.82, 0)))
	add_child(Models.mi(Models.cyl(0.35, 0.45, 1.6, 12), Models.soft(0xd9d5ce), Vector3(0, 1.5, 0)))
	add_child(Models.mi(Models.cyl(0.9, 0.9, 0.15, 16), Models.soft(0xb8b4ac), Vector3(0, 2.3, 0)))
	_orb = Node3D.new()
	_orb.position = Vector3(0, 3.1, 0)
	add_child(_orb)
	Models.add(_orb, Models.sphere(0.45, 16), Models.flat(0xffb7d5))
	Models.add(_orb, Models.torus(0.7, 0.05), Models.flat(0xffd34d), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	Models.add(_orb, Models.torus(0.85, 0.04), Models.flat(0xffd34d), Vector3.ZERO, Vector3(0.3, 0, PI / 2))

func _place(scene: PackedScene, pos: Vector3, rot: float, props: Dictionary = {}) -> Node3D:
	var n = scene.instantiate()
	for k in props:
		n.set(k, props[k])
	n.position = pos
	n.rotation.y = rot
	add_child(n)
	_shade.append(Vector3(pos.x, pos.z, maxf(0.8, float(n.get_meta("r", 1.2)) * 0.72)))
	return n

func _build_village() -> void:
	var torii := Models.torii()
	torii.position = Vector3(0, 0, -9.0)
	add_child(torii)
	_place(WindmillScene, Vector3(10.5, 0, -6.5), -0.5)
	_place(HouseScene, Vector3(-9.5, 0, -5.5), 0.45, {"variant": 0})
	_place(HouseScene, Vector3(-14.0, 0, 1.5), 0.9, {"variant": 3})
	_place(HouseScene, Vector3(13.5, 0, 2.0), -0.8, {"variant": 2})
	_place(DecoScene, Vector3(-6.0, 0, -8.0), 0.3, {"kind": "crates"})
	_place(DecoScene, Vector3(7.2, 0, -8.5), 0.0, {"kind": "hay"})
	_place(DecoScene, Vector3(-4.5, 0, 6.0), 0.0, {"kind": "lantern"})
	_place(DecoScene, Vector3(4.5, 0, 6.0), 0.0, {"kind": "lantern"})
	_place(DecoScene, Vector3(9.0, 0, 6.5), 1.2, {"kind": "fence"})
	# Trees around the back and sides, palms on the beach
	var spots := [
		[-18, -10, "round"], [-14, -13, "sakura"], [-6, -15, "round"], [3, -16, "sakura"], [12, -14, "round"],
		[18, -9, "sakura"], [20, -2, "round"], [-20, -3, "round"], [-17, 7, "sakura"], [17, 9, "round"],
		[-3, -13, "round"], [7, -13, "round"],
	]
	for s in spots:
		_place(TreeScene, Vector3(s[0], 0, s[1]), _rng.randf() * TAU, {"kind": s[2], "size": _rng.randf_range(1.1, 1.5), "tree_seed": _rng.randi()})
	for a in [0.4, 0.9, 1.4, 1.9, 2.5, 2.9]:
		_place(PalmScene, Vector3(cos(a) * 26.0, 0, sin(a) * 22.0), _rng.randf() * TAU, {"size": 1.1, "tree_seed": _rng.randi()})
	for p in [[-11, 9], [11, 11], [-21, 12], [22, 13]]:
		_place(BushScene, Vector3(p[0], 0, p[1]), 0.0, {"size": 1.2, "bush_seed": _rng.randi()})
	var petals := Models.drift_particles("petal", Defs.col(0xffc1dc), 60, Vector3(20, 1, 12), 12.0)
	petals.position = Vector3(0, 12, 0)
	petals.lifetime = 10.0
	petals.preprocess = 10.0
	add_child(petals)

## Show the given heroes standing around the plaza.
func set_heroes(keys: Array) -> void:
	for h in heroes:
		(h[0]["root"] as Node3D).queue_free()
	heroes.clear()
	var n := keys.size()
	for i in range(n):
		var m: Dictionary = Models.build_hero(keys[i])
		# Spread along a wide arc in front of the fountain, alternating rows
		var a := PI * 0.06 + (PI * 0.88) * (float(i) / maxf(1.0, n - 1.0))
		var r := 6.2 if i % 2 == 0 else 4.9
		var pos := Vector3(cos(a) * -r, 0.2, sin(a) * r * 0.75 + 0.6)
		var root: Node3D = m["root"]
		root.position = pos
		root.scale = Vector3.ONE * 1.25
		(m["body"] as Node3D).rotation.y = atan2(-pos.x, 18.0 - pos.z)
		add_child(root)
		heroes.append([m, pos, _rng.randf() * TAU, _rng.randf_range(1.0, 5.0)])

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_orb.rotation.y += delta * 0.8
	_orb.position.y = 3.1 + sin(_t * 1.6) * 0.15
	for h in heroes:
		var m: Dictionary = h[0]
		var body: Node3D = m["body"]
		h[3] -= delta
		if h[3] <= 0.0:
			h[3] = _rng.randf_range(2.5, 6.0)
			var tw := create_tween()
			tw.tween_property(body, "position:y", 1.0, 0.18).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(body, "rotation:y", body.rotation.y + TAU, 0.36)
			tw.tween_property(body, "position:y", 0.36, 0.18).set_ease(Tween.EASE_IN)
		else:
			var rarm: Node3D = m["rarm"]
			rarm.rotation.x = -0.9 + sin(_t * 2.0 + h[2]) * 0.25
		for sp in m["spinners"]:
			(sp as Node3D).rotation.y += delta * 2.2
