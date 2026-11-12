# Small props: stone lantern, wooden crate stack, hay bale, fence.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export_enum("lantern", "crates", "hay", "fence") var kind := "crates"

func _ready() -> void:
	match kind:
		"lantern":
			add_child(Models.lantern())
			Models.collide_cyl(self, 0.5, 2.4, Vector3(0, 1.2, 0))
			set_meta("r", 0.9)
		"crates":
			add_child(Models.crate())
			var top := Models.crate()
			top.position = Vector3(0.2, 1.1, 0.1)
			top.rotation.y = 0.4
			top.scale = Vector3.ONE * 0.8
			add_child(top)
			Models.collide_box(self, Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0))
			set_meta("r", 1.0)
		"hay":
			Models.add(self, Models.cyl(0.7, 0.7, 1.1, 14), Models.toon(0xe8c463), Vector3(0, 0.7, 0), Vector3(PI / 2, 0, 0))
			Models.collide_cyl(self, 0.75, 1.4, Vector3(0, 0.7, 0))
			set_meta("r", 0.9)
		"fence":
			var wood := Models.toon(0x9b6a3a)
			for i in range(4):
				Models.add(self, Models.box(0.18, 0.9, 0.18), wood, Vector3(i * 1.0 - 1.5, 0.45, 0))
			for y in [0.35, 0.7]:
				Models.add(self, Models.box(3.3, 0.12, 0.1), wood, Vector3(0, y, 0))
			Models.collide_box(self, Vector3(3.4, 1.0, 0.3), Vector3(0, 0.5, 0))
			set_meta("r", 1.8)
