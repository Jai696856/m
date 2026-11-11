# Leafy tree (round canopy or sakura) with a trunk collider.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export_enum("round", "sakura") var kind := "round"
@export var size := 1.0
@export var tree_seed := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var t: Node3D = Models.round_tree(size, rng) if kind == "round" else Models.sakura(size, rng)
	add_child(t)
	Models.collide_cyl(self, 0.45 * size, 2.0 * size, Vector3(0, size, 0))
	set_meta("r", float(t.get_meta("r", 1.6)))
