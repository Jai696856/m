# Title screen shown over a live "attract mode" game: player level, big PLAY
# button, daily challenge, and screens for heroes, achievements, stats,
# settings and how to play. Uses the style helpers from ui.gd.
extends Control

const Defs = preload("res://scripts/defs.gd")
const Maps = preload("res://scripts/maps.gd")
const Progress = preload("res://scripts/progress.gd")
const UIScript = preload("res://scripts/ui.gd")
const Icons = preload("res://scripts/icons.gd")

const TIPS := [
	"Tip: Heroes on tier 3 of any path unlock an ability. Press Q to Q-I to use them.",
	"Tip: Veiled spirits are invisible to most heroes. Kaede and upgraded heroes can see them.",
	"Tip: Shadow Wisps shrug off explosions, Frost Wisps can't be frozen.",
	"Tip: Aiko earns money every round and makes nearby heroes stronger.",
	"Tip: Regrowing spirits heal if you leave them alone. Finish them off!",
	"Tip: Expert maps have short tracks. Place damage where spirits enter.",
	"Tip: Clay Masks take many hits. Bring bonus damage against masks.",
	"Tip: Boss rounds are announced. Save money for boss-damage upgrades.",
]

var ui
var game
var level_lbl: Label
var xp_bar: ProgressBar
var xp_lbl: Label
var daily_btn: Button
var medal_pill: Label
var trophy_pill: Label
var hero_class_i := 0
var hero_list: BoxContainer
var hero_tabs: Array = []
var tip_lbl: Label
var screens := {}
var tree_hero := "ninja"
var tree_sel := Vector2i(0, 1)
var tree_title: Label
var tree_xp: Label
var tree_desc: Label
var tree_grid: VBoxContainer
var tree_preview: VBoxContainer
var tree_mastery: PanelContainer
var tip_i := 0
var gem_pill: Label
var continue_btn: Button
var title_lbl: Label
var login_shown := false
var quest_box: VBoxContainer
var skin_row: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_home()
	screens["heroes"] = _build_heroes()
	screens["tree"] = _build_tree()
	screens["achievements"] = _screen("ACHIEVEMENTS")
	screens["stats"] = _screen("STATS")
	screens["settings"] = _build_settings()
	screens["howto"] = _build_howto()
	screens["store"] = _screen("STORE")
	screens["almanac"] = _screen("SPIRIT ALMANAC")
	screens["blessings"] = _screen("SHRINE BLESSINGS")
	screens["login"] = _screen("DAILY GIFT")
	var t := Timer.new()
	t.wait_time = 6.0
	t.autostart = true
	t.timeout.connect(_next_tip)
	add_child(t)

# ---------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------
func _build_home() -> void:
	# Soft bands top and bottom so buttons read over the village
	for top in [true, false]:
		var g := ColorRect.new()
		g.color = Color(0.05, 0.1, 0.25, 0.35)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.anchor_right = 1.0
		g.anchor_top = 0.0 if top else 1.0
		g.anchor_bottom = 0.0 if top else 1.0
		g.offset_bottom = 84 if top else 0
		g.offset_top = 0 if top else -150
		add_child(g)

	# Top-left: player level badge
	var badge := HBoxContainer.new()
	badge.position = Vector2(12, 8)
	badge.add_theme_constant_override("separation", 8)
	add_child(badge)
	var star := Control.new()
	star.custom_minimum_size = Vector2(70, 70)
	badge.add_child(star)
	var star_icon = UIScript.HudIcon.new("star", 70, ui.GOLD)
	star.add_child(star_icon)
	level_lbl = ui.lbl("1", 24, Color.WHITE, 8)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_lbl.size = Vector2(70, 70)
	star.add_child(level_lbl)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	badge.add_child(bv)
	title_lbl = ui.lbl("SHRINE NOVICE", 20, Color.WHITE, 8)
	bv.add_child(title_lbl)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(220, 18)
	xp_bar.add_theme_stylebox_override("background", ui.sb(Color(0.03, 0.05, 0.12, 0.6), 9, 0, false, 0))
	xp_bar.add_theme_stylebox_override("fill", ui.sb(Color(0.35, 0.72, 1.0), 9, 0, false, 0))
	bv.add_child(xp_bar)
	xp_lbl = ui.lbl("", 13, Color.WHITE, 5)
	bv.add_child(xp_lbl)

	# Top-centre: small logo
	var logo: Label = ui.lbl("SAKURA SPIRIT DEFENSE", 30, Color.WHITE, 12)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.offset_top = 18
	add_child(logo)

	# Top-right: medals and trophies
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 10)
	pills.anchor_left = 1.0
	pills.anchor_right = 1.0
	pills.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pills.offset_right = -14
	pills.offset_top = 14
	add_child(pills)
	gem_pill = _pill(pills, "gem", ui.GEM)
	medal_pill = _pill(pills, "coin", ui.GOLD)
	trophy_pill = _pill(pills, "trophy", ui.GOLD)

	# Left column: small round buttons
	var left := _icon_column(true)
	_icon_button(left, "gear", "SETTINGS", ui.BLUE, func() -> void: _open("settings"))
	_icon_button(left, "book", "HOW TO PLAY", ui.BLUE, func() -> void: _open("howto"))
	_icon_button(left, "star", "BLESSINGS", ui.ORANGE, func() -> void: _open("blessings"))
	_icon_button(left, "ghost", "ALMANAC", ui.VIOLET, func() -> void: _open("almanac"))
	if OS.has_feature("pc") and not OS.has_feature("web"):
		_icon_button(left, "door", "QUIT", ui.RED, func() -> void: get_tree().quit())

	# Bottom row: big round buttons, PLAY in the middle
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -6
	add_child(row)
	_big_button(row, "", "HEROES", ui.PINK, 96, func() -> void: _open("heroes"), "ninja")
	_big_button(row, "trophy", "TROPHIES", ui.VIOLET, 96, func() -> void: _open("achievements"))
	_big_button(row, "bag", "STORE", Color(0.16, 0.68, 0.86), 96, func() -> void: _open("store"))
	_big_button(row, "play", "PLAY", ui.GREEN, 128, func() -> void: ui.show_map_select())
	daily_btn = _big_button(row, "calendar", "DAILY", ui.ORANGE, 96, func() -> void: game.start_daily())
	_big_button(row, "chart", "STATS", ui.BLUE, 96, func() -> void: _open("stats"))

	# Right side: today's quests
	var qp: PanelContainer = ui.panel_of(Color(0.075, 0.1, 0.19, 0.9), 18)
	qp.anchor_left = 1.0
	qp.anchor_right = 1.0
	qp.anchor_top = 0.5
	qp.anchor_bottom = 0.5
	qp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	qp.grow_vertical = Control.GROW_DIRECTION_BOTH
	qp.offset_right = -14
	qp.offset_top = -40
	qp.custom_minimum_size = Vector2(300, 0)
	add_child(qp)
	quest_box = VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 6)
	qp.add_child(quest_box)

	# Continue a saved game, just above PLAY
	continue_btn = ui.btn("CONTINUE", ui.ORANGE, 18, 16)
	continue_btn.anchor_left = 0.5
	continue_btn.anchor_right = 0.5
	continue_btn.anchor_top = 1.0
	continue_btn.anchor_bottom = 1.0
	continue_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	continue_btn.offset_bottom = -186
	continue_btn.custom_minimum_size = Vector2(300, 46)
	continue_btn.icon = Icons.tex("play", Color.WHITE, 40)
	continue_btn.add_theme_constant_override("icon_max_width", 20)
	continue_btn.pressed.connect(func() -> void: game.continue_run())
	add_child(continue_btn)

	tip_lbl = ui.lbl("", 15, Color.WHITE, 6)
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.anchor_left = 0.0
	tip_lbl.anchor_right = 1.0
	tip_lbl.offset_top = 92
	tip_lbl.offset_bottom = 116
	add_child(tip_lbl)
	_next_tip()

func _pill(parent: Control, icon: String, col: Color) -> Label:
	var p: PanelContainer = ui.panel_of(Color(0.075, 0.1, 0.19, 0.9), 20)
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(UIScript.HudIcon.new(icon, 30, col))
	var l: Label = ui.lbl("0", 22, Color.WHITE, 8)
	h.add_child(l)
	return l

func _icon_column(left_side: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.offset_top = -20
	if left_side:
		v.offset_left = 16
	else:
		v.anchor_left = 1.0
		v.anchor_right = 1.0
		v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		v.offset_right = -16
	add_child(v)
	return v

func _icon_button(parent: Control, icon: String, text: String, bg: Color, cb: Callable) -> Button:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", -2)
	parent.add_child(cell)
	var b: Button = ui.round_btn(bg, 64)
	b.tooltip_text = text
	ui.centered(b, UIScript.HudIcon.new(icon, 42, Color.WHITE))
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(b)
	var l: Label = ui.lbl(text, 13, Color.WHITE, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(l)
	return b

func _big_button(parent: Control, icon: String, text: String, bg: Color, px: int, cb: Callable, portrait_key: String = "") -> Button:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", -4)
	cell.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(cell)
	var b: Button = ui.round_btn(bg, px)
	b.add_theme_stylebox_override("normal", ui.sb(bg, px / 2, 4))
	b.add_theme_stylebox_override("hover", ui.sb(bg.lightened(0.15), px / 2, 4))
	if portrait_key != "":
		ui.centered(b, ui._portrait_rect(portrait_key, px * 0.85))
	else:
		ui.centered(b, UIScript.HudIcon.new(icon, px * 0.62, Color.WHITE))
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(b)
	var l: Label = ui.lbl(text, 22 if px > 100 else 18, Color.WHITE, 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(l)
	b.set_meta("label", l)
	return b

func _next_tip() -> void:
	tip_lbl.text = TIPS[tip_i % TIPS.size()]
	tip_i += 1

## Refresh level, daily challenge and achievement counts.
func refresh() -> void:
	var p = game.progress
	level_lbl.text = str(p.level())
	title_lbl.text = p.title()
	var lp: Vector2 = p.level_progress()
	xp_bar.max_value = lp.y
	xp_bar.value = lp.x
	xp_lbl.text = "%d / %d XP" % [int(lp.x), int(lp.y)]
	var d: Dictionary = p.daily()
	var m: Dictionary = Maps.MAPS[d["map"]]
	daily_btn.tooltip_text = "DAILY CHALLENGE\n%s - %s - %s%s" % [m["name"], String(d["diff"]).capitalize(), game.MODES[d["mode"]]["name"], "\n(completed today)" if d["done"] else ""]
	(daily_btn.get_meta("label") as Label).text = "DAILY - DONE" if d["done"] else "DAILY - NEW!"
	trophy_pill.text = "%d/%d" % [p.unlocked_count(), Progress.ACHIEVEMENTS.size()]
	var medals := 0
	for i in range(Maps.MAPS.size()):
		for dd in ["easy", "normal", "hard", "nightmare"]:
			if game.has_medal(i, dd, "standard"):
				medals += 1
	medal_pill.text = str(medals)
	gem_pill.text = _num(p.gems())
	var run: Dictionary = game.saved_run()
	continue_btn.visible = not run.is_empty()
	if not run.is_empty():
		continue_btn.text = "CONTINUE  -  ROUND %d  -  %s" % [int(run["round"]) + 1, String(Maps.MAPS[int(run["map"])]["name"]).to_upper()]
	_fill_quests()

func _fill_quests() -> void:
	_clear(quest_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	quest_box.add_child(head)
	head.add_child(UIScript.HudIcon.new("scroll", 26, Color(1, 0.93, 0.75)))
	head.add_child(ui.lbl("DAILY QUESTS", 18, Color.WHITE, 6))
	var qs: Array = game.progress.quests()
	for q in qs:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		quest_box.add_child(row)
		var top := HBoxContainer.new()
		row.add_child(top)
		var t: Label = ui.lbl(q["text"], 14, Color.WHITE if not q["claimed"] else Color(0.6, 0.7, 0.8), 5)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		var reward: Label = ui.lbl("%d" % int(q["gems"]), 14, ui.GEM, 5)
		top.add_child(reward)
		top.add_child(UIScript.HudIcon.new("gem", 18, ui.GEM))
		var bot := HBoxContainer.new()
		bot.add_theme_constant_override("separation", 6)
		row.add_child(bot)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = q["need"]
		bar.value = q["have"]
		bar.add_theme_stylebox_override("background", ui.sb(Color(1, 1, 1, 0.12), 7, 0, false, 0))
		bar.add_theme_stylebox_override("fill", ui.sb(ui.GREEN if q["done"] else Color(0.3, 0.75, 1.0), 7, 2, false, 0))
		bot.add_child(bar)
		if q["claimed"]:
			bot.add_child(ui.lbl("DONE", 14, ui.GREEN, 5))
		elif q["done"]:
			var b: Button = ui.btn("CLAIM", ui.GREEN, 14, 8)
			b.custom_minimum_size = Vector2(70, 26)
			var idx: int = q["index"]
			b.pressed.connect(func() -> void:
				if game.progress.claim_quest(idx):
					game.sfx.play("quest")
					game.save.save(game.SAVE_PATH)
					refresh())
			bot.add_child(b)
		else:
			bot.add_child(ui.lbl("%s/%s" % [_num(q["have"]), _num(q["need"])], 13, Color(0.8, 0.88, 1.0), 5))
	var gift: Button = ui.btn("DAILY GIFT" + ("  - NEW!" if game.progress.login_available() else ""), ui.GREEN if game.progress.login_available() else ui.BLUE, 14, 10)
	gift.custom_minimum_size = Vector2(0, 32)
	gift.icon = Icons.tex("gem", Color.WHITE, 32)
	gift.add_theme_constant_override("icon_max_width", 16)
	gift.pressed.connect(func() -> void: _open("login"))
	quest_box.add_child(gift)

const SPIRIT_NOTES := {
	"pink": "The weakest spirit. Every bigger spirit hides one inside.",
	"blue": "A little faster than Pink.",
	"green": "Quicker still.",
	"gold": "Very fast. Place heroes where the path enters.",
	"violet": "The fastest of the plain wisps.",
	"shadow": "Shrugs off explosions. Splits into two Violets.",
	"frost": "Cannot be frozen. Splits into two Violets.",
	"kitsune": "A nimble fox with three tails. Takes 2 hits, then splits into two Violets.",
	"crane": "Folded paper that glides by at top speed, carrying a Fox Spirit.",
	"prism": "Shimmers in every colour. Holds a Shadow and a Frost wisp.",
	"lantern": "A paper lantern that sharp attacks cannot pierce. Use magic, blasts or cold.",
	"mask": "A tough clay mask that takes many hits. Heroes with mask bonus damage shine here.",
	"oni": "Boss: a huge red demon with 320 health that releases four masks.",
	"shogun": "Boss: an armoured warlord with 650 health. Releases two Oni Lords and two Lanterns.",
	"dragon": "Final boss: a long storm dragon with 1,100 health that releases four Oni Lords.",
}

func _fill_login(result: Dictionary = {}) -> void:
	var body := _body("login")
	_clear(body)
	var p = game.progress
	var today: int = p.login_day() if result.is_empty() else int(result["day"])
	var claimed: bool = not p.login_available()
	var info: Label = ui.lbl("Come back every day for a gift. Keep the streak going for bigger rewards: day 6 and day 7 include a Hero Charm. Missing a day starts the streak again.", 15, Color(0.76, 0.81, 0.94), 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(940, 0)
	body.add_child(info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	for i in range(p.LOGIN_REWARDS.size()):
		var r: Array = p.LOGIN_REWARDS[i]
		var done: bool = i < today or (i == today and claimed)
		var is_today: bool = i == today
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _glow_box(ui.SURFACE.lightened(0.12) if is_today else ui.SURFACE, ui.GOLD if is_today else (ui.GREEN if done else Color(1, 1, 1, 0.1))))
		card.custom_minimum_size = Vector2(124, 190)
		row.add_child(card)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var d: Label = ui.lbl("DAY %d" % (i + 1), 20, Color.WHITE, 7)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
		var icon := CenterContainer.new()
		icon.custom_minimum_size = Vector2(0, 64)
		icon.add_child(UIScript.HudIcon.new("scroll" if r[1] and int(r[0]) == 0 else "gem", 54, Color(1, 0.95, 0.8) if r[1] and int(r[0]) == 0 else ui.GEM))
		v.add_child(icon)
		var parts: Array = []
		if int(r[0]) > 0:
			parts.append("%d GEMS" % int(r[0]))
		if r[1]:
			parts.append("+ CHARM" if int(r[0]) > 0 else "HERO CHARM")
		var t: Label = ui.lbl("\n".join(parts), 14, ui.GOLD, 5)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		if done:
			var ok: Label = ui.lbl("CLAIMED", 13, ui.GREEN, 5)
			ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(ok)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(bottom)
	if not result.is_empty():
		var txt := "You got %d Spirit Gems" % int(result["gems"]) if int(result["gems"]) > 0 else "You got"
		if String(result["charm"]) != "":
			var c: Dictionary = p.parse_charm(result["charm"])
			txt += "%s a Hero Charm: %s %s" % [" and" if int(result["gems"]) > 0 else "", Defs.HEROES[c["hero"]]["name"], game.charm_label(result["charm"])]
		bottom.add_child(ui.lbl(txt + "!", 22, Color.WHITE, 8))
	elif claimed:
		bottom.add_child(ui.lbl("Today's gift is claimed. See you tomorrow!", 20, Color.WHITE, 8))
	else:
		var b: Button = ui.btn("CLAIM DAY %d" % (today + 1), ui.GREEN, 26, 16)
		b.custom_minimum_size = Vector2(280, 60)
		b.pressed.connect(func() -> void:
			var res: Dictionary = game.progress.claim_login(Defs.HERO_ORDER)
			if res.is_empty():
				return
			game.sfx.play("quest")
			game.save.save(game.SAVE_PATH)
			_fill_login(res)
			refresh())
		bottom.add_child(b)

func _fill_blessings() -> void:
	var body := _body("blessings")
	_clear(body)
	var p = game.progress
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	top.add_child(UIScript.HudIcon.new("star", 40, ui.GOLD))
	var pts: Label = ui.lbl("%d BLESSING POINT%s" % [p.blessing_points(), "" if p.blessing_points() == 1 else "S"], 26, Color.WHITE, 8)
	pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pts)
	var rs: Button = ui.btn("RESET (FREE)", ui.GREY, 16, 10)
	rs.custom_minimum_size = Vector2(160, 40)
	rs.pressed.connect(func() -> void:
		game.progress.reset_blessings()
		game.save.save(game.SAVE_PATH)
		_fill_blessings())
	top.add_child(rs)
	var info: Label = ui.lbl("You earn a point every time you level up. Blessings last forever and work in every mode except Sandbox.", 14, Color(0.76, 0.81, 0.94), 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(940, 0)
	body.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for b in p.BLESSINGS:
		var id: String = b[0]
		var owned: bool = p.has_blessing(id)
		var block: String = p.blessing_blocker(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _glow_box(ui.SURFACE if not owned else ui.SURFACE.lightened(0.12), ui.GOLD if owned else (ui.GREEN if block == "" else Color(1, 1, 1, 0.1))))
		card.custom_minimum_size = Vector2(305, 92)
		grid.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		card.add_child(h)
		var disc := PanelContainer.new()
		disc.add_theme_stylebox_override("panel", ui.sb(ui.GOLD if owned else ui.GREY, 24, 3, false, 6))
		disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		disc.add_child(_icon_rect(b[5], 34))
		h.add_child(disc)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(ui.lbl(b[1], 17, Color.WHITE, 6))
		var d: Label = ui.lbl(b[2], 12, Color(0.76, 0.81, 0.94), 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(170, 0)
		v.add_child(d)
		if owned:
			v.add_child(ui.lbl("BLESSED", 13, ui.GOLD, 4))
		else:
			var buy: Button = ui.btn("%d PT" % int(b[3]) if block == "" else block, ui.GREEN if block == "" else ui.GREY, 13, 8)
			buy.disabled = block != ""
			buy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			buy.pressed.connect(func() -> void:
				if game.progress.buy_blessing(id):
					game.sfx.play("upgrade")
					game.save.save(game.SAVE_PATH)
					_fill_blessings())
			v.add_child(buy)

func _fill_almanac() -> void:
	var body := _body("almanac")
	_clear(body)
	var p = game.progress
	var info: Label = ui.lbl("Pop a spirit once to add it to the almanac (%d / %d found)." % [int(p.get_stat("#spirits_seen")), Defs.ORDER.size()], 15, Color(0.76, 0.81, 0.94), 0)
	body.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	var seen: Array = p.save.get_value("sets", "spirits_seen", [])
	for k in Defs.ORDER:
		var key: String = k
		var d: Dictionary = Defs.ENEMIES[key]
		var known: bool = seen.has(key)
		var col: Color = Color(1, 0.6, 0.9) if d.get("rainbow", false) else Defs.col(d["color"])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _glow_box(ui.SURFACE, col if known else Color(1, 1, 1, 0.1)))
		card.custom_minimum_size = Vector2(305, 130)
		grid.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		card.add_child(h)
		var pic := TextureRect.new()
		pic.texture = ui.spirit_portrait(key)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(96, 96)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not known:
			pic.modulate = Color(0, 0, 0, 0.85)
		h.add_child(pic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(ui.lbl(String(d["name"]).to_upper() if known else "???", 18, Color.WHITE, 6))
		var traits: Array = []
		if d.has("immune"):
			traits.append("immune to %s" % d["immune"])
		if d.get("boss", false):
			traits.append("BOSS")
		v.add_child(ui.lbl("Speed %.1f  -  Health %s  -  Layers %s" % [float(d["speed"]), _num(d["hp"]), _num(Defs.rbe(key))], 12, ui.GOLD, 4))
		var note: Label = ui.lbl(SPIRIT_NOTES.get(key, "") if known else "Not met yet.", 12, Color(0.76, 0.81, 0.94), 0)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(185, 0)
		v.add_child(note)
		if known and d.get("boss", false):
			v.add_child(ui.lbl("Defeated: %s" % _num(p.get_stat(key + "_pops")), 12, ui.GREEN, 4))

func _fill_store() -> void:
	var body := _body("store")
	_clear(body)
	var p = game.progress
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	body.add_child(top)
	top.add_child(UIScript.HudIcon.new("gem", 34, ui.GEM))
	top.add_child(ui.lbl("%s Spirit Gems" % _num(p.gems()), 26, Color.WHITE, 8))
	var info: Label = ui.lbl("Earn gems by winning games, finishing daily quests, unlocking achievements and levelling up. Up to %d powers can be used per game." % game.power_limit(), 14, Color(0.76, 0.81, 0.94), 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(940, 0)
	body.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for pw in p.POWERS:
		var id: String = pw[0]
		var col: Color = Defs.col(pw[5])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _glow_box(ui.SURFACE, col))
		card.custom_minimum_size = Vector2(305, 190)
		grid.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		var disc := PanelContainer.new()
		disc.add_theme_stylebox_override("panel", ui.sb(col.darkened(0.1), 30, 3, false, 6))
		disc.add_child(_icon_rect(pw[3], 48))
		h.add_child(disc)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		h.add_child(nv)
		nv.add_child(ui.lbl(pw[1], 22, Color.WHITE, 8))
		nv.add_child(ui.lbl("Owned: %d" % p.power_count(id), 15, ui.GOLD, 5))
		var d: Label = ui.lbl(pw[2], 14, Color(0.76, 0.81, 0.94), 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(280, 40)
		v.add_child(d)
		var buy: Button = ui.btn("BUY  %d" % int(pw[4]), ui.GREEN if p.gems() >= int(pw[4]) else ui.GREY, 18, 10)
		buy.icon = Icons.tex("gem", Color.WHITE, 40)
		buy.add_theme_constant_override("icon_max_width", 20)
		buy.custom_minimum_size = Vector2(0, 40)
		buy.pressed.connect(func() -> void:
			if game.progress.buy_power(id):
				game.sfx.play("upgrade")
				game.save.save(game.SAVE_PATH)
				_fill_store()
				refresh()
			else:
				game.sfx.play("error"))
		v.add_child(buy)
	# Hero Charms
	var ch_card := PanelContainer.new()
	ch_card.add_theme_stylebox_override("panel", _glow_box(ui.SURFACE, ui.GOLD))
	body.add_child(ch_card)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 14)
	ch_card.add_child(ch)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", ui.sb(Color(0.95, 0.7, 0.2), 30, 3, false, 8))
	disc.add_child(UIScript.HudIcon.new("scroll", 48, Color(1, 0.95, 0.8)))
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(disc)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cv)
	cv.add_child(ui.lbl("HERO CHARM  (owned: %d)" % p.charm_count(), 22, Color.WHITE, 8))
	var cd: Label = ui.lbl("A random recruited hero with upgrades already bought (up to tier 4). Place it for free from the charm button in a game. Every win also drops a charm (two on Hard and Nightmare).", 14, Color(0.76, 0.81, 0.94), 0)
	cd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cd.custom_minimum_size = Vector2(600, 0)
	cv.add_child(cd)
	var last_lbl: Label = ui.lbl("", 15, ui.GOLD, 5)
	cv.add_child(last_lbl)
	var cb: Button = ui.btn("BUY  %d" % p.CHARM_PRICE, ui.GREEN if p.gems() >= p.CHARM_PRICE else ui.GREY, 18, 10)
	cb.icon = Icons.tex("gem", Color.WHITE, 40)
	cb.add_theme_constant_override("icon_max_width", 20)
	cb.custom_minimum_size = Vector2(170, 46)
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.pressed.connect(func() -> void:
		var key: String = game.progress.buy_charm(Defs.HERO_ORDER)
		if key == "":
			game.sfx.play("error")
			return
		game.sfx.play("quest")
		game.save.save(game.SAVE_PATH)
		_fill_store()
		refresh()
		var c2: Dictionary = game.progress.parse_charm(key)
		ui.toast("HERO CHARM", "%s %s" % [Defs.HEROES[c2["hero"]]["name"], game.charm_label(key)]))
	ch.add_child(cb)


func show_home() -> void:
	for k in screens:
		(screens[k] as Control).visible = false
	refresh()
	visible = true
	if not login_shown and game.progress.login_available():
		login_shown = true
		_open("login")

# ---------------------------------------------------------------------
# Sub-screens
# ---------------------------------------------------------------------
func _screen(title: String) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.12, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card: PanelContainer = ui.panel_of(Color(0.075, 0.1, 0.19), 22)
	card.custom_minimum_size = Vector2(1000, 600)
	center.add_child(card)
	card.add_child(_night_bg())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t: Label = ui.lbl(title, 44, Color.WHITE, 14)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back: Button = ui.btn("BACK", ui.BLUE, 22, 14)
	back.custom_minimum_size = Vector2(140, 50)
	back.pressed.connect(show_home)
	head.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "Scroll"
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	shade.set_meta("body", body)
	shade.set_meta("card", card)
	return shade

func _body(which: String) -> VBoxContainer:
	return (screens[which] as Control).get_meta("body")

func _open(which: String) -> void:
	for k in screens:
		(screens[k] as Control).visible = k == which
	match which:
		"achievements":
			_fill_achievements()
		"stats":
			_fill_stats()
		"heroes":
			_pick_hero_class(hero_class_i)
		"settings":
			_fill_settings()
		"store":
			_fill_store()
		"almanac":
			_fill_almanac()
		"blessings":
			_fill_blessings()
		"login":
			_fill_login()

func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func _fill_achievements() -> void:
	var body := _body("achievements")
	_clear(body)
	var p = game.progress
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for a in Progress.ACHIEVEMENTS:
		var done: bool = p.is_unlocked(a[0])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ui.sb(ui.SURFACE if done else Color(0.09, 0.11, 0.2), 12, 2, false, 8))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(470, 0)
		grid.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var star := PanelContainer.new()
		star.custom_minimum_size = Vector2(40, 40)
		star.add_theme_stylebox_override("panel", ui.sb(ui.GOLD if done else ui.GREY.darkened(0.3), 20, 3, false, 0))
		h.add_child(star)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		v.add_child(ui.dark_lbl(a[1], 18))
		v.add_child(ui.dark_lbl(a[2], 13))
		var have := minf(p.get_stat(a[3]), float(a[4]))
		h.add_child(ui.dark_lbl("DONE" if done else "%s / %s" % [_num(have), _num(a[4])], 14))

func _fill_stats() -> void:
	var body := _body("stats")
	_clear(body)
	var p = game.progress
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var rows := [["Player level", str(p.level())], ["Total XP", _num(p.xp())], ["Achievements", "%d / %d" % [p.unlocked_count(), Progress.ACHIEVEMENTS.size()]]]
	for s in Progress.STAT_LABELS:
		var v: float = p.get_stat(s[0])
		rows.append([s[1], ("$" if s[0] == "cash_earned" else "") + _num(v)])
	var medals := 0
	for i in range(Maps.MAPS.size()):
		for d in game.DIFF_ORDER:
			for m in game.MODE_ORDER:
				if game.has_medal(i, d, m):
					medals += 1
	rows.append(["Medals earned", str(medals)])
	for r in rows:
		grid.add_child(ui.lbl(r[0], 22, Color.WHITE, 8))
		grid.add_child(ui.lbl(r[1], 22, ui.GOLD, 8))

static func _num(v) -> String:
	var n := int(v)
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# Heroes: portrait list on the left, details and the full upgrade tree on the right.
func _build_heroes() -> Control:
	var sc := _screen("HEROES")
	var body: VBoxContainer = sc.get_meta("body")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for i in range(Defs.CLASSES.size()):
		var c: Dictionary = Defs.CLASSES[i]
		var tb: Button = ui.btn(c["name"], Defs.col(c["color"]).darkened(0.3), 16, 10)
		tb.custom_minimum_size = Vector2(170, 44)
		tb.icon = Icons.tex(Icons.CLASS_ICONS.get(c["id"], "star"), Color.WHITE, 56)
		tb.add_theme_constant_override("icon_max_width", 26)
		tb.pressed.connect(_pick_hero_class.bind(i))
		tabs.add_child(tb)
		hero_tabs.append(tb)
	hero_list = HBoxContainer.new()
	hero_list.add_theme_constant_override("separation", 14)
	hero_list.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(hero_list)
	var hint: Label = ui.lbl("Pick a hero to open their upgrade tree. Pop spirits with a hero to earn their XP.", 15, Color(0.76, 0.81, 0.94), 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hint)
	return sc

func _pick_hero_class(i: int) -> void:
	hero_class_i = i
	for j in range(hero_tabs.size()):
		var col: Color = Defs.col(Defs.CLASSES[j]["color"])
		ui._set_btn_bg(hero_tabs[j], col if j == i else col.darkened(0.45), 10)
	_clear(hero_list)
	for k in Defs.CLASSES[i]["heroes"]:
		var key: String = k
		var d: Dictionary = Defs.HEROES[key]
		var unlocked: bool = game.progress.level() >= int(Defs.UNLOCK_LEVEL[key])
		var b: Button = ui.btn("", ui.SURFACE.lerp(Defs.col(Defs.CLASSES[i]["color"]), 0.22) if unlocked else Color(0.1, 0.12, 0.22), 14, 18)
		b.custom_minimum_size = Vector2(220 if Defs.CLASSES[i]["heroes"].size() < 5 else 190, 380)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		var pic: TextureRect = ui._portrait_rect(key, 190)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not unlocked:
			pic.modulate = Color(0.2, 0.2, 0.3)
		v.add_child(pic)
		for line in [[d["name"], 30, Color.WHITE], [d["role"], 16, Color.WHITE], ["LEVEL %d" % int(Defs.UNLOCK_LEVEL[key]) if not unlocked else ("MASTERED" if game.progress.mastered(key) else "XP %s" % _num(game.progress.hero_xp(key))), 16, ui.GOLD], ["%s pops" % _num(game.progress.get_stat("hero_pops_" + key)) if unlocked else "", 13, Color(0.85, 0.9, 1.0)]]:
			var l: Label = ui.lbl(line[0], line[1], line[2], 8)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
		var count := 0
		for p in range(3):
			for t in range(2, 5):
				if game.progress.upgrade_unlocked(key, p, t):
					count += 1
		var prog: Label = ui.lbl("%d / 12 UPGRADES" % count, 14, Color.WHITE, 6)
		prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(prog)
		b.pressed.connect(open_tree.bind(key))
		hero_list.add_child(b)

# ---------------------------------------------------------------------
# Upgrade tree: header with hero XP and arrows, preview on the left,
# 3 paths x 4 tiers of round nodes, and the Mastery node on the right.
# ---------------------------------------------------------------------
func _build_tree() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	root.add_child(_night_bg())
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	outer.add_theme_constant_override("separation", 10)
	root.add_child(outer)
	# Header row
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	var back: Button = ui.btn("", ui.TILE.darkened(0.1), 14, 12)
	back.custom_minimum_size = Vector2(64, 60)
	ui.centered(back, _icon_rect("back", 40))
	back.pressed.connect(func() -> void: _open("heroes"))
	head.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var arrow_l: Button = ui.btn("", ui.GOLD, 14, 12)
	arrow_l.custom_minimum_size = Vector2(54, 60)
	ui.centered(arrow_l, _icon_rect("left", 36))
	arrow_l.pressed.connect(func() -> void: _step_hero(-1))
	head.add_child(arrow_l)
	var banner: PanelContainer = ui.panel_of(ui.SURFACE, 16)
	banner.custom_minimum_size = Vector2(620, 0)
	head.add_child(banner)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	banner.add_child(bv)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 16)
	bv.add_child(bh)
	tree_title = ui.lbl("", 30, Color.WHITE, 10)
	bh.add_child(tree_title)
	tree_xp = ui.lbl("", 22, ui.GREEN, 8)
	bh.add_child(tree_xp)
	tree_desc = ui.lbl("", 14, Color.WHITE, 0)
	tree_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(tree_desc)
	var arrow_r: Button = ui.btn("", ui.GOLD, 14, 12)
	arrow_r.custom_minimum_size = Vector2(54, 60)
	ui.centered(arrow_r, _icon_rect("right", 36))
	arrow_r.pressed.connect(func() -> void: _step_hero(1))
	head.add_child(arrow_r)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer2)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(64, 0)
	head.add_child(pad)
	# Body: preview | grid | mastery
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	tree_preview = VBoxContainer.new()
	tree_preview.custom_minimum_size = Vector2(250, 0)
	tree_preview.add_theme_constant_override("separation", 6)
	body.add_child(tree_preview)
	tree_grid = VBoxContainer.new()
	tree_grid.add_theme_constant_override("separation", 6)
	tree_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tree_grid)
	tree_mastery = PanelContainer.new()
	tree_mastery.custom_minimum_size = Vector2(170, 0)
	tree_mastery.add_theme_stylebox_override("panel", _glow_box(Color(0.2, 0.17, 0.42), ui.GOLD))
	body.add_child(tree_mastery)
	return root

func _night_bg() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.13, 0.17, 0.33))
	g.set_color(1, Color(0.065, 0.085, 0.17))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _glow_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(12)
	s.anti_aliasing_size = 1.2
	s.shadow_color = Color(border, 0.22)
	s.shadow_size = 8
	return s

func _icon_rect(icon: String, px: int, col: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Icons.tex(icon, col, px * 2)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func open_tree(k: String) -> void:
	tree_hero = k
	tree_sel = Vector2i(0, 1)
	for s in screens:
		(screens[s] as Control).visible = s == "tree"
	_fill_tree()

func _step_hero(dir: int) -> void:
	var order: Array = Defs.HERO_ORDER
	var i := (order.find(tree_hero) + dir + order.size()) % order.size()
	open_tree(order[i])

## State of one node: "owned" (unlocked), "available" (affordable now), "locked".
func _node_state(k: String, p: int, t: int) -> String:
	var prog = game.progress
	if prog.upgrade_unlocked(k, p, t):
		return "owned"
	if prog.unlock_blocker(k, p, t) == "":
		return "available"
	return "locked"

func _fill_tree() -> void:
	var k := tree_hero
	var d: Dictionary = Defs.HEROES[k]
	var cls_col: Color = Defs.col(Defs.hero_class(k)["color"])
	tree_title.text = "%s  -  %s" % [String(d["name"]).to_upper(), String(d["role"]).to_upper()]
	tree_xp.text = "XP: %s" % _num(game.progress.hero_xp(k))
	tree_desc.text = d["desc"]
	_clear(tree_grid)
	for p in range(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		tree_grid.add_child(row)
		var path_lbl: Label = ui.lbl(String(d["path_names"][p]).to_upper(), 14, ui.GOLD, 6)
		path_lbl.custom_minimum_size = Vector2(96, 0)
		path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		path_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(path_lbl)
		for t in range(1, 5):
			if t > 1:
				var bar := ColorRect.new()
				bar.custom_minimum_size = Vector2(26, 8)
				bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				bar.color = ui.GOLD if _node_state(k, p, t) == "owned" else Color(1, 1, 1, 0.14)
				bar.position.y = -14
				row.add_child(bar)
			row.add_child(_tree_node(k, p, t, cls_col))
	# Mastery column
	_clear(tree_mastery)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", 6)
	tree_mastery.add_child(mv)
	var mt: Label = ui.lbl("MASTERY", 22, ui.GOLD, 8)
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(mt)
	var mastered: bool = game.progress.mastered(k)
	var mb: Button = ui.round_btn(ui.GOLD if mastered else ui.SURFACE.lightened(0.12), 120)
	mb.add_theme_stylebox_override("normal", _glow_box(ui.GOLD if mastered else ui.SURFACE.lightened(0.12), ui.GOLD))
	(mb.get_theme_stylebox("normal") as StyleBoxFlat).set_corner_radius_all(60)
	ui.centered(mb, _icon_rect("star", 70, Color.WHITE if mastered else Color(1, 0.85, 0.4)))
	mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mb.pressed.connect(func() -> void:
		tree_sel = Vector2i(-1, 0)
		_fill_preview())
	mv.add_child(mb)
	var ml: Label = ui.lbl("MASTERED" if mastered else "%s XP" % _num(Progress.MASTERY_COST), 16, Color.WHITE, 6)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(ml)
	var md: Label = ui.lbl("Faster attacks, +1 damage and pierce, and a golden crown in every game.", 12, Color(0.95, 0.9, 1.0), 0)
	md.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	md.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(md)
	_fill_preview()

func _tree_node(k: String, p: int, t: int, cls_col: Color) -> Control:
	var d: Dictionary = Defs.HEROES[k]
	var up: Array = d["paths"][p][t - 1]
	var state := _node_state(k, p, t)
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(118, 0)
	cell.add_theme_constant_override("separation", 0)
	var bg: Color = cls_col if state == "owned" else (Color(0.18, 0.2, 0.42) if state == "available" else Color(0.1, 0.12, 0.22))
	var b: Button = ui.round_btn(bg, 84)
	var st: StyleBoxFlat = ui.sb(bg, 42, 4)
	if state == "available":
		st.border_color = ui.GOLD
		st.set_border_width_all(5)
	if tree_sel == Vector2i(p, t):
		st.shadow_color = Color(1, 1, 1, 0.8)
		st.shadow_size = 10
		st.shadow_offset = Vector2.ZERO
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	var icon := _icon_rect(Icons.for_upgrade(up[3]), 46, Color.WHITE if state != "locked" else Color(1, 1, 1, 0.35))
	ui.centered(b, icon)
	if state == "locked":
		var lk := _icon_rect("lock", 22, Color(1, 1, 1, 0.9))
		lk.position = Vector2(58, 58)
		b.add_child(lk)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		tree_sel = Vector2i(p, t)
		_fill_tree())
	cell.add_child(b)
	var name_lbl: Label = ui.lbl(up[0], 13, Color.WHITE, 5)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(112, 34)
	cell.add_child(name_lbl)
	return cell

func _fill_preview() -> void:
	_clear(tree_preview)
	var k := tree_hero
	var d: Dictionary = Defs.HEROES[k]
	var mastery := tree_sel.x < 0
	var title: String
	var desc: String
	var icon: String
	var status: String
	var can := false
	var cost_txt := ""
	if mastery:
		title = "MASTERY"
		desc = "The final node: this hero attacks 15% faster with +1 damage and pierce in every game, and wears a golden crown."
		icon = "star"
		var block: String = game.progress.mastery_blocker(k)
		status = "MASTERED" if game.progress.mastered(k) else (block if block != "" else "AVAILABLE")
		can = block == ""
		cost_txt = "%s XP" % _num(Progress.MASTERY_COST)
	else:
		var up: Array = d["paths"][tree_sel.x][tree_sel.y - 1]
		title = String(up[0]).to_upper()
		desc = up[2]
		icon = Icons.for_upgrade(up[3])
		var state := _node_state(k, tree_sel.x, tree_sel.y)
		status = {"owned": "UNLOCKED", "available": "AVAILABLE"}.get(state, String(game.progress.unlock_blocker(k, tree_sel.x, tree_sel.y)).to_upper())
		can = state == "available"
		cost_txt = "%d XP" % int(Progress.UNLOCK_COST[tree_sel.y])
		desc += "\nIn-game cost: $%d" % int(up[1])
	var t: Label = ui.lbl(title, 24, Color.WHITE, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tree_preview.add_child(t)
	var big := PanelContainer.new()
	big.custom_minimum_size = Vector2(200, 200)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	big.add_theme_stylebox_override("panel", _glow_box(Defs.col(Defs.hero_class(k)["color"]).darkened(0.2), ui.GOLD if mastery else Color(1, 1, 1, 0.14)))
	var stack := Control.new()
	big.add_child(stack)
	var pic: TextureRect = ui._portrait_rect(k, 180)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(pic)
	var ic := _icon_rect(icon, 70)
	ic.position = Vector2(120, 110)
	stack.add_child(ic)
	tree_preview.add_child(big)
	var s: Label = ui.lbl(status, 18, ui.GREEN if status in ["UNLOCKED", "MASTERED", "AVAILABLE"] else ui.GOLD, 6)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tree_preview.add_child(s)
	var dl: Label = ui.lbl(desc, 14, Color(0.82, 0.86, 0.96), 0)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tree_preview.add_child(dl)
	if status not in ["UNLOCKED", "MASTERED"]:
		var ub: Button = ui.btn("UNLOCK  %s" % cost_txt, ui.GREEN if can else ui.GREY, 18, 14)
		ub.disabled = not can
		ub.pressed.connect(_unlock_selected)
		tree_preview.add_child(ub)
	_fill_skins(k)

## Skin swatches under the preview: tap an owned one to wear it, or buy one with gems.
func _fill_skins(k: String) -> void:
	var p = game.progress
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 6)
	tree_preview.add_child(head)
	head.add_child(_icon_rect("shirt", 20))
	head.add_child(ui.lbl("SKIN: %s" % String(p.SKINS[p.skin(k)][0]).to_upper(), 15, Color.WHITE, 5))
	skin_row = HBoxContainer.new()
	skin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skin_row.add_theme_constant_override("separation", 8)
	tree_preview.add_child(skin_row)
	for i in range(p.SKINS.size()):
		var sk: Array = p.SKINS[i]
		var owned: bool = p.skin_owned(k, i)
		var col: Color = Defs.col(sk[1]) if int(sk[1]) != 0 else Defs.col(Defs.hero_class(k)["color"])
		var b: Button = ui.round_btn(col, 46)
		var worn: bool = p.skin(k) == i
		b.add_theme_stylebox_override("normal", ui.sb(col, 23, 4 if worn else 3))
		if worn:
			var st: StyleBoxFlat = ui.sb(col, 23, 4)
			st.border_color = ui.GOLD
			b.add_theme_stylebox_override("normal", st)
		b.tooltip_text = "%s%s" % [sk[0], "" if owned else " - %d gems" % int(sk[2])]
		if not owned:
			var lk := _icon_rect("lock", 22)
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.centered(b, lk)
		var idx := i
		b.pressed.connect(func() -> void:
			if game.progress.skin_owned(k, idx):
				game.progress.select_skin(k, idx)
				game.sfx.play("place")
			elif game.progress.buy_skin(k, idx):
				game.sfx.play("upgrade")
			else:
				game.sfx.play("error")
				return
			game.save.save(game.SAVE_PATH)
			_fill_preview()
			refresh())
		skin_row.add_child(b)

func _unlock_selected() -> void:
	var ok := false
	if tree_sel.x < 0:
		ok = game.unlock_mastery(tree_hero)
	else:
		ok = game.unlock_upgrade(tree_hero, tree_sel.x, tree_sel.y)
	if ok:
		_fill_tree()
		refresh()

func _build_settings() -> Control:
	return _screen("SETTINGS")

func _fill_settings() -> void:
	var body := _body("settings")
	_clear(body)
	var items := [
		["music", "Music", "Background music on the menus and in games."],
		["sound", "Sound effects", "Pops, explosions and jingles."],
		["shake", "Camera shake", "Shake the camera on boss pops and leaks."],
		["shadows", "Shadows", "Turn off for better performance on slow devices."],
		["autostart", "Auto-start rounds", "Start each new game with AUTO switched on."],
	]
	for it in items:
		var key: String = it[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		var on: bool = game.get_setting(key)
		var b: Button = ui.btn("ON" if on else "OFF", ui.GREEN if on else ui.GREY, 22, 14)
		b.custom_minimum_size = Vector2(110, 50)
		b.pressed.connect(_toggle_setting.bind(key))
		row.add_child(b)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		row.add_child(v)
		v.add_child(ui.lbl(it[1], 24, Color.WHITE, 8))
		v.add_child(ui.lbl(it[2], 14, Color(0.8, 0.9, 1.0), 0))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 30)
	body.add_child(sep)
	var reset: Button = ui.btn("RESET ALL PROGRESS", ui.RED, 20, 14)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(_on_reset.bind(reset))
	body.add_child(reset)

func _toggle_setting(key: String) -> void:
	game.set_setting(key, not game.get_setting(key))
	_fill_settings()

func _on_reset(b: Button) -> void:
	if b.text == "TAP AGAIN TO CONFIRM":
		game.reset_progress()
		show_home()
	else:
		b.text = "TAP AGAIN TO CONFIRM"

func _build_howto() -> Control:
	var sc := _screen("HOW TO PLAY")
	var body: VBoxContainer = sc.get_meta("body")
	var lines := [
		["Goal", "Spirits march along the stone track toward the shrine. Pop them before they arrive. Each one that gets through costs lives."],
		["Heroes", "Pick a hero from the shop (1-5 picks a class, Z X C V B a hero) and click on grass to place them. Click a hero to upgrade, change targeting or sell."],
		["Upgrades", "Each hero has 3 upgrade paths with 4 tiers. You can upgrade two paths, and only one of them past tier 2."],
		["Abilities", "Reaching tier 3 on any path unlocks a hero ability. Use it from the bar at the bottom or with Q W E R T Y U I."],
		["Spirits", "Spirits are layered: popping one reveals the next. Veiled spirits need detection, fortified spirits have double health and regrowing spirits heal if left alone."],
		["Rounds", "Press PLAY (or Space) to send the next round. Press it again to speed up. AUTO starts rounds by itself."],
		["Camera", "Drag to rotate, right-drag to pan, wheel or pinch to zoom. Esc or P pauses."],
		["Farms", "Komugi the rice farmer grows coin bundles during each round. Tap them to collect, or upgrade her Market path to collect them automatically."],
		["Spirit Gems", "Gems come from wins, achievements, levelling up and daily quests. Spend them in the Store on powers (up to 3 per game) or on hero skins in the upgrade tree."],
		["Daily quests", "Three new quests appear every day on the home screen. Claim each one for gems and XP."],
		["Progress", "Earn XP, medals and achievements. Try a new daily challenge every day."],
	]
	for l in lines:
		body.add_child(ui.lbl(l[0], 24, ui.GOLD, 8))
		var t: Label = ui.lbl(l[1], 16, Color.WHITE, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(t)
	var tut: Button = ui.btn("PLAY THE TUTORIAL", ui.GREEN, 20, 14)
	tut.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tut.pressed.connect(func() -> void:
		game.save.set_value("settings", "tutorial_seen", false)
		game.new_game("easy", 0, "standard"))
	body.add_child(tut)
	return sc

## Narrower cards on phones held upright.
func layout(portrait: bool) -> void:
	for k in screens:
		var card: PanelContainer = (screens[k] as Control).get_meta("card")
		card.custom_minimum_size = Vector2(680, 1000) if portrait else Vector2(1000, 600)
