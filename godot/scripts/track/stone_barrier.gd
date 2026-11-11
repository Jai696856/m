# A low wall of chunky stones, running along the local X axis.
# Used on every closed side of a track tile.
extends Node3D

const Models = preload("res://scripts/models.gd")

const THICKNESS := 0.6
const BASE_Y := 0.12
const GRAYS := [0x8b8a86, 0x7f7e7a, 0x979692, 0x74736f, 0xa09f9a]

@export var length := 4.0
@export var stone_seed := 0
## When false, the parent Track batches the stones into one draw call.
@export var standalone := true

# [[Transform3D, Color], ...] in this node's local space
var stones: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var x := -length / 2.0
	var gap := 0.06
	while x < length / 2.0 - 0.05:
		var w := rng.randf_range(0.75, 1.3)
		if length / 2.0 - (x + w) < 0.45:
			w = length / 2.0 - x
		var hgt := rng.randf_range(0.42, 0.56)
		var size := Vector3(w - gap, hgt, THICKNESS - rng.randf_range(0.0, 0.08))
		var b := Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)) * Basis.from_scale(size)
		var pos := Vector3(x + w / 2.0, BASE_Y + hgt / 2.0, rng.randf_range(-0.025, 0.025))
		stones.append([Transform3D(b, pos), Models.toon(GRAYS[rng.randi() % GRAYS.size()]).albedo_color])
		x += w

	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.6, THICKNESS)
	shape.shape = box
	shape.position = Vector3(0, BASE_Y + 0.3, 0)
	body.add_child(shape)
	add_child(body)

	if standalone:
		add_child(Models.batch(Models.chamfer_box(0.12), stones))
