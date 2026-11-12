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

var camera: Camera3D
var heroes: Array = []   # [model dict, base position, phase, hop timer]
var _orb: Node3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 77
	_build_ground()
	_build_plaza()
	_build_village()
	camera = Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.position = Vector3(0, 12.5, 21.0)
	camera.look_at(global_position + Vector3(0, 1.6, -1.0), Vector3.UP)

func _flat(hex: int) -> StandardMaterial3D:
	var m := Models.make_toon(Defs.col(hex), false)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_ground() -> void:
	var sea := PlaneMesh.new()
	sea.size = Vector2(400, 400)
	add_child(Models.mi(sea, _flat(0x1f9ad6), Vector3(0, -0.45, 0)))
	add_child(Models.mi(Models.cyl(34.0, 34.0, 0.1, 64), _flat(0x5fd0ef), Vector3(0, -0.38, 0)))
	add_child(Models.mi(Models.cyl(29.0, 29.0, 0.1, 64), _flat(0xeafcff), Vector3(0, -0.33, 0)))
	add_child(Models.mi(Models.cyl(28.0, 28.5, 0.3, 64), _flat(0xf5df9e), Vector3(0, -0.2, 0)))
	add_child(Models.mi(Models.cyl(24.5, 24.5, 0.12, 64), _flat(0x86d040), Vector3(0, -0.06, 0)))
	# grass patches and flowers
	var patches: Array = []
	var flowers: Array = []
	for i in range(30):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(8.0, 22.0)
		var s := _rng.randf_range(1.5, 3.5)
		patches.append([Transform3D(Basis.from_scale(Vector3(s, 1, s * 0.7)), Vector3(cos(a) * r, 0.01, sin(a) * r)), Defs.col([0x74c234, 0x97da4f, 0xa3e05a][i % 3])])
	for i in range(500):
		var a2 := _rng.randf() * TAU
		var r2 := _rng.randf_range(7.5, 23.5)
		flowers.append([Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)), Vector3(cos(a2) * r2, 0.06, sin(a2) * r2)), Defs.col([0xffffff, 0xfff3a0, 0xffb3d1, 0xc9a6ff][i % 4])])
	add_child(Models.batch(Models.cyl(1.0, 1.0, 0.02, 16), patches, false, false))
	add_child(Models.batch(Models.sphere(0.13, 6), flowers, false, false))

func _build_plaza() -> void:
	# Round plaza of chunky stones
	var stones: Array = []
	var grays := [0xc8c6c0, 0xb2b0ab, 0xbdbbb5, 0xa3a29e]
	for ring in range(1, 7):
		var r := ring * 1.05
		var n := int(TAU * r / 1.1)
		for i in range(n):
			var a := (i + ring * 0.5) * TAU / n
			var sz := Vector3(1.0, 0.18, 0.95)
			var b := Basis(Vector3.UP, -a) * Basis.from_scale(sz)
			stones.append([Transform3D(b, Vector3(cos(a) * r, 0.1, sin(a) * r)), Defs.col(grays[(i + ring) % grays.size()])])
	add_child(Models.batch(Models.chamfer_box(0.12), stones))
	add_child(Models.mi(Models.cyl(7.2, 7.2, 0.12, 48), _flat(0x6f6a62), Vector3(0, 0.02, 0)))
	# Fountain shrine in the middle
	add_child(Models.mi(Models.cyl(1.9, 2.1, 0.7, 24), Models.toon(0xb8b4ac), Vector3(0, 0.45, 0)))
	add_child(Models.mi(Models.cyl(1.6, 1.6, 0.1, 24), Models.flat(0x6fd8f5), Vector3(0, 0.82, 0)))
	add_child(Models.mi(Models.cyl(0.35, 0.45, 1.6, 12), Models.toon(0xd9d5ce), Vector3(0, 1.5, 0)))
	add_child(Models.mi(Models.cyl(0.9, 0.9, 0.15, 16), Models.toon(0xb8b4ac), Vector3(0, 2.3, 0)))
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
	var petals := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.2)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Defs.col(0xffc1dc)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = pm
	petals.mesh = quad
	petals.amount = 50
	petals.lifetime = 10.0
	petals.preprocess = 10.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(20, 1, 12)
	petals.position = Vector3(0, 12, 0)
	petals.direction = Vector3(1, -0.4, 0.2)
	petals.gravity = Vector3(0, -0.6, 0)
	petals.initial_velocity_min = 0.6
	petals.initial_velocity_max = 1.4
	add_child(petals)

## Show the given heroes standing around the plaza.
func set_heroes(keys: Array) -> void:
	for h in heroes:
		(h[0]["root"] as Node3D).queue_free()
	heroes.clear()
	var n := keys.size()
	for i in range(n):
		var m: Dictionary = Models.build_hero(keys[i])
		var a := PI * 0.15 + (PI * 0.7) * (float(i) / maxf(1.0, n - 1.0))
		var pos := Vector3(cos(a) * -4.6, 0.12, sin(a) * 4.0 + 0.5)
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
