# Wooden windmill with turning sails.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export var sail_speed := 0.6

var hub: Node3D

func _ready() -> void:
	var wood := Models.toon(0xb07a45)
	var dark := Models.toon(0x6b4426)
	Models.add(self, Models.chamfer_box(0.12), Models.toon(0x9a958c), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(3.8, 0.5, 3.8))
	Models.add(self, Models.cyl(1.35, 1.85, 4.6, 8), wood, Vector3(0, 0.5 + 2.3, 0))
	for y in [1.4, 2.8, 4.2]:
		Models.add(self, Models.cyl(1.9 - y * 0.11, 1.9 - y * 0.11, 0.16, 8), dark, Vector3(0, 0.5 + y, 0))
	Models.add(self, Models.box(0.9, 1.5, 0.12), dark, Vector3(0, 1.25, 1.8), Vector3(-0.1, 0, 0))
	Models.add(self, Models.box(0.6, 0.6, 0.1), Models.flat(0x9fd8ff), Vector3(0, 3.6, 1.55), Vector3(-0.1, 0, 0))
	Models.add(self, Models.cone(1.75, 1.8, 8), Models.toon(0x9b3d2a), Vector3(0, 5.1 + 0.9, 0))
	# Sails: hub on the front, four arms with cloth panels
	hub = Node3D.new()
	hub.position = Vector3(0, 5.0, 1.85)
	add_child(hub)
	Models.add(hub, Models.cyl(0.3, 0.3, 0.5, 10), dark, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in range(4):
		var arm := Node3D.new()
		arm.rotation.z = i * PI / 2.0 + 0.4
		hub.add_child(arm)
		Models.add(arm, Models.box(0.16, 3.4, 0.12), dark, Vector3(0, 1.85, 0.2))
		Models.add(arm, Models.box(0.9, 2.5, 0.05), Models.toon(0xf4ead2), Vector3(0.5, 2.1, 0.22))
		for k in range(3):
			Models.add(arm, Models.box(0.95, 0.06, 0.08), dark, Vector3(0.5, 1.2 + k * 0.9, 0.24))
	Models.collide_cyl(self, 1.9, 6.0, Vector3(0, 3.0, 0))
	set_meta("r", 2.4)
	add_to_group("no_batch")

func _process(delta: float) -> void:
	hub.rotation.z += delta * sail_speed
