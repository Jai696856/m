# Wooden windmill with turning sails.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export var sail_speed := 0.6

var hub: Node3D

func _ready() -> void:
	var wall := Models.soft(0xfbeed2)
	var dark := Models.soft(0x7a5236)
	Models.add(self, Models.chamfer_box(0.1), Models.soft(0xa8a297), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(3.9, 0.44, 3.9))
	# Tapered round tower with timber bands
	Models.add(self, Models.cyl(1.3, 1.85, 4.6, 16), wall, Vector3(0, 0.44 + 2.3, 0))
	for y in [0.2, 2.2, 4.4]:
		var r: float = 1.87 - y * 0.12
		Models.add(self, Models.cyl(r, r + 0.02, 0.2, 16), dark, Vector3(0, 0.5 + y, 0))
	# Door and a round window
	Models.add(self, Models.box(0.95, 1.6, 0.14), dark, Vector3(0, 1.25, 1.78), Vector3(-0.12, 0, 0))
	Models.add(self, Models.box(0.74, 1.4, 0.16), Models.soft(0x9b6a45), Vector3(0, 1.2, 1.8), Vector3(-0.12, 0, 0))
	Models.add(self, Models.cyl(0.36, 0.36, 0.12, 16), Models.soft(0xfdf8ee), Vector3(0, 3.5, 1.5), Vector3(PI / 2 - 0.12, 0, 0))
	Models.add(self, Models.cyl(0.26, 0.26, 0.14, 16), Models.flat(0xa9defa), Vector3(0, 3.5, 1.52), Vector3(PI / 2 - 0.12, 0, 0))
	# Tiled cap
	Models.add(self, Models.cone(1.8, 1.9, 16), Models.roof(0xcf5d44, 2.8), Vector3(0, 5.04 + 0.95, 0))
	Models.add(self, Models.sphere(0.16, 10), Models.soft(0xffd34d), Vector3(0, 7.0, 0))
	# Sails: hub on the front, four arms with cloth panels
	hub = Node3D.new()
	hub.position = Vector3(0, 5.0, 1.85)
	add_child(hub)
	Models.add(hub, Models.cyl(0.3, 0.3, 0.5, 12), dark, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	Models.add(hub, Models.sphere(0.2, 10), Models.soft(0xffd34d), Vector3(0, 0, 0.3))
	for i in range(4):
		var arm := Node3D.new()
		arm.rotation.z = i * PI / 2.0 + 0.4
		hub.add_child(arm)
		Models.add(arm, Models.box(0.16, 3.5, 0.12), dark, Vector3(0, 1.9, 0.2))
		Models.add(arm, Models.box(0.92, 2.5, 0.05), Models.soft(0xfdf6e6), Vector3(0.5, 2.15, 0.22))
		for k in range(4):
			Models.add(arm, Models.box(0.96, 0.06, 0.08), dark, Vector3(0.5, 0.95 + k * 0.8, 0.24))
		Models.add(arm, Models.box(0.06, 2.5, 0.08), dark, Vector3(0.96, 2.15, 0.24))
	Models.collide_cyl(self, 1.9, 6.0, Vector3(0, 3.0, 0))
	set_meta("r", 2.4)
	add_to_group("no_batch")

func _process(delta: float) -> void:
	hub.rotation.z += delta * sail_speed
