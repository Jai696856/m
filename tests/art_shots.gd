# Fast art-review renders: a few camera angles on one map (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/art_shots.gd -- <out_dir> [shots] [map_index]
# shots: comma list of board, wide, close, shore, low, hub (default: all)
extends SceneTree

const TYPES := ["blue", "green", "gold", "violet", "kitsune", "prism", "shadow", "frost", "lantern", "mask"]

var out := "user://"
var only: Array = []
var main: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1 and args[1] != "all":
		only = Array(args[1].split(","))
	var map_i := int(args[2]) if args.size() > 2 else 0
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(2)
	main.save = ConfigFile.new()
	main.progress.save = main.save
	main.sfx.muted = true
	main.save.set_value("settings", "tutorial_seen", true)
	main.progress.unlock_everything(main.Defs.HERO_ORDER)
	main.menu.login_shown = true
	main.menu.visible = false
	main.ui.toast_box.visible = false

	main.new_game("normal", map_i, "sandbox")
	main.ui.sandbox_panel.visible = false
	var picks := ["ninja", "mage", "kenta", "komugi", "mecha", "idol", "ice", "samurai", "miko", "lumi"]
	var n := 0
	for x in range(-30, 26, 3):
		for z in range(-17, 18, 3):
			if n < picks.size() and main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < 4.5:
				var h = main.place_hero(picks[n], float(x), float(z))
				for t in range(n % 4):
					main.buy_upgrade(h, n % 3)
				n += 1
	main.select_hero(null)
	for i in range(40):
		main.spawn_enemy(TYPES[i % TYPES.size()], main.path_len * (0.03 + 0.9 * i / 40.0))
	main.spawn_enemy("oni", main.path_len * 0.55)
	for i in range(30):
		main._step(1.0 / 60.0)
	main._fit_camera()
	await _wait(6)
	await _shot("board")
	main.ui.set_hud_visible(false)
	main.ui.banner_box.visible = false
	var h0 = main.heroes[1]
	var hp := Vector3(h0.x, 0, h0.z)
	if _want("wide"):
		_cam(Vector3(0, 0, 0), 46.0, 0.72, 0.35)
		await _wait(4)
		await _shot("wide")
	if _want("close"):
		_cam(hp + Vector3(0, 1.0, 0), 16.5, 0.5, 0.6)
		await _wait(4)
		await _shot("close")
	if _want("low"):
		_cam(hp + Vector3(2, 1.0, 1), 24.0, 0.38, -0.5)
		await _wait(4)
		await _shot("low")
	if _want("shore"):
		var sx := -30.0
		var sz := 0.0
		match main.level.shore_side():
			"top":
				sx = 0.0
				sz = -17.0
			"bottom":
				sx = 0.0
				sz = 17.0
		_cam(Vector3(sx, 0, sz), 30.0, 0.62, 0.9 if main.level.shore_side() == "left" else 0.2)
		await _wait(4)
		await _shot("shore")
	if _want("hub"):
		main.to_home()
		main.menu.visible = false
		await _wait(20)
		await _shot("hub")
	main.queue_free()
	await process_frame
	quit(0)

func _cam(target: Vector3, dist: float, pitch: float, yaw: float) -> void:
	main.cam_target = target
	main.cam_dist = dist
	main.cam_pitch = pitch
	main.cam_yaw = yaw

func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	if not _want(name):
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
