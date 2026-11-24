extends Node3D
## Buildings you can walk into: Bay Bank (robbable, with a vault), the Quick Stop
## corner store (robbable), and the Shoreline Reserve, where the big heist happens.
## Each is a hollow shell with a doorway, a furnished interior, lights and staff.
## Also offers "Press F" interactions to the player (see game.find_interaction).

const Util := preload("res://scripts/util.gd")
const Ped := preload("res://scripts/ped.gd")

const BANK_COOLDOWN := 300.0
const STORE_COOLDOWN := 180.0

var game
var city
var body: StaticBody3D
var rooms := {}          # name -> Rect2 of the inside (x/z)
var bank := {}
var store := {}
var reserve := {}
var bag := 0             # stolen cash you're carrying until you lose the cops
var _anims: Array = []   # [node, from Transform3D, to Transform3D, t, time]


func setup(g) -> void:
	game = g
	city = g.city
	name = "Interiors"
	body = StaticBody3D.new()
	body.name = "InteriorBody"
	add_child(body)
	_build_bank(city.special_blocks["bank"])
	_build_store(city.special_blocks["store"])
	_build_reserve(city.special_blocks["reserve"])


# --- construction helpers ------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, m: Material, collide := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Util.box(size.x, size.y, size.z)
	mi.material_override = m
	add_child(mi)
	mi.position = pos
	mi.rotation = rot
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		cs.position = pos
		cs.rotation = rot
	return mi


## A hollow building: four walls (doorway in the +Z wall), a ceiling, a roof,
## an interior lining and a floor. Returns the inside rectangle.
func _shell(c: Vector3, size: Vector3, door_x: float, door_w: float, door_h: float, wall: Color,
		inside: Color, floor_col: Color, style := 0) -> Rect2:
	var t := 0.4
	var y0: float = city.CURB
	var ext: ShaderMaterial = city._bmat(wall, style)
	var lin := Util.mat(inside, 0.8)
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	var h := size.y
	# back and sides
	_wall(Vector3(size.x, h, t), Vector3(c.x, y0 + h * 0.5, c.z - hd + t * 0.5), ext)
	_wall(Vector3(t, h, size.z), Vector3(c.x - hw + t * 0.5, y0 + h * 0.5, c.z), ext)
	_wall(Vector3(t, h, size.z), Vector3(c.x + hw - t * 0.5, y0 + h * 0.5, c.z), ext)
	# front wall with a doorway
	var fz := c.z + hd - t * 0.5
	var left := (door_x - door_w * 0.5) - (c.x - hw)
	var right := (c.x + hw) - (door_x + door_w * 0.5)
	_wall(Vector3(left, h, t), Vector3(c.x - hw + left * 0.5, y0 + h * 0.5, fz), ext)
	_wall(Vector3(right, h, t), Vector3(c.x + hw - right * 0.5, y0 + h * 0.5, fz), ext)
	_wall(Vector3(door_w, h - door_h, t), Vector3(door_x, y0 + door_h + (h - door_h) * 0.5, fz), ext)
	# ceiling + roof
	_box(Vector3(size.x, t, size.z), Vector3(c.x, y0 + h - t * 0.5, c.z), Util.mat(Color(0.35, 0.35, 0.37)))
	# inside lining so the walls don't show window glass from within
	var li := 0.05
	_box(Vector3(size.x - t * 2.0, h - t, li), Vector3(c.x, y0 + h * 0.5, c.z - hd + t + li * 0.5), lin, false)
	_box(Vector3(li, h - t, size.z - t * 2.0), Vector3(c.x - hw + t + li * 0.5, y0 + h * 0.5, c.z), lin, false)
	_box(Vector3(li, h - t, size.z - t * 2.0), Vector3(c.x + hw - t - li * 0.5, y0 + h * 0.5, c.z), lin, false)
	_box(Vector3(left - t, h - t, li), Vector3(c.x - hw + t + (left - t) * 0.5, y0 + h * 0.5, fz - t * 0.5 - li * 0.5), lin, false)
	_box(Vector3(right - t, h - t, li), Vector3(c.x + hw - t - (right - t) * 0.5, y0 + h * 0.5, fz - t * 0.5 - li * 0.5), lin, false)
	# floor
	_box(Vector3(size.x - t * 2.0, 0.02, size.z - t * 2.0), Vector3(c.x, y0 + 0.012, c.z), Util.mat(floor_col, 0.25), false)
	city.footprints.append(Rect2(c.x - hw, c.z - hd, size.x, size.z))
	return Rect2(c.x - hw + t, c.z - hd + t, size.x - t * 2.0, size.z - t * 2.0)


func _wall(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = city.unit_box
	mi.material_override = m
	mi.scale = size
	add_child(mi)
	mi.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	cs.position = pos


func _light(pos: Vector3, energy := 1.6, rng := 16.0, col := Color(1.0, 0.95, 0.85)) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = rng
	l.light_color = col
	l.shadow_enabled = false
	add_child(l)
	var panel := Util.glow_mat(Color(1.0, 0.97, 0.9), 1.5)
	_box(Vector3(2.0, 0.06, 0.8), pos + Vector3(0, 0.6, 0), panel, false)


func _staff(pos: Vector3, yaw: float, shirt: Color):
	var p = game.peds.spawn_ped(pos, "ped")
	p.mission = true
	p.state = Ped.IDLE
	p.model.rotation.y = yaw
	p.model.reset_pose()
	return p


func _money_stack(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	var parts := []
	for i in 3:
		for j in 2:
			parts.append([Util.box(0.5, 0.22, 0.3), Util.xf(Vector3(i * 0.55 - 0.55, 0.11 + j * 0.23, 0)), Color(0.3, 0.7, 0.35)])
			parts.append([Util.box(0.52, 0.06, 0.31), Util.xf(Vector3(i * 0.55 - 0.55, 0.11 + j * 0.23, 0)), Color(0.95, 0.95, 0.85)])
	var mi := MeshInstance3D.new()
	mi.mesh = Util.merge(parts)
	mi.material_override = Util.vc_mat(0.6)
	n.add_child(mi)
	add_child(n)
	n.position = pos
	return n


func _gold_pallet(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	var parts := [[Util.box(1.4, 0.15, 1.1), Util.xf(Vector3(0, 0.08, 0)), Color(0.45, 0.33, 0.2)]]
	for i in 3:
		for j in 3:
			for k in 2:
				parts.append([Util.box(0.4, 0.14, 0.24), Util.xf(Vector3(i * 0.44 - 0.44, 0.23 + k * 0.15, j * 0.32 - 0.32)), Color(1.0, 0.78, 0.2)])
	var mi := MeshInstance3D.new()
	mi.mesh = Util.merge(parts)
	var m := Util.vc_mat(0.25, 0.9)
	mi.material_override = m
	n.add_child(mi)
	add_child(n)
	n.position = pos
	return n


func _vault_door(pos: Vector3, r: float) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	var steel := Color(0.62, 0.64, 0.68)
	var mi := MeshInstance3D.new()
	var parts := [[Util.cyl(r, r, 0.45, 28), Util.xf(Vector3(r, 0, 0), Vector3(PI * 0.5, 0, 0)), steel]]
	parts.append([Util.cyl(r * 0.35, r * 0.35, 0.6, 16), Util.xf(Vector3(r, 0, 0.1), Vector3(PI * 0.5, 0, 0)), steel.darkened(0.3)])
	for k in 4:
		var a := k * PI * 0.5
		parts.append([Util.box(0.12, r * 0.9, 0.12), Util.xf(Vector3(r, 0, 0.42), Vector3(0, 0, a)), Color(0.85, 0.85, 0.88)])
	mi.mesh = Util.merge(parts)
	mi.material_override = Util.vc_mat(0.3, 0.8)
	n.add_child(mi)
	# hinge on the left edge (local x=0); the door body spans x 0..2r
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(r * 2.0, r * 2.0, 0.45)
	cs.shape = sh
	cs.position = Vector3(r, 0, 0)
	sb.add_child(cs)
	n.add_child(sb)
	return n


func _animate(node: Node3D, to: Transform3D, time: float) -> void:
	_anims.append([node, node.transform, to, 0.0, time])


func _sign_box(text: String, pos: Vector3, color: Color, px := 0.022) -> void:
	city._sign(text, pos, Vector3(0, 0, 1), color, px)


# --- Bay Bank ---------------------------------------------------------------------------

func _build_bank(c: Vector3) -> void:
	var cz := c.z + 15.0
	var bc := Vector3(c.x, 0, cz)
	var door_x := c.x - 6.0
	var room := _shell(bc, Vector3(30, 8, 22), door_x, 3.6, 3.8, Color(0.9, 0.86, 0.76), Color(0.93, 0.9, 0.82), Color(0.86, 0.83, 0.78), 0)
	rooms["bank"] = room
	city._building(Vector2(c.x, c.z - 14.0), Vector3(40, 26, 22), Color(0.78, 0.74, 0.66), 0, body)
	var y: float = city.CURB
	_sign_box("BAY BANK", Vector3(c.x + 4.0, y + 6.0, cz + 11.0), Color(0.4, 0.85, 1.0), 0.03)
	var marble := Util.mat(Color(0.7, 0.68, 0.62), 0.3)
	var wood := Util.mat(Color(0.45, 0.3, 0.18), 0.6)
	var glass := Util.mat(Color(0.6, 0.8, 0.9), 0.05)
	# columns flanking the door
	for dx in [-2.6, 2.6]:
		_box(Vector3(0.7, 7.6, 0.7), Vector3(door_x + dx, y + 3.8, cz + 11.6), marble)
	# teller counter with glass screens, gap on the left so staff can get behind
	var counter_c := Vector3(c.x + 4.0, y + 0.55, cz - 1.0)
	_box(Vector3(16, 1.1, 0.9), counter_c, wood)
	_box(Vector3(16, 0.05, 1.0), counter_c + Vector3(0, 0.58, 0), marble, false)
	_box(Vector3(16, 1.0, 0.05), counter_c + Vector3(0, 1.1, 0.0), glass, false)
	# vault wall with an opening, and the round vault door
	var vz := cz - 6.0
	var vx := c.x + 8.0
	var vw := 3.2
	_box(Vector3((vx - vw * 0.5) - (c.x - 14.6), 7.6, 0.4), Vector3(((vx - vw * 0.5) + (c.x - 14.6)) * 0.5, y + 3.8, vz), marble)
	_box(Vector3((c.x + 14.6) - (vx + vw * 0.5), 7.6, 0.4), Vector3(((c.x + 14.6) + (vx + vw * 0.5)) * 0.5, y + 3.8, vz), marble)
	_box(Vector3(vw, 7.6 - 3.4, 0.4), Vector3(vx, y + 3.4 + (7.6 - 3.4) * 0.5, vz), marble)
	var door := _vault_door(Vector3(vx - 1.6, y + 1.7, vz + 0.35), 1.6)
	bank.door = door
	bank.door_closed = door.transform
	bank.door_open = Transform3D(Basis(Vector3.UP, -PI * 0.55), door.position)
	# vault shelves and cash
	bank.piles = []
	for px in [c.x + 4.0, c.x + 8.0, c.x + 12.0]:
		_box(Vector3(2.4, 1.0, 0.8), Vector3(px, y + 0.5, cz - 10.0), Util.mat(Color(0.4, 0.42, 0.45), 0.4, 0.6))
		var s := _money_stack(Vector3(px, y + 1.0, cz - 10.0))
		bank.piles.append(s)
	# lobby furniture
	for dx in [-11.0, -8.0]:
		_box(Vector3(1.8, 0.8, 1.0), Vector3(c.x + dx, y + 0.4, cz + 4.0), wood)
		_box(Vector3(0.6, 0.9, 0.6), Vector3(c.x + dx, y + 0.45, cz + 5.2), Util.mat(Color(0.2, 0.2, 0.25)))
	for p in [Vector3(c.x - 13.5, 0, cz + 9.5), Vector3(c.x + 13.5, 0, cz + 9.5)]:
		_box(Vector3(0.6, 0.6, 0.6), p + Vector3(0, y + 0.3, 0), Util.mat(Color(0.75, 0.45, 0.3)))
		_box(Vector3(1.0, 1.2, 1.0), p + Vector3(0, y + 1.2, 0), Util.mat(Color(0.25, 0.5, 0.2)), false)
	_box(Vector3(6, 0.02, 9), Vector3(door_x, y + 0.03, cz + 6.0), Util.mat(Color(0.6, 0.1, 0.12), 0.9), false)
	_light(Vector3(c.x - 5.0, y + 6.6, cz + 4.0))
	_light(Vector3(c.x + 7.0, y + 6.6, cz - 3.0))
	_light(Vector3(c.x + 8.0, y + 6.6, cz - 9.0), 1.2, 10.0)
	bank.teller = _staff(Vector3(c.x + 4.0, y, cz - 3.0), 0.0, Color.WHITE)
	bank.teller_pos = Vector3(c.x + 4.0, y, cz - 3.0)
	bank.counter_front = Vector3(c.x + 4.0, y, cz + 0.5)
	bank.vault_front = Vector3(vx, y, vz + 1.5)
	bank.entrance = Vector3(door_x, y, cz + 13.5)
	bank.state = "idle"
	bank.cool = 0.0


# --- Quick Stop corner store ---------------------------------------------------------------

func _build_store(c: Vector3) -> void:
	var cz := c.z + 21.0
	var sc := Vector3(c.x, 0, cz)
	var door_x := c.x + 3.5
	var room := _shell(sc, Vector3(16, 4.6, 12), door_x, 2.6, 3.0, Color(0.95, 0.9, 0.7), Color(0.95, 0.95, 0.92), Color(0.82, 0.84, 0.86), 2)
	rooms["store"] = room
	var y: float = city.CURB
	_sign_box("QUICK STOP 24", Vector3(c.x - 1.0, y + 3.8, cz + 6.0), Color(1.0, 0.45, 0.2), 0.018)
	var stripe := Util.glow_mat(Color(1.0, 0.4, 0.2), 1.6)
	city.neon_mats.append(stripe)
	_box(Vector3(15.8, 0.25, 0.1), Vector3(c.x, y + 3.2, cz + 6.06), stripe, false)
	# shelves with colourful products
	for row in 3:
		var sz := cz - 3.0 + row * 2.6
		var sx := c.x - 3.0
		_box(Vector3(7.0, 1.7, 0.7), Vector3(sx, y + 0.85, sz), Util.mat(Color(0.85, 0.85, 0.88)))
		var parts := []
		for k in 22:
			var col: Color = [Color(1, 0.3, 0.3), Color(0.3, 0.6, 1), Color(1, 0.85, 0.2), Color(0.3, 0.8, 0.4), Color(0.9, 0.5, 0.9)][k % 5]
			var lvl := k % 2
			parts.append([Util.box(0.25, 0.32, 0.25), Util.xf(Vector3(-3.2 + (k / 2) * 0.6, 0.65 + lvl * 0.7, 0.3 * (1 - 2 * (k % 2)))), col])
		var mi := MeshInstance3D.new()
		mi.mesh = Util.merge(parts)
		mi.material_override = Util.vc_mat(0.6)
		add_child(mi)
		mi.position = Vector3(sx, y + 0.5, sz)
	# glowing drinks fridge on the back wall
	var fridge := Util.glow_mat(Color(0.7, 0.95, 1.0), 0.8)
	_box(Vector3(6.0, 2.2, 0.6), Vector3(c.x - 3.0, y + 1.1, cz - 5.4), fridge)
	# counter and register
	_box(Vector3(1.0, 1.0, 3.2), Vector3(c.x + 5.0, y + 0.5, cz - 0.5), Util.mat(Color(0.3, 0.3, 0.35)))
	_box(Vector3(0.5, 0.35, 0.4), Vector3(c.x + 5.0, y + 1.17, cz - 1.2), Util.mat(Color(0.15, 0.15, 0.15)), false)
	_light(Vector3(c.x - 2.0, y + 3.6, cz), 1.3, 12.0)
	store.clerk = _staff(Vector3(c.x + 6.2, y, cz - 0.5), PI * 0.5, Color.WHITE)
	store.clerk_pos = Vector3(c.x + 6.2, y, cz - 0.5)
	store.counter_front = Vector3(c.x + 3.8, y, cz - 0.5)
	store.state = "idle"
	store.cool = 0.0
	store.t = 0.0
	# a couple of houses behind
	city._building(Vector2(c.x - 14.0, c.z - 14.0), Vector3(12, 5.5, 11), Color(0.62, 0.9, 0.8), 2, body)
	city._building(Vector2(c.x + 14.0, c.z - 14.0), Vector3(12, 6.0, 11), Color(0.98, 0.72, 0.76), 2, body)


# --- Shoreline Reserve (heist target) ----------------------------------------------------

func _build_reserve(c: Vector3) -> void:
	var cz := c.z + 14.0
	var rc := Vector3(c.x, 0, cz)
	var door_x := c.x - 8.0
	var room := _shell(rc, Vector3(34, 9, 28), door_x, 4.0, 4.2, Color(0.42, 0.48, 0.55), Color(0.86, 0.84, 0.8), Color(0.8, 0.78, 0.74), 1)
	rooms["reserve"] = room
	var y: float = city.CURB
	city._building(Vector2(c.x, cz), Vector3(34, 95, 28), Color(0.38, 0.46, 0.54), 1, body, y + 9.0)
	city._building(Vector2(c.x, c.z - 17.0), Vector3(44, 34, 20), Color(0.75, 0.72, 0.66), 0, body)
	_sign_box("SHORELINE RESERVE", Vector3(c.x + 4.0, y + 7.2, cz + 14.0), Color(1.0, 0.82, 0.35), 0.026)
	var marble := Util.mat(Color(0.72, 0.7, 0.66), 0.3)
	for px in [-10.0, -2.0, 6.0, 14.0]:
		_box(Vector3(1.0, 8.6, 1.0), Vector3(c.x + px, y + 4.3, cz + 4.0), marble)
	_box(Vector3(5.0, 1.1, 1.2), Vector3(c.x - 8.0, y + 0.55, cz + 2.0), Util.mat(Color(0.2, 0.22, 0.26)))
	# vault wall and the big round door
	var vz := cz - 6.0
	var vx := c.x + 6.0
	var vw := 4.2
	var x0 := c.x - 16.6
	var x1 := c.x + 16.6
	_box(Vector3((vx - vw * 0.5) - x0, 8.6, 0.6), Vector3(((vx - vw * 0.5) + x0) * 0.5, y + 4.3, vz), marble)
	_box(Vector3(x1 - (vx + vw * 0.5), 8.6, 0.6), Vector3((x1 + (vx + vw * 0.5)) * 0.5, y + 4.3, vz), marble)
	_box(Vector3(vw, 8.6 - 4.3, 0.6), Vector3(vx, y + 4.3 + (8.6 - 4.3) * 0.5, vz), marble)
	var door := _vault_door(Vector3(vx - 2.1, y + 2.1, vz + 0.45), 2.1)
	reserve.door = door
	reserve.door_closed = door.transform
	reserve.door_open = Transform3D(Basis(Vector3.UP, -PI * 0.55), door.position)
	reserve.gold = []
	for gp in [Vector3(c.x - 2.0, y, cz - 10.5), Vector3(c.x + 3.0, y, cz - 11.5), Vector3(c.x + 9.0, y, cz - 11.5), Vector3(c.x + 14.0, y, cz - 10.5)]:
		reserve.gold.append(_gold_pallet(gp))
	_light(Vector3(c.x - 6.0, y + 7.6, cz + 6.0), 1.8, 18.0)
	_light(Vector3(c.x + 8.0, y + 7.6, cz + 2.0), 1.6, 16.0)
	_light(Vector3(c.x + 6.0, y + 7.6, cz - 10.0), 1.4, 14.0, Color(1.0, 0.9, 0.6))
	reserve.vault_front = Vector3(vx, y, vz + 1.6)
	reserve.street = Vector3(door_x, 0.0, c.z + 40.0 - city.LANE_OFF)
	reserve.entrance = Vector3(door_x, y, cz + 15.5)
	reserve.guard_spots = [Vector3(c.x - 12.0, y, cz + 8.0), Vector3(c.x - 4.0, y, cz + 1.0), Vector3(c.x + 10.0, y, cz + 6.0), Vector3(c.x + 2.0, y, cz - 3.0)]


# --- queries ---------------------------------------------------------------------------------

func inside(room: String, pos: Vector3) -> bool:
	return rooms.has(room) and (rooms[room] as Rect2).has_point(Vector2(pos.x, pos.z))


func open_vault(which: Dictionary) -> void:
	var d: Node3D = which.door
	_animate(d, which.door_open, 2.5)
	game.sfx.play("crash", d.global_position, -4.0, 0.5)


func close_vault(which: Dictionary) -> void:
	var d: Node3D = which.door
	d.transform = which.door_closed


## The "Press F" action on offer at this spot, if any: {text, pos, call}.
func get_interaction(pos: Vector3) -> Dictionary:
	if game.player.in_car:
		return {}
	if bank.state == "idle" and inside("bank", pos) and pos.distance_to(bank.counter_front) < 3.2:
		return {"text": "rob the bank", "pos": bank.counter_front, "call": _rob_bank}
	if bank.state == "robbing":
		for s in bank.piles:
			if s.visible and pos.distance_to(s.global_position) < 2.4:
				return {"text": "grab the cash", "pos": s.global_position, "call": _grab_cash.bind(s)}
	if store.state == "idle" and inside("store", pos) and pos.distance_to(store.counter_front) < 2.6:
		return {"text": "rob the store", "pos": store.counter_front, "call": _rob_store}
	return {}


# --- robberies -------------------------------------------------------------------------------

func _rob_bank() -> void:
	bank.state = "robbing"
	bank.cool = BANK_COOLDOWN
	game.police.set_min_stars(2)
	open_vault(bank)
	if is_instance_valid(bank.teller):
		bank.teller.model.set_hands_up()
	game.hud.big_message("BANK ROBBERY", "Grab the cash in the vault, then lose the cops", Color(0.4, 0.85, 1.0), 3.0)
	game.sfx.play("horn", bank.counter_front, 4.0, 0.7)
	game.post("bank")
	game.peds.alert(bank.counter_front, 40.0)


func _grab_cash(s: Node3D) -> void:
	s.visible = false
	var amt: int = game.rng.randi_range(1800, 3000)
	bag += amt
	game.sfx.play("pickup", null, -2.0)
	game.hud.notice("Cash bag: $%d  (lose the cops to keep it)" % bag)
	game.police.set_min_stars(3)


func _rob_store() -> void:
	store.state = "emptying"
	store.t = 3.0
	store.cool = STORE_COOLDOWN
	game.police.set_min_stars(1)
	if is_instance_valid(store.clerk):
		store.clerk.model.set_hands_up()
	game.hud.subtitle("Clerk: \"Okay, okay! Take it!\"", 3.0)
	game.peds.alert(store.counter_front, 25.0)


## Called on wasted/busted: the cash bag is lost.
func on_player_down() -> void:
	if bag > 0:
		game.hud.subtitle("You lost the $%d cash bag." % bag, 4.0)
	bag = 0


func _physics_process(delta: float) -> void:
	# opening/closing animations
	var k := 0
	while k < _anims.size():
		var a: Array = _anims[k]
		a[3] += delta
		var t := clampf(a[3] / a[4], 0.0, 1.0)
		var n: Node3D = a[0]
		var from: Transform3D = a[1]
		var to: Transform3D = a[2]
		n.transform = from.interpolate_with(to, smoothstep(0.0, 1.0, t))
		if t >= 1.0:
			_anims.remove_at(k)
			continue
		k += 1
	if game.state != "play":
		return
	# the clerk hands over the register after a moment
	if store.state == "emptying":
		store.t -= delta
		if store.t <= 0.0:
			var amt: int = game.rng.randi_range(250, 650)
			game.add_money(amt, false)
			game.hud.big_message("STORE ROBBED", "+$%d" % amt, Color(1.0, 0.5, 0.2), 2.5)
			game.sfx.play("pickup")
			store.state = "cooldown"
	# keep the cash bag once the heat is off
	if bag > 0 and game.police.wanted == 0:
		game.add_money(bag, false)
		game.hud.big_message("BANK JOB DONE", "+$%d" % bag, Color(0.4, 0.95, 0.5), 3.5)
		game.sfx.play("pass")
		game.stats.robberies += 1
		bag = 0
	for d in [bank, store]:
		if d.state != "idle" and d.state != "emptying":
			d.cool -= delta
			if d.cool <= 0.0:
				d.state = "idle"
				if d == bank:
					close_vault(bank)
					for s in bank.piles:
						s.visible = true
					if is_instance_valid(bank.teller):
						bank.teller.model.reset_pose()
				elif is_instance_valid(store.clerk):
					store.clerk.model.reset_pose()


func get_blips() -> Array:
	var out := []
	out.append([bank.entrance, Color(0.4, 0.85, 1.0), "bank"])
	out.append([Vector3(store.counter_front.x, 0, store.counter_front.z + 7.0), Color(1.0, 0.55, 0.2), "store"])
	return out
