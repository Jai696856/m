# The Track scene: lays out modular stone tiles on a grid from a list of
# waypoints, validates that the route is one connected corridor, batches all
# stones into a few draw calls, and exposes the centre line for spirits.
extends Node3D

const Models = preload("res://scripts/models.gd")
const StraightScene = preload("res://scenes/track/track_straight.tscn")
const CornerScene = preload("res://scenes/track/track_corner.tscn")

const CELL := 4.0
## World position of the centre of grid cell (0, 0).
const ORIGIN := Vector2(-30.0, -16.0)

## Route as grid waypoints. Consecutive waypoints share a row or a column.
## The first and last waypoints lie just outside the tiled area (entry and exit).
## Default route (the original "Sakura Shore" map). The Level overrides `route`
## before the Track enters the scene tree; every map in scripts/maps.gd has one.
const ROUTE := [
	Vector2i(3, -2), Vector2i(3, 1), Vector2i(10, 1), Vector2i(10, 3), Vector2i(6, 3),
	Vector2i(6, 5), Vector2i(2, 5), Vector2i(2, 7), Vector2i(8, 7), Vector2i(8, 5),
	Vector2i(12, 5), Vector2i(12, 3), Vector2i(14, 3), Vector2i(14, 7), Vector2i(11, 7),
	Vector2i(11, 8),
]

var route: Array = ROUTE
## Colour multiplier for the stones (warm sandstone in the desert, cool blue-grey in snow...).
var stone_tint := Color.WHITE

const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}

## Every grid cell along the route, entry and exit included.
var cells: Array[Vector2i] = []
var tiles: Array[Node3D] = []

func _ready() -> void:
	_expand_route()
	if not validate():
		push_error("Track route is invalid; see errors above.")
	_build_tiles()

static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(ORIGIN.x + c.x * CELL, 0.0, ORIGIN.y + c.y * CELL)

func _expand_route() -> void:
	cells.clear()
	cells.append(route[0])
	for i in range(1, route.size()):
		var a: Vector2i = route[i - 1]
		var b: Vector2i = route[i]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		while c != b:
			c += step
			cells.append(c)

# Checks: axis-aligned waypoints, every step moves to a 4-neighbour, no cell is
# used twice, and no two non-consecutive cells touch (so the corridor never merges).
func validate() -> bool:
	var ok := true
	for i in range(1, route.size()):
		var a: Vector2i = route[i - 1]
		var b: Vector2i = route[i]
		if a.x != b.x and a.y != b.y:
			push_error("Track: waypoints %s -> %s are not in one row or column" % [a, b])
			ok = false
	var index := {}
	for i in range(cells.size()):
		var c := cells[i]
		if index.has(c):
			push_error("Track: cell %s is used twice" % c)
			ok = false
		index[c] = i
		if i > 0 and (cells[i] - cells[i - 1]).length_squared() != 1:
			push_error("Track: gap between %s and %s" % [cells[i - 1], cells[i]])
			ok = false
	for i in range(cells.size()):
		for d in DIRS.values():
			var n: Vector2i = cells[i] + d
			if index.has(n) and absi(int(index[n]) - i) > 1:
				push_error("Track: cells %s and %s touch but are not connected" % [cells[i], n])
				ok = false
	return ok

func _side_toward(from: Vector2i, to: Vector2i) -> String:
	for k in DIRS:
		if DIRS[k] == to - from:
			return k
	return ""

# Rotation (in -90 degree steps, clockwise seen from above) mapping N->E->S->W.
const CW := ["N", "E", "S", "W"]

func _rotate_side(side: String, steps: int) -> String:
	return CW[(CW.find(side) + steps) % 4]

func _build_tiles() -> void:
	var stone_items: Array = []
	var grout_items: Array = []
	# Tiles cover every cell except the entry and exit points.
	for i in range(1, cells.size() - 1):
		var c := cells[i]
		var a := _side_toward(c, cells[i - 1])
		var b := _side_toward(c, cells[i + 1])
		var straight := (a == "N" and b == "S") or (a == "S" and b == "N") or (a == "E" and b == "W") or (a == "W" and b == "E")
		var tile = (StraightScene if straight else CornerScene).instantiate()
		tile.standalone = false
		tile.stone_seed = c.x * 73856093 ^ c.y * 19349663
		var base: Array = ["N", "S"] if straight else ["N", "E"]
		var steps := 0
		for k in range(4):
			var r0 := _rotate_side(base[0], k)
			var r1 := _rotate_side(base[1], k)
			if (r0 == a and r1 == b) or (r0 == b and r1 == a):
				steps = k
				break
		tile.name = "Tile_%d_%d" % [c.x, c.y]
		tile.position = cell_to_world(c)
		tile.rotation.y = -PI / 2.0 * steps
		add_child(tile)
		tiles.append(tile)
		var xf: Transform3D = tile.transform
		for s in tile.stones:
			stone_items.append([xf * (s[0] as Transform3D), (s[1] as Color) * stone_tint])
		for g in tile.grout:
			grout_items.append([xf * (g[0] as Transform3D), g[1]])
	var stones_mm := Models.batch(Models.chamfer_box(0.12), stone_items)
	stones_mm.name = "Stones"
	add_child(stones_mm)
	var grout_mm := Models.batch(Models.box(1, 1, 1), grout_items, false, false)
	grout_mm.name = "Grout"
	add_child(grout_mm)

## Centre line for spirits: entry, every corner, exit (world space, y = 0).
func get_path_points() -> Array:
	var pts: Array = []
	for w in route:
		pts.append(cell_to_world(w))
	return pts

## Grid helpers for other systems (placement, props).
func is_track_cell(c: Vector2i) -> bool:
	return cells.has(c)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - ORIGIN.x) / CELL), roundi((p.z - ORIGIN.y) / CELL))
