extends Node3D
## Story missions from three contacts, then endless freelance jobs.
## Types: courier (steal a car and deliver it), race (checkpoints against the
## clock), package (pick up, lose the cops, deliver), demolition (wreck marked
## vans) and hit (take out a target with bodyguards).

const Util := preload("res://scripts/util.gd")
const Car := preload("res://scripts/car.gd")
const Ped := preload("res://scripts/ped.gd")

const CONTACTS := ["Rosa", "Dex", "Lena"]
const CONTACT_COLORS := [Color(1.0, 0.75, 0.2), Color(0.3, 0.85, 1.0), Color(1.0, 0.4, 0.75)]
const STORY := [
	{"type": "courier", "contact": 0, "title": "First Wheels", "reward": 1500,
		"intro": "Rosa: \"New in town? Prove you can drive. There's a gold Marlin GT parked across the city. Bring it to my lot.\""},
	{"type": "race", "contact": 1, "title": "Sunset Sprint", "reward": 2500, "checkpoints": 8,
		"intro": "Dex: \"Eight checkpoints through the streets. Beat the clock and the pot is yours.\""},
	{"type": "package", "contact": 2, "title": "Hot Package", "reward": 3000,
		"intro": "Lena: \"I need a package picked up. The drop is watched, so expect company. Lose them before you come back.\""},
	{"type": "demolition", "contact": 0, "title": "Scrap Run", "reward": 3500,
		"intro": "Rosa: \"A rival crew parked three green vans around town. Wreck every one of them.\""},
	{"type": "hit", "contact": 2, "title": "The Collector", "reward": 4500,
		"intro": "Lena: \"A loan shark in a white suit is squeezing my friends. He walks with two guards. Deal with him.\""},
	{"type": "race", "contact": 1, "title": "Night Run", "reward": 5000, "checkpoints": 12, "tight": true,
		"intro": "Dex: \"Twelve checkpoints and a tighter clock. Show me what you've really got.\""},
]

var game
var city
var index := 0
var freelance := 0
var active: Dictionary = {}
var contact_marker: Node3D
var markers: Array = []
var rng := RandomNumberGenerator.new()
var start_cd := 0.0
var heists_done := 0

## The big one: an original multi-stage heist on the Shoreline Reserve.
const HEIST := {"type": "heist", "contact": 2, "title": "The Shoreline Job", "reward": 0,
	"intro": "Lena: \"The Shoreline Reserve keeps gold in its ground-floor vault. Steal the armored van, drill the vault, grab what you can carry, and meet the boat at Gator Tours.\""}
const GOLD_VALUE := 12500
const DRILL_TIME := 25.0
const BOAT_POS := Vector3(552.0, 0.3, 0.0)


func can_heist() -> String:
	if is_active():
		return "Finish your current job first."
	if index < 3:
		return "Lena: \"Do a few more jobs for the crew first.\" (%d/3)" % index
	if game.police.wanted > 0:
		return "Lose the cops first."
	return ""


func setup(g) -> void:
	game = g
	city = g.city
	name = "Missions"
	rng.randomize()


func next_def() -> Dictionary:
	if index < STORY.size():
		return STORY[index]
	var types := ["courier", "race", "package", "demolition", "hit"]
	var t: String = types[freelance % types.size()]
	var contact: int = {"courier": 0, "race": 1, "package": 2, "demolition": 0, "hit": 2}[t]
	return {"type": t, "contact": contact, "title": "Freelance Job #%d" % (freelance + 1),
		"reward": 2000 + freelance * 400, "checkpoints": 8 + mini(freelance, 6), "tight": freelance > 3,
		"intro": "%s has another job for you." % CONTACTS[contact]}


func contact_pos() -> Vector3:
	return city.contact_points[next_def().contact]


func is_active() -> bool:
	return not active.is_empty()


func _physics_process(delta: float) -> void:
	start_cd -= delta
	if game.state != "play":
		return
	if active.is_empty():
		_idle()
		return
	match active.def.type:
		"courier": _courier(delta)
		"race": _race(delta)
		"package": _package(delta)
		"demolition": _demolition(delta)
		"hit": _hit(delta)
		"heist": _heist(delta)
	if active.is_empty():
		return
	if active.has("timer"):
		active.timer -= delta
		if active.timer <= 0.0:
			fail("Out of time.")


func _idle() -> void:
	var def := next_def()
	var cp: Vector3 = city.contact_points[def.contact]
	if contact_marker == null:
		contact_marker = game.fx.make_marker(CONTACT_COLORS[def.contact], 1.4, 3.0)
		add_child(contact_marker)
	contact_marker.global_position = cp
	contact_marker.visible = true
	_spin(contact_marker)
	var pp: Vector3 = game.player_pos()
	var r := 4.5 if game.player.in_car else 2.0
	if pp.distance_to(cp) < r + 3.0:
		game.hint = "%s: \"%s\"" % [CONTACTS[def.contact], def.title]
	if pp.distance_to(cp) < r and start_cd <= 0.0:
		if game.police.wanted > 0:
			game.hint = "Lose the cops before starting a job."
			return
		start(def)


func _spin(m: Node3D) -> void:
	var a := m.get_node_or_null("Arrow")
	if a:
		a.rotation.y += 0.05
		a.position.y = 4.2 + sin(Time.get_ticks_msec() * 0.004) * 0.3


func start(def: Dictionary) -> void:
	active = {"def": def, "stage": 0}
	if contact_marker:
		contact_marker.visible = false
	game.hud.big_message(def.title.to_upper(), "", CONTACT_COLORS[def.contact], 2.5)
	game.hud.subtitle(def.intro, 7.0)
	game.sfx.play("pass", null, -8.0, 1.3)
	match def.type:
		"courier": _start_courier()
		"race": _start_race()
		"package": _start_package()
		"demolition": _start_demolition()
		"hit": _start_hit()
		"heist": _start_heist()


func _marker(pos: Vector3, color: Color, radius := 2.0, height := 4.0) -> Node3D:
	var m: Node3D = game.fx.make_marker(color, radius, height)
	add_child(m)
	m.global_position = pos
	markers.append(m)
	return m


func _clear_markers() -> void:
	for m in markers:
		if is_instance_valid(m):
			m.queue_free()
	markers.clear()


func _far_spot(min_d: float, max_d: float, kind := "curb") -> Variant:
	var pp: Vector3 = game.player_pos()
	for attempt in 60:
		var v
		var pos: Vector3
		if kind == "curb":
			var xf: Transform3D = city.random_curb_xf(rng)
			v = xf
			pos = xf.origin
		else:
			pos = city.random_sidewalk_point(rng)
			v = pos
		var d := pos.distance_to(pp)
		if d >= min_d and d <= max_d:
			return v
	return city.random_curb_xf(rng) if kind == "curb" else city.random_sidewalk_point(rng)


func _objective(text: String) -> void:
	game.hud.objective = text


# --- courier ---------------------------------------------------------------------

func _start_courier() -> void:
	var xf: Transform3D = _far_spot(220.0, 420.0)
	var car = game.traffic.spawn_car("sport", Color(0.95, 0.75, 0.2), xf)
	car.mission = true
	active.car = car
	active.drop = city.contact_points[0] + Vector3(20.0, 0, -30.0)
	_objective("Steal the gold Marlin GT.")


func _courier(_delta: float) -> void:
	var car = active.car
	if not is_instance_valid(car) or car.dead:
		fail("The car was destroyed.")
		return
	if active.stage == 0:
		if game.player.in_car == car:
			active.stage = 1
			active.timer = maxf(60.0, car.global_position.distance_to(active.drop) / 13.0 + 35.0)
			_marker(active.drop, Color(1.0, 0.8, 0.2), 4.0, 5.0)
			_objective("Deliver the car to Rosa's lot.")
	else:
		if game.player.in_car != car:
			_objective("Get back in the Marlin GT.")
		else:
			_objective("Deliver the car to Rosa's lot.")
		if car.global_position.distance_to(active.drop) < 6.0 and car.linear_velocity.length() < 4.0:
			if car.health < 40.0:
				passed(0.6, "The car is a wreck. Rosa pays less.")
			else:
				passed()


# --- race --------------------------------------------------------------------------

func _start_race() -> void:
	var start_node: Vector2i = city.nearest_node(city.contact_points[1])
	active.start = city.nodev(start_node) + Vector3(0, 0, 0)
	active.start_node = start_node
	_marker(active.start, Color(0.3, 0.85, 1.0), 6.0, 6.0)
	_objective("Get a car and drive to the start line.")


func _build_route(from: Vector2i, count: int) -> Array:
	var route: Array = []
	var visited := {from: true}
	var cur := from
	var prev := Vector2i(-1, -1)
	var dir := Vector2i.ZERO
	while route.size() < count:
		var opts: Array[Vector2i] = []
		for n in city.neighbors(cur):
			if n == prev or visited.has(n):
				continue
			opts.append(n)
			if n - cur == dir:
				opts.append(n)
				opts.append(n)
		if opts.is_empty():
			for n in city.neighbors(cur):
				if n != prev:
					opts.append(n)
		var nxt: Vector2i = opts[rng.randi() % opts.size()]
		dir = nxt - cur
		prev = cur
		cur = nxt
		visited[cur] = true
		# skip one node now and then so checkpoints are spread out
		if rng.randf() < 0.45 or route.is_empty() and false:
			continue
		route.append(cur)
	return route


func _race(delta: float) -> void:
	var p = game.player
	match active.stage:
		0:
			if p.in_car == null:
				_objective("Get a car and drive to the start line.")
			else:
				_objective("Drive to the start line.")
				if p.in_car.global_position.distance_to(active.start) < 9.0:
					_clear_markers()
					var route := _build_route(active.start_node, active.def.get("checkpoints", 8))
					active.route = route
					active.cp = 0
					var dist := 0.0
					var prevp: Vector3 = active.start
					for n in route:
						var np: Vector3 = city.nodev(n)
						dist += absf(np.x - prevp.x) + absf(np.z - prevp.z)
						prevp = np
					active.par = dist / (19.5 if active.def.get("tight", false) else 16.5) + 10.0
					active.stage = 1
					active.count = 3.0
					game.hud.big_message("3", "", Color(1, 1, 1), 0.9)
					game.sfx.play("click", null, 0.0)
		1:
			active.count -= delta
			var n := ceili(active.count)
			if n != active.get("shown", 4) and n > 0:
				active.shown = n
				game.hud.big_message(str(n), "", Color(1, 1, 1), 0.9)
				game.sfx.play("click", null, 0.0)
			if active.count <= 0.0:
				game.hud.big_message("GO!", "", Color(0.3, 1.0, 0.4), 1.0)
				game.sfx.play("pickup", null, 0.0)
				active.stage = 2
				active.timer = active.par
				_show_checkpoint()
		2:
			if p.in_car == null:
				_objective("Get back in a car!")
			else:
				_objective("Race! Checkpoint %d / %d" % [active.cp + 1, active.route.size()])
			var target: Vector3 = city.nodev(active.route[active.cp])
			if game.player_pos().distance_to(target) < 10.0:
				active.cp += 1
				game.sfx.play("pickup", null, -2.0, 1.0 + active.cp * 0.04)
				if active.cp >= active.route.size():
					passed()
					return
				_show_checkpoint()


func _show_checkpoint() -> void:
	_clear_markers()
	var target: Vector3 = city.nodev(active.route[active.cp])
	_marker(target, Color(1.0, 0.85, 0.2), 7.0, 18.0)
	if active.cp + 1 < active.route.size():
		_marker(city.nodev(active.route[active.cp + 1]), Color(1.0, 0.6, 0.2), 3.0, 8.0)


# --- package -------------------------------------------------------------------------

func _start_package() -> void:
	var pos: Vector3 = _far_spot(180.0, 380.0, "sidewalk")
	active.pkg = pos
	active.drop = city.contact_points[2]
	_marker(pos, Color(0.3, 1.0, 0.45), 1.5, 3.5)
	var box := MeshInstance3D.new()
	box.mesh = Util.box(0.6, 0.45, 0.45)
	box.material_override = Util.mat(Color(0.65, 0.48, 0.28))
	markers[0].add_child(box)
	box.position.y = 0.35
	_objective("Pick up the package.")


func _package(_delta: float) -> void:
	var pp: Vector3 = game.player_pos()
	if active.stage == 0:
		if pp.distance_to(active.pkg) < (4.0 if game.player.in_car else 2.0):
			_clear_markers()
			active.stage = 1
			game.sfx.play("pickup")
			game.police.set_min_stars(2)
			game.hud.subtitle("It's a setup! Lose the cops, then bring the package to Lena.", 5.0)
	else:
		if game.police.wanted > 0:
			_objective("Lose the cops.")
			if not markers.is_empty():
				_clear_markers()
		else:
			_objective("Deliver the package to Lena.")
			if markers.is_empty():
				_marker(active.drop, CONTACT_COLORS[2], 2.0, 4.0)
			if pp.distance_to(active.drop) < (5.0 if game.player.in_car else 2.5):
				passed()


# --- demolition ------------------------------------------------------------------------

func _start_demolition() -> void:
	active.vans = []
	for k in 3:
		var xf: Transform3D = _far_spot(140.0 + k * 40.0, 420.0)
		var van = game.traffic.spawn_car("van", Color(0.2, 0.55, 0.25), xf)
		van.mission = true
		active.vans.append(van)
	active.timer = 300.0
	_objective("Wreck the green vans (0/3).")


func _demolition(_delta: float) -> void:
	var done := 0
	for v in active.vans:
		if not is_instance_valid(v) or v.dead:
			done += 1
	_objective("Wreck the green vans (%d/3). Shoot them or ram them." % done)
	if done >= 3:
		passed()


# --- hit -----------------------------------------------------------------------------------

func _start_hit() -> void:
	var pos: Vector3 = _far_spot(200.0, 380.0, "sidewalk")
	var target = game.peds.spawn_ped(pos, "target")
	target.mission = true
	target.state = Ped.IDLE
	active.target = target
	active.guards = []
	for s in [-1.0, 1.0]:
		var g = game.peds.spawn_ped(pos + Vector3(s * 1.6, 0, 1.2), "guard")
		g.mission = true
		g.state = Ped.IDLE
		active.guards.append(g)
	_objective("Take out the loan shark in the white suit.")


func _hit(_delta: float) -> void:
	var t = active.target
	if not is_instance_valid(t):
		fail("He got away.")
		return
	if t.state == Ped.DEAD:
		game.police.set_min_stars(2)
		passed()
		return
	if t.global_position.distance_to(game.player_pos()) > 450.0:
		fail("He got away.")


# --- results ----------------------------------------------------------------------------

func passed(mult := 1.0, note := "", reward_override := -1) -> void:
	var def: Dictionary = active.def
	var reward := int(def.reward * mult) if reward_override < 0 else reward_override
	var was_heist: bool = def.type == "heist"
	_cleanup(true)
	game.add_money(reward, false)
	game.stats.missions += 1
	game.hud.big_message("MISSION PASSED", "+$%d" % reward, Color(1.0, 0.8, 0.2), 4.0)
	if note != "":
		game.hud.subtitle(note, 4.0)
	game.sfx.play("pass")
	game.post("race" if def.type == "race" else "mission")
	if was_heist:
		heists_done += 1
		game.stats.heists += 1
		game.post("heist")
	elif index < STORY.size():
		index += 1
		if index == STORY.size():
			game.hud.subtitle("That's the whole story. Your contacts still have freelance work.", 6.0)
	else:
		freelance += 1
	start_cd = 4.0


func fail(reason: String) -> void:
	if active.is_empty():
		return
	_cleanup(false)
	if game.state == "play":
		game.hud.big_message("MISSION FAILED", reason, Color(0.9, 0.2, 0.2), 4.0)
		game.sfx.play("fail")
	else:
		game.hud.subtitle("Mission failed: " + reason, 5.0)
	start_cd = 6.0


func _cleanup(_success: bool) -> void:
	_clear_markers()
	if active.has("car") and is_instance_valid(active.car):
		active.car.mission = false
	if active.has("vans"):
		for v in active.vans:
			if is_instance_valid(v):
				v.mission = false
	for key in ["target"]:
		if active.has(key) and is_instance_valid(active[key]):
			active[key].mission = false
	if active.get("def", {}).get("type", "") == "heist":
		game.interiors.close_vault(game.interiors.reserve)
		for g in game.interiors.reserve.gold:
			g.visible = true
	if active.has("guards"):
		for g in active.guards:
			if is_instance_valid(g):
				g.mission = false
	active = {}
	game.hud.objective = ""


func get_blips() -> Array:
	var out := []
	if active.is_empty():
		var def := next_def()
		out.append([city.contact_points[def.contact], CONTACT_COLORS[def.contact], "contact"])
		return out
	var y := Color(1.0, 0.85, 0.2)
	match active.def.type:
		"courier":
			if active.stage == 0 and is_instance_valid(active.car):
				out.append([active.car.global_position, Color(0.3, 0.6, 1.0), "target"])
			elif active.stage == 1:
				out.append([active.drop, y, "objective"])
		"race":
			if active.stage == 0:
				out.append([active.start, y, "objective"])
			elif active.has("route") and active.cp < active.route.size():
				out.append([city.nodev(active.route[active.cp]), y, "objective"])
		"package":
			if active.stage == 0:
				out.append([active.pkg, Color(0.3, 1.0, 0.45), "objective"])
			elif game.police.wanted == 0:
				out.append([active.drop, y, "objective"])
		"demolition":
			for v in active.vans:
				if is_instance_valid(v) and not v.dead:
					out.append([v.global_position, Color(1.0, 0.25, 0.25), "target"])
		"heist":
			match active.stage:
				0:
					if is_instance_valid(active.car):
						out.append([active.car.global_position, Color(0.3, 0.6, 1.0), "target"])
				1:
					out.append([game.interiors.reserve.street, y, "objective"])
				2, 3, 4:
					out.append([game.interiors.reserve.vault_front, y, "objective"])
				5:
					out.append([BOAT_POS, Color(0.3, 1.0, 0.6), "objective"])
		"hit":
			if is_instance_valid(active.target):
				out.append([active.target.global_position, Color(1.0, 0.25, 0.25), "target"])
	return out


## "Press F" steps of the heist.
func get_interaction(pos: Vector3) -> Dictionary:
	if active.is_empty() or active.def.type != "heist" or game.player.in_car:
		return {}
	var r: Dictionary = game.interiors.reserve
	if active.stage == 2 and pos.distance_to(r.vault_front) < 2.8:
		return {"text": "start drilling the vault", "pos": r.vault_front, "call": _start_drill}
	if active.stage == 4:
		for g in r.gold:
			if g.visible and pos.distance_to(g.global_position) < 2.4:
				return {"text": "grab the gold ($%d)" % GOLD_VALUE, "pos": g.global_position, "call": _grab_gold.bind(g)}
	return {}


# --- heist --------------------------------------------------------------------------------

func _start_heist() -> void:
	var xf: Transform3D = _far_spot(180.0, 380.0)
	var van = game.traffic.spawn_car("van", Color(0.28, 0.3, 0.33), xf)
	van.mission = true
	active.car = van
	active.take = 0
	active.guards = []
	_objective("Steal the armored van.")


func _heist(delta: float) -> void:
	var r: Dictionary = game.interiors.reserve
	var p = game.player
	var van = active.car
	match active.stage:
		0, 1:
			if not is_instance_valid(van) or van.dead:
				fail("The armored van was wrecked.")
				return
			if active.stage == 0 and p.in_car == van:
				active.stage = 1
				_marker(r.street, Color(1.0, 0.82, 0.35), 5.0, 6.0)
			if active.stage == 1:
				_objective("Drive the armored van to the Shoreline Reserve." if p.in_car == van else "Get back in the armored van.")
				if van.global_position.distance_to(r.street) < 9.0 and van.linear_velocity.length() < 4.0:
					_clear_markers()
					active.stage = 2
					for spot in r.guard_spots:
						var gd = game.peds.spawn_ped(spot, "guard")
						gd.mission = true
						gd.state = Ped.IDLE
						active.guards.append(gd)
					_marker(r.vault_front, Color(1.0, 0.82, 0.35), 1.2, 3.0)
					game.hud.subtitle("Lena: \"Guards inside. Get to the vault door and start the drill.\"", 5.0)
		2:
			_objective("Get inside and drill the vault.")
			if game.interiors.inside("reserve", p.global_position):
				for gd in active.guards:
					if is_instance_valid(gd) and gd.state == Ped.IDLE:
						gd.alerted = true
						gd.state = Ped.CHASE
		3:
			var near: bool = p.in_car == null and p.global_position.distance_to(r.vault_front) < 8.0
			if near:
				active.drill -= delta
				active.spark -= delta
				if active.spark <= 0.0:
					active.spark = 0.15
					game.fx.spark(r.door.global_position + Vector3(2.1, 0, 0.5))
				_objective("Drilling the vault... %d s  (stay close and hold them off)" % ceili(active.drill))
			else:
				_objective("Get back to the drill!")
			if active.drill <= 0.0:
				_clear_markers()
				game.interiors.open_vault(r)
				game.police.set_min_stars(4)
				active.stage = 4
				game.hud.big_message("VAULT OPEN", "Grab the gold", Color(1.0, 0.82, 0.35), 2.5)
		4:
			var left := 0
			for g in r.gold:
				if g.visible:
					left += 1
			var taken: int = r.gold.size() - left
			_objective("Grab the gold (%d/%d, $%d), then get out." % [taken, r.gold.size(), active.take])
			if taken > 0 and (left == 0 or not game.interiors.inside("reserve", p.global_position)):
				active.stage = 5
				_marker(BOAT_POS, Color(0.3, 1.0, 0.6), 4.0, 8.0)
				game.hud.subtitle("Lena: \"The boat's waiting at Gator Tours. Move!\"", 5.0)
		5:
			_objective("Escape to the boat at Gator Tours ($%d in gold)." % active.take)
			if game.player_pos().distance_to(BOAT_POS) < 7.0:
				var take: int = active.take
				game.police.clear()
				passed(1.0, "The boat slips into the swamp. The crew splits the take.", take)


func _start_drill() -> void:
	active.stage = 3
	active.drill = DRILL_TIME
	active.spark = 0.0
	game.police.set_min_stars(3)
	game.sfx.play("alarm", game.interiors.reserve.vault_front, 4.0)
	game.hud.big_message("ALARM!", "Hold out until the drill is through", Color(1, 0.3, 0.3), 2.5)
	for gd in active.guards:
		if is_instance_valid(gd) and gd.state != Ped.DEAD:
			gd.alerted = true
			gd.state = Ped.CHASE


func _grab_gold(g: Node3D) -> void:
	g.visible = false
	active.take += GOLD_VALUE
	game.sfx.play("pickup", null, 0.0, 0.8)
	game.hud.notice("Gold: $%d" % active.take)


func timer_left() -> float:
	if active.is_empty() or not active.has("timer"):
		return -1.0
	return active.timer
