# Leafy tree (round canopy or sakura) with a trunk collider.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export_enum("round", "sakura", "autumn", "pine", "snowpine", "cactus") var kind := "round"
@export var size := 1.0
@export var tree_seed := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var t: Node3D
	match kind:
		"sakura":
			t = Models.sakura(size, rng)
		"autumn":
			var pal: Array = [[0xd9603a, 0xe98444, 0xf5ab52], [0xd0a83a, 0xe5c04a, 0xf3d96a], [0xc4523e, 0xdc6f44, 0xee9752]][rng.randi() % 3]
			t = Models.round_tree(size, rng, pal, pal[2])
		"pine":
			t = Models.pine(size)
		"snowpine":
			t = Models.snowy_pine(size)
		"cactus":
			t = Models.cactus(size, rng)
		_:
			t = Models.round_tree(size, rng)
	add_child(t)
	Models.collide_cyl(self, 0.45 * size, 2.0 * size, Vector3(0, size, 0))
	set_meta("r", float(t.get_meta("r", 1.6)))
