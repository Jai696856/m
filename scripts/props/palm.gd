# Beach palm tree.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export var size := 1.0
@export var tree_seed := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	add_child(Models.palm(size, rng))
	Models.collide_cyl(self, 0.35 * size, 3.0 * size, Vector3(0, 1.5 * size, 0))
	set_meta("r", 1.0 * size)
