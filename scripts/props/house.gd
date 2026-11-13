# Small half-timbered cottage with a tiled roof.
# Four variants give the buildings around the track some variety.
extends Node3D

const Models = preload("res://scripts/models.gd")

@export_range(0, 3) var variant := 0

const WALLS := [0xfbeed2, 0xf3dfbc, 0xfaf0dc, 0xefd9b4]
const ROOFS := [0xe8853d, 0xcf5d44, 0xe3ad4a, 0xb4604a]
const BEAM := 0x7a5236

func _ready() -> void:
	var tall := variant == 2
	var w := 4.0 if variant != 3 else 4.8
	var d := 3.4
	var h := 2.2 if not tall else 3.2
	var wall := Models.soft(WALLS[variant])
	var beam := Models.soft(BEAM)
	var glass := Models.flat(0xa9defa)
	var frame := Models.soft(0xfdf8ee)
	var base_y := 0.4

	# Stone footing and walls
	Models.add(self, Models.chamfer_box(0.1), Models.soft(0xa8a297), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(w + 0.5, 0.4, d + 0.5))
	Models.add(self, Models.box(w, h, d), wall, Vector3(0, base_y + h / 2.0, 0))
	# Timber frame: corner posts, sill and belt beams, braces on the front
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Models.add(self, Models.box(0.24, h, 0.24), beam, Vector3(sx * w / 2.0, base_y + h / 2.0, sz * d / 2.0))
	for y in [base_y + 0.1, base_y + h - 0.1]:
		Models.add(self, Models.box(w + 0.1, 0.2, d + 0.1), beam, Vector3(0, y, 0))
	if variant % 2 == 0:
		for sx in [-1.0, 1.0]:
			Models.add(self, Models.box(0.16, h * 0.9, 0.1), beam, Vector3(sx * w * 0.34, base_y + h / 2.0, d / 2.0 + 0.03), Vector3(0, 0, sx * 0.55))
	if tall:
		Models.add(self, Models.box(w + 0.1, 0.18, d + 0.1), beam, Vector3(0, base_y + h * 0.5, 0))

	# Door with a step and a round knob
	var door_x := -w * 0.18 if variant != 1 else 0.0
	Models.add(self, Models.box(1.1, 1.68, 0.1), beam, Vector3(door_x, base_y + 0.84, d / 2.0 + 0.04))
	Models.add(self, Models.box(0.88, 1.5, 0.12), Models.soft(0x9b6a45), Vector3(door_x, base_y + 0.77, d / 2.0 + 0.06))
	Models.add(self, Models.sphere(0.07, 8), Models.soft(0xffd34d), Vector3(door_x + 0.28, base_y + 0.8, d / 2.0 + 0.14))
	Models.add(self, Models.chamfer_box(0.1), Models.soft(0xb9b3a8), Vector3(door_x, 0.12, d / 2.0 + 0.5), Vector3.ZERO, Vector3(1.4, 0.24, 0.6))

	# Windows: white frame, glass, a cross bar; one gets a flower box
	var wins: Array = [Vector2(w * 0.25, h * 0.6)]
	if variant == 3:
		wins.append(Vector2(-w * 0.4, h * 0.6))
	if tall:
		wins = [Vector2(w * 0.25, h * 0.3), Vector2(w * 0.25, h * 0.74), Vector2(-w * 0.22, h * 0.74)]
	for i in range(wins.size()):
		var wp: Vector2 = wins[i]
		var c := Vector3(wp.x, base_y + wp.y, d / 2.0)
		Models.add(self, Models.box(0.86, 0.76, 0.1), frame, c + Vector3(0, 0, 0.03))
		Models.add(self, Models.box(0.68, 0.58, 0.12), glass, c + Vector3(0, 0, 0.04))
		Models.add(self, Models.box(0.06, 0.58, 0.14), frame, c + Vector3(0, 0, 0.04))
		Models.add(self, Models.box(0.68, 0.06, 0.14), frame, c + Vector3(0, 0, 0.04))
		if i == 0:
			Models.add(self, Models.box(0.9, 0.2, 0.26), beam, c + Vector3(0, -0.5, 0.14))
			for k in range(3):
				Models.add(self, Models.sphere(0.13, 8), Models.foliage(0x58b950, 0.0), c + Vector3(-0.28 + k * 0.28, -0.36, 0.16))
				Models.add(self, Models.sphere(0.07, 6), Models.soft([0xff8fc0, 0xfff3a0, 0xffffff][(k + variant) % 3]), c + Vector3(-0.28 + k * 0.28, -0.26, 0.2))
	# A side window on the east wall
	Models.add(self, Models.box(0.1, 0.76, 0.86), frame, Vector3(w / 2.0 + 0.03, base_y + h * 0.6, 0))
	Models.add(self, Models.box(0.12, 0.58, 0.68), glass, Vector3(w / 2.0 + 0.04, base_y + h * 0.6, 0))

	# Roof: a tiled prism with eaves, a ridge beam and trim boards on the gables
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.1, 1.9 if not tall else 2.3, d + 1.0)
	var roof_y := base_y + h + roof.size.y / 2.0
	Models.add(self, roof, Models.roof(ROOFS[variant], 2.6), Vector3(0, roof_y, 0))
	Models.add(self, Models.box(0.26, 0.26, d + 1.15), beam, Vector3(0, roof_y + roof.size.y / 2.0 - 0.02, 0))
	var slope := atan2(roof.size.y, roof.size.x / 2.0)
	var run := Vector2(roof.size.x / 2.0, roof.size.y).length()
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			Models.add(self, Models.box(run + 0.1, 0.16, 0.12), Models.soft(0xfdf8ee), Vector3(sx * roof.size.x / 4.0, roof_y, sz * (roof.size.z / 2.0 + 0.02)), Vector3(0, 0, -sx * slope))
	# Chimney, or a barrel and a hay bale beside the house
	if variant != 1:
		Models.add(self, Models.chamfer_box(0.1), Models.soft(0xa39d93), Vector3(w * 0.28, roof_y + 0.45, -d * 0.15), Vector3.ZERO, Vector3(0.6, 1.5, 0.6))
		Models.add(self, Models.chamfer_box(0.1), Models.soft(0x8f897f), Vector3(w * 0.28, roof_y + 1.22, -d * 0.15), Vector3.ZERO, Vector3(0.76, 0.2, 0.76))
	else:
		Models.add(self, Models.cyl(0.45, 0.45, 0.9, 14), Models.soft(0x96623a), Vector3(w / 2.0 + 0.8, 0.45, d * 0.25))
		for y in [0.2, 0.7]:
			Models.add(self, Models.cyl(0.47, 0.47, 0.08, 14), Models.soft(0x5f4a3a), Vector3(w / 2.0 + 0.8, y, d * 0.25))
		Models.add(self, Models.cyl(0.5, 0.5, 0.8, 14), Models.soft(0xedcb6a), Vector3(w / 2.0 + 0.9, 0.5, -d * 0.2), Vector3(PI / 2, 0, 0))
	Models.collide_box(self, Vector3(w + 0.5, h + 2.0, d + 0.5), Vector3(0, (h + 2.0) / 2.0, 0))
	set_meta("r", maxf(w, d) * 0.62 + 0.4)
