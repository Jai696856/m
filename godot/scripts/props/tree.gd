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
			var pal: Array = [[0xd9542b, 0xe8792f, 0xf2a03a], [0xc9a227, 0xe0b93a, 0xf0d257], [0xb8432f, 0xd4612e, 0xe98a3c]][rng.randi() % 3]
			t = Models.round_tree(size, rng, pal, 0xf7c35a)
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
