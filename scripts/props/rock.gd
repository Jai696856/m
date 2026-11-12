# Grey boulder pair.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export var size := 1.0

func _ready() -> void:
	add_child(Models.rock(size))
	Models.collide_cyl(self, 1.1 * size, 1.0 * size, Vector3(0, 0.5 * size, 0))
	set_meta("r", 1.3 * size)
