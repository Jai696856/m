extends Node3D
## Spinning pickups: cash, health, armour and SMG ammo. Fixed ones respawn.

const Util := preload("res://scripts/util.gd")

const COLORS := {"cash": Color(0.3, 0.95, 0.4), "health": Color(1.0, 0.3, 0.3), "armor": Color(0.35, 0.6, 1.0), "smg": Color(1.0, 0.8, 0.3)}

var game
var items: Array = []   # {node, kind, amount, pos, respawn, wait}
var t := 0.0


func setup(g) -> void:
	game = g
	name = "Pickups"
	for s in game.city.pickup_spots:
		var amount := 0
		match s[0]:
			"cash": amount = game.rng.randi_range(40, 150)
			"smg": amount = 120
		spawn(s[0], s[1], amount, 60.0)


func _model(kind: String) -> Node3D:
	var n := Node3D.new()
	var parts := []
	match kind:
		"cash":
			parts = [[Util.box(0.5, 0.18, 0.28), Util.xf(Vector3.ZERO), Color(0.3, 0.75, 0.35)],
				[Util.box(0.52, 0.19, 0.08), Util.xf(Vector3.ZERO), Color(0.95, 0.95, 0.85)]]
		"health":
			parts = [[Util.box(0.5, 0.16, 0.16), Util.xf(Vector3.ZERO), Color(1, 0.2, 0.2)],
				[Util.box(0.16, 0.5, 0.16), Util.xf(Vector3.ZERO), Color(1, 0.2, 0.2)]]
		"armor":
			parts = [[Util.box(0.45, 0.5, 0.15), Util.xf(Vector3.ZERO), Color(0.25, 0.4, 0.75)],
				[Util.box(0.3, 0.1, 0.17), Util.xf(Vector3(0, 0.12, 0)), Color(0.9, 0.9, 0.9)]]
		_:
			parts = [[Util.box(0.12, 0.14, 0.55), Util.xf(Vector3.ZERO), Color(0.15, 0.15, 0.16)],
				[Util.box(0.1, 0.3, 0.1), Util.xf(Vector3(0, -0.15, 0.08)), Color(0.15, 0.15, 0.16)],
				[Util.box(0.08, 0.22, 0.1), Util.xf(Vector3(0, -0.12, -0.12)), Color(0.4, 0.3, 0.2)]]
	var mi := MeshInstance3D.new()
	mi.mesh = Util.merge(parts)
	mi.material_override = Util.vc_mat(0.4)
	mi.position.y = 0.8
	mi.name = "Mesh"
	n.add_child(mi)
	var ring := MeshInstance3D.new()
	ring.mesh = Util.cyl(0.55, 0.55, 0.03, 16)
	var c: Color = COLORS.get(kind, Color.WHITE)
	ring.material_override = Util.fade_mat(Color(c.r * 2.0, c.g * 2.0, c.b * 2.0, 0.6))
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	return n


func spawn(kind: String, pos: Vector3, amount := 0, respawn := -1.0) -> void:
	var n := _model(kind)
	add_child(n)
	n.global_position = pos
	items.append({"node": n, "kind": kind, "amount": amount, "pos": pos, "respawn": respawn, "wait": 0.0})


func _process(delta: float) -> void:
	t += delta
	var p = game.player
	var pp: Vector3 = game.player_pos()
	var k := 0
	while k < items.size():
		var it: Dictionary = items[k]
		var n: Node3D = it.node
		if not n.visible:
			it.wait -= delta
			if it.wait <= 0.0:
				n.visible = true
			k += 1
			continue
		var mesh: Node3D = n.get_node("Mesh")
		mesh.rotation.y = t * 2.0
		mesh.position.y = 0.8 + sin(t * 3.0 + k) * 0.1
		var r := 3.0 if p.in_car else 1.4
		if not p.dead and game.state == "play" and pp.distance_to(it.pos) < r and _collect(it):
			game.sfx.play("pickup", null, -4.0)
			if it.respawn > 0.0:
				n.visible = false
				it.wait = it.respawn
			else:
				n.queue_free()
				items.remove_at(k)
				continue
		k += 1


func _collect(it: Dictionary) -> bool:
	var p = game.player
	match it.kind:
		"cash":
			var amt: int = it.amount if it.amount > 0 else game.rng.randi_range(20, 80)
			game.add_money(amt)
		"health":
			if p.health >= 100.0:
				return false
			p.heal(100.0)
			game.hud.notice("Health restored")
		"armor":
			if p.armor >= 100.0:
				return false
			p.armor = 100.0
			game.hud.notice("Body armour")
		"smg":
			if p.in_car:
				return false
			p.weapons[1].ammo = maxi(p.weapons[1].ammo, 0) + (it.amount if it.amount > 0 else 60)
			p.weapon = 1
			game.hud.notice("SMG  +%d ammo" % (it.amount if it.amount > 0 else 60))
	return true


func get_blips() -> Array:
	var out := []
	var pp: Vector3 = game.player_pos()
	for it in items:
		var n: Node3D = it.node
		if n.visible and it.kind != "cash" and pp.distance_to(it.pos) < 200.0:
			out.append([it.pos, COLORS[it.kind], "pickup"])
	return out
