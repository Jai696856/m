# Small wooden medieval cottage (half-timbered walls, steep roof).
# Four variants give the four buildings around the track some variety.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export_range(0, 3) var variant := 0

const WALLS := [0xf2e2bf, 0xc98b4f, 0xeedbb4, 0xb7804a]
const ROOFS := [0xe07b2c, 0xb84a30, 0xd9a03a, 0x8c4a2f]
const BEAM := 0x6b4426

func _ready() -> void:
	var tall := variant == 2
	var w := 4.0 if variant != 3 else 4.8
	var d := 3.4
	var h := 2.2 if not tall else 3.2
	var wall := Models.toon(WALLS[variant])
	var beam := Models.toon(BEAM)
	var stone := Models.chamfer_box(0.1)

	Models.add(self, stone, Models.toon(0x9a958c), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(w + 0.5, 0.44, d + 0.5))
	Models.add(self, Models.box(w, h, d), wall, Vector3(0, 0.44 + h / 2.0, 0))
	# Timber frame: corner posts, sill and belt beams, braces on the front
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Models.add(self, Models.box(0.26, h, 0.26), beam, Vector3(sx * w / 2.0, 0.44 + h / 2.0, sz * d / 2.0))
	for y in [0.55, 0.44 + h - 0.1]:
		Models.add(self, Models.box(w + 0.1, 0.2, d + 0.1), beam, Vector3(0, y, 0))
	if variant % 2 == 0:
		for sx in [-1.0, 1.0]:
			Models.add(self, Models.box(0.18, h * 0.9, 0.12), beam, Vector3(sx * w * 0.32, 0.44 + h / 2.0, d / 2.0 + 0.04), Vector3(0, 0, sx * 0.55))
	# Door and windows on the front (+Z)
	Models.add(self, Models.box(0.95, 1.55, 0.12), Models.toon(0x5a3a22), Vector3(-w * 0.18 if variant != 1 else 0.0, 0.44 + 0.78, d / 2.0 + 0.06))
	Models.add(self, Models.box(0.12, 0.12, 0.1), Models.toon(0xffd34d, 1.0, false), Vector3((-w * 0.18 if variant != 1 else 0.0) + 0.3, 0.44 + 0.8, d / 2.0 + 0.14))
	for wx in [w * 0.25, -w * 0.4] if variant == 3 else [w * 0.25]:
		Models.add(self, Models.box(0.8, 0.7, 0.1), Models.toon(0x5a3a22), Vector3(wx, 0.44 + h * 0.6, d / 2.0 + 0.05))
		Models.add(self, Models.box(0.62, 0.52, 0.12), Models.flat(0x9fd8ff), Vector3(wx, 0.44 + h * 0.6, d / 2.0 + 0.06))
	if tall:
		Models.add(self, Models.box(0.8, 0.7, 0.1), Models.toon(0x5a3a22), Vector3(w * 0.25, 0.44 + h * 0.3, d / 2.0 + 0.05))
	# Roof: a triangular prism with overhanging eaves, ridge along Z
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.0, 1.9 if not tall else 2.3, d + 0.9)
	var roof_y := 0.44 + h + roof.size.y / 2.0
	Models.add(self, roof, Models.toon(ROOFS[variant]), Vector3(0, roof_y, 0))
	Models.add(self, Models.box(0.3, 0.3, d + 1.0), beam, Vector3(0, roof_y + roof.size.y / 2.0, 0))
	# Chimney or a hay bale / barrel beside the house
	if variant != 1:
		Models.add(self, stone, Models.toon(0x8f8a82), Vector3(w * 0.28, roof_y + 0.5, -d * 0.15), Vector3.ZERO, Vector3(0.6, 1.6, 0.6))
	else:
		Models.add(self, Models.cyl(0.45, 0.45, 0.9, 12), Models.toon(0x8a5427), Vector3(w / 2.0 + 0.8, 0.45, d * 0.25))
		Models.add(self, Models.cyl(0.5, 0.5, 0.8, 12), Models.toon(0xe8c463), Vector3(w / 2.0 + 0.9, 0.4, -d * 0.2), Vector3(PI / 2, 0, 0))
	Models.collide_box(self, Vector3(w + 0.5, h + 2.0, d + 0.5), Vector3(0, (h + 2.0) / 2.0, 0))
	set_meta("r", maxf(w, d) * 0.62 + 0.4)
