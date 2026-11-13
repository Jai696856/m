# A low wall of chunky stones, running along the local X axis.
# Used on every closed side of a track tile.
extends Node3D

const Models = preload("res://scripts/models.gd")

const THICKNESS := 0.6
const BASE_Y := 0.12
const GRAYS := [0xcabfa6, 0xc2b79e, 0xd0c6ae]

@export var length := 4.0
@export var stone_seed := 0
## When false, the parent Track batches the stones into one draw call.
@export var standalone := true

# [[Transform3D, Color], ...] in this node's local space
var stones: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	# Even blocks of one height, so the wall reads as a tidy curb
	var n := maxi(1, int(round(length / 1.0)))
	var w := length / n
	var gap := 0.05
	for k in range(n):
		var size := Vector3(w - gap, 0.44, THICKNESS - 0.04)
		var pos := Vector3(-length / 2.0 + w * (k + 0.5), BASE_Y + 0.22, 0)
		stones.append([Transform3D(Basis.from_scale(size), pos), Models.toon(GRAYS[rng.randi() % GRAYS.size()]).albedo_color])

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
		add_child(Models.batch(Models.chamfer_box(0.08), stones))
