# One grid cell of stone track (CELL x CELL world units).
# "straight" is open to the north (-Z) and south (+Z); "corner" is open to the north and east (+X).
# The Track rotates tiles in 90-degree steps to fit the route.
extends Node3D

const Models = preload("res://scripts/models.gd")
const BarrierScene = preload("res://scenes/track/stone_barrier.tscn")

const CELL := 4.0
const WALL := 0.6            # barrier thickness
const STONE_ROW := 1.0       # depth of one row of floor stones
const GAP := 0.07            # visible joint between stones
const GRAYS := [0xe6dcc6, 0xdfd4bd, 0xebe2ce, 0xe2d8c2]   # close shades of warm stone
const GROUT := 0xb3a88f

@export_enum("straight", "corner") var piece := "straight"
@export var stone_seed := 0
## When false, the parent Track batches all stones into a couple of draw calls.
@export var standalone := true

var stones: Array = []   # floor + barrier stones: [[Transform3D, Color], ...] in tile space
var grout: Array = []    # dark slabs under the stones

func open_sides() -> Array:
	return ["N", "S"] if piece == "straight" else ["N", "E"]

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var open := open_sides()
	var half := CELL / 2.0
	var inner := half - WALL
	var x_min := -half if open.has("W") else -inner
	var x_max := half if open.has("E") else inner
	var z_min := -half if open.has("N") else -inner
	var z_max := half if open.has("S") else inner

	# Grout slab: whole cell, so neighbouring tiles join seamlessly.
	var gb := Basis.from_scale(Vector3(CELL, 0.14, CELL))
	grout.append([Transform3D(gb, Vector3(0, 0.07, 0)), Models.toon(GROUT).albedo_color])

	# Floor: even pavers in a running bond (every other row is shifted half a stone).
	var z := -half
	var row := 0
	while z < half - 0.001:
		var z0 := maxf(z, z_min)
		var z1 := minf(z + STONE_ROW, z_max)
		z += STONE_ROW
		row += 1
		if z1 - z0 < 0.2:
			continue
		var span := x_max - x_min
		var n := maxi(1, int(round(span / 0.95)))
		var w := span / n
		# Stone edges for this row; odd rows start with a half stone
		var edges: Array = [x_min]
		var shift := (row % 2 == 1)
		for k in range(n):
			edges.append(x_min + w * (k + (0.5 if shift else 1.0)))
		if shift:
			edges.append(x_max)
		for k in range(edges.size() - 1):
			var x0: float = edges[k]
			var x1: float = minf(edges[k + 1], x_max)
			if x1 - x0 < 0.05:
				continue
			var size := Vector3((x1 - x0) - GAP, 0.16, (z1 - z0) - GAP)
			var pos := Vector3((x0 + x1) / 2.0, 0.13 + 0.08 - 0.02, (z0 + z1) / 2.0)
			stones.append([Transform3D(Basis.from_scale(size), pos), Models.toon(GRAYS[rng.randi() % GRAYS.size()]).albedo_color])

	# Barriers on closed sides. Side walls (E/W) run full length; N/S walls stop where they meet them.
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	for side in ["N", "S", "E", "W"]:
		if open.has(side):
			continue
		var bar = BarrierScene.instantiate()
		bar.standalone = false
		bar.stone_seed = rng.randi()
		if side == "N" or side == "S":
			var left := -half + (WALL if not open.has("W") else 0.0)
			var right := half - (WALL if not open.has("E") else 0.0)
			bar.length = right - left
			bar.position = Vector3((left + right) / 2.0, 0, -inner - WALL / 2.0 if side == "N" else inner + WALL / 2.0)
		else:
			bar.length = CELL
			bar.position = Vector3(inner + WALL / 2.0 if side == "E" else -inner - WALL / 2.0, 0, 0)
			bar.rotation.y = PI / 2.0
		bar.name = "Barrier" + side
		add_child(bar)
		for s in bar.stones:
			stones.append([bar.transform * (s[0] as Transform3D), s[1]])

	# Inner corner post closes the gap where the two neighbouring walls meet.
	if piece == "corner":
		var post_pos := Vector3(inner + WALL / 2.0, 0, -inner - WALL / 2.0)
		var ph := 0.52
		var pb := Basis.from_scale(Vector3(WALL + 0.04, ph, WALL + 0.04))
		stones.append([Transform3D(pb, post_pos + Vector3(0, 0.12 + ph / 2.0, 0)), Models.toon(0xc2b69c).albedo_color])
		var post_shape := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = Vector3(WALL, 0.7, WALL)
		post_shape.shape = pbox
		post_shape.position = post_pos + Vector3(0, 0.47, 0)
		body.add_child(post_shape)

	# Walkable floor collision covering the whole cell (flush with neighbours).
	var floor_shape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(CELL, 0.3, CELL)
	floor_shape.shape = fbox
	floor_shape.position = Vector3(0, 0.07, 0)
	body.add_child(floor_shape)

	if standalone:
		add_child(Models.batch(Models.chamfer_box(0.08), stones))
		add_child(Models.batch(Models.box(1, 1, 1), grout, false, false))
