# Low round bush.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export var size := 1.0
@export var bush_seed := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bush_seed
	add_child(Models.bush(size, rng))
	Models.collide_cyl(self, 0.9 * size, 1.0 * size, Vector3(0, 0.5 * size, 0))
	set_meta("r", 1.2 * size)
