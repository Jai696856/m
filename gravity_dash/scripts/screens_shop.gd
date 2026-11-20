extends RefCounted

const Levels = preload("res://scripts/levels.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Skins = preload("res://scripts/skins.gd")
const Tile = preload("res://scripts/ui/tile.gd")
const Widget = preload("res://scripts/ui/widgets.gd")
const Synth = preload("res://scripts/synth.gd")
const FONT = preload("res://fonts/Fredoka-Bold.ttf")

var m
var kit_tab:= "icon"
var color_slot:= "c1"
var tiles: Array = []
var preview
var info: Label
var shop_id:= "bazaar"

func _init(main) -> void:
	m = main

func show_icons() -> void:
	var root: Control = m.new_screen("icons")
	m.frame(root, "Icon Kit", m.show_menu, Color("ff9ae6"))
	tiles.clear()
	var center: CenterContainer = m.center_box(root, 70.0)
	var hb:= HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	center.add_child(hb)
	var left:= VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(280, 0)
	hb.add_child(left)
	preview = Widget.new()
	preview.kind = "preview"
	preview.custom_minimum_size = Vector2(280, 210)
	left.add_child(preview)
	left.add_child(m.label(str(Catalog.ICONS[Save.icon()].name), 32))
	info = m.label("Pick a look. Locked items say how to get them.", 19, Color(1, 1, 1, 0.75), 6)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(280, 100)
	left.add_child(info)
	if Save.has_extra("glow"):
		var g = m.button("round", Color("ffd34d") if Save.data.skin.get("glow", false) else Color("4a4a5a"), "", "Glow: " + ("on" if Save.data.skin.get("glow", false) else "off"), Vector2(200, 50), func ():
			Save.set_skin("glow", not Save.data.skin.get("glow", false))
			m.go(show_icons))
		g.font_size = 20
		left.add_child(g)

	var right:= VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	hb.add_child(right)
	var tabs:= HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for t in [["icon", "Icons"], ["c1", "Colour 1"], ["c2", "Colour 2"], ["trail", "Trails"], ["death", "Crashes"], ["theme", "Music"]]:
		var key: String = t[0]
		var b = m.button("round", Color("ff7ad9") if kit_tab == key else Color("4a4a5a"), "", str(t[1]), Vector2(118, 48), func ():
			kit_tab = key
			m.go(show_icons))
		b.font_size = 19
		tabs.add_child(b)
	var pnl: PanelContainer = m.panel(Vector2(0, 0))
	right.add_child(pnl)
	var sc:= ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 410)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	var grid:= GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var kind:= "color" if kit_tab in ["c1", "c2"] else kit_tab
	var side:= 76.0
	if kind in ["trail", "death", "theme"]:
		grid.columns = 6
		side = 116.0
	var l: Array = Catalog.list(kind)
	for i in l.size():
		var tl = Tile.new()
		tl.item(kind, i, _pick, side)
		if kind == "color":
			tl.selected = Save.skin(kit_tab) == i
		grid.add_child(tl)
		tiles.append(tl)

func _pick(kind: String, idx: int) -> void:
	if not Save.owns(kind, idx):
		info.text = "Locked\n" + Save.how_to_get(kind, idx)
		Audio.sfx("deny")
		return
	var key: String = kit_tab if kind == "color" else kind
	Save.set_skin(key, idx)
	Audio.sfx("click")
	for tl in tiles:
		if kind == "color":
			tl.selected = tl.idx == idx
		tl.queue_redraw()
	preview.pop = 1.0
	info.text = str(Catalog.list(kind)[idx].get("name", ""))
	if kind == "theme":
		Audio.play_menu()

func show_market() -> void:
	var root: Control = m.new_screen("market")
	m.frame(root, "The Market", m.show_menu, Color("b9a6ff"))
	var center: CenterContainer = m.center_box(root, 70.0)
	var v:= VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var grid:= HBoxContainer.new()
	grid.add_theme_constant_override("separation", 22)
	v.add_child(grid)
	var note: Label = m.label("Earn shards by beating levels, picking up shards, quests and chests. Secret coins give prisms.", 20, Color(1, 1, 1, 0.75), 6)
	for i in Catalog.SHOPS.size():
		var s: Dictionary = Catalog.SHOPS[i]
		var open:= Save.shop_open(s)
		var col:= v_column(s, i, open)
		var id: String = s.id
		var unlock_text: String = s.unlock.get("text", "")
		var tl = Tile.new()
		var on_click:= func ():
			if open:
				shop_id = id
				m.go(show_shop)
			else:
				note.text = unlock_text
		tl.hub("shop", str(s.name), Color.from_hsv(float(s.hue), 0.55, 0.85), not open, on_click, 200.0)
		col.add_child(tl)
		grid.add_child(col)
	v.add_child(note)
	if Save.has_extra("jukebox"):
		v.add_child(m.button("round", Color("5ab0e0"), "music", "Jukebox", Vector2(240, 60), func (): m.go(show_jukebox)))

func v_column(s: Dictionary, i: int, open: bool) -> VBoxContainer:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var k = Widget.new()
	k.kind = "keeper"
	k.idx = i
	k.custom_minimum_size = Vector2(200, 150)
	k.modulate = Color.WHITE if open else Color(0.4, 0.4, 0.45)
	col.add_child(k)
	col.add_child(m.label(str(s.keeper), 22, Color(1, 1, 1, 0.8), 6))
	return col

func show_shop() -> void:
	var s: Dictionary = Catalog.shop(shop_id)
	var root: Control = m.new_screen("shop")
	m.frame(root, str(s.name), show_market, Color.from_hsv(float(s.hue), 0.45, 1.0))
	var center: CenterContainer = m.center_box(root, 70.0)
	var hb:= HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	center.add_child(hb)
	var left:= VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 6)
	hb.add_child(left)
	var k = Widget.new()
	k.kind = "keeper"
	k.idx = Catalog.SHOPS.find(s)
	k.custom_minimum_size = Vector2(260, 220)
	left.add_child(k)
	var say: Label = m.label(str(s.greet[randi() % s.greet.size()]), 21, Color.WHITE, 6)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.custom_minimum_size = Vector2(260, 90)
	left.add_child(say)
	left.add_child(m.label("- " + str(s.keeper), 18, Color(1, 1, 1, 0.6), 5))
	var pnl: PanelContainer = m.panel(Vector2(0, 0))
	hb.add_child(pnl)
	var sc:= ScrollContainer.new()
	sc.custom_minimum_size = Vector2(740, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	var grid:= GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	for it in Catalog.shop_items(shop_id):
		var cell:= VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var tl = Tile.new()
		tl.item(it.kind, it.idx, func (kind, idx): _buy(kind, idx, say), 128.0)
		cell.add_child(tl)
		var nm: String = it.item.get("name", "Colour")
		cell.add_child(m.label(nm + ("" if it.kind != "extra" else ""), 17, Color.WHITE, 5))
		grid.add_child(cell)

func _buy(kind: String, idx: int, say: Label) -> void:
	if Save.owns(kind, idx):
		say.text = "You already own that. Equip it in the Icon Kit." if kind != "extra" else "Already yours."
		Audio.sfx("click")
		return
	var src: Dictionary = Catalog.list(kind)[idx].src
	if Save.buy(kind, idx):
		Audio.sfx("buy")
		var item: Dictionary = Catalog.list(kind)[idx]
		say.text = "Pleasure doing business! %s is yours." % item.get("name", "That colour")
		if kind == "extra":
			say.text += " " + str(item.desc) + "."
		m.go(show_shop)
	else:
		Audio.sfx("deny")
		var have:= Save.shards() if src.cur == "shards" else Save.prisms()
		say.text = "You need %d more %s for that." % [int(src.price) - have, src.cur]

func show_jukebox() -> void:
	var root: Control = m.new_screen("jukebox")
	m.frame(root, "Jukebox", show_market, Color("5ab0e0"))
	var center: CenterContainer = m.center_box(root, 90.0)
	var pnl: PanelContainer = m.panel(Vector2(0, 0))
	center.add_child(pnl)
	var sc:= ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	var v:= VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	var entries:= []
	for i in Catalog.THEMES.size():
		entries.append(["theme:%d" % i, "Menu: " + str(Catalog.THEMES[i].name), Synth.GENRE_NAMES[int(Catalog.THEMES[i].genre)]])
	for i in Levels.main_count():
		var p:= Levels.main_params(i)
		entries.append([p.key, str(p.name), "%s, %d bpm" % [Synth.GENRE_NAMES[int(p.genre)], int(p.bpm)]])
	for e in entries:
		var h:= HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var key: String = e[0]
		h.add_child(m.button("round", Color("8ee53f"), "play", "", Vector2(56, 44), func (): Audio.play(key, true)))
		var l: Label = m.label("%s   (%s)" % [e[1], e[2]], 21, Color.WHITE, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		h.add_child(l)
		v.add_child(h)

func show_achievements() -> void:
	var root: Control = m.new_screen("achievements")
	m.frame(root, "Achievements", m.show_menu, Color("ffd34d"))
	var center: CenterContainer = m.center_box(root, 80.0)
	var pnl: PanelContainer = m.panel(Vector2(0, 0))
	center.add_child(pnl)
	var sc:= ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	var grid:= GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	var got:= 0
	for i in Catalog.ACHIEVEMENTS.size():
		var a: Array = Catalog.ACHIEVEMENTS[i]
		var done:= Save.claimed("ach:%d" % i)
		if done:
			got += 1
		var h:= HBoxContainer.new()
		h.custom_minimum_size = Vector2(430, 0)
		h.add_theme_constant_override("separation", 10)
		var medal = Widget.new()
		medal.kind = "progress"
		medal.value = int(100.0 * minf(1.0, Save.stat(a[2]) / float(a[3])))
		medal.color = Color("ffd34d") if done else Color("5ab0e0")
		medal.custom_minimum_size = Vector2(150, 26)
		var txt:= VBoxContainer.new()
		var t1: Label = m.label(str(a[0]) + ("  +%d" % int(a[4])), 21, Color("ffd34d") if done else Color.WHITE, 6)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var t2: Label = m.label(str(a[1]), 16, Color(1, 1, 1, 0.65), 4)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		txt.add_child(t1)
		txt.add_child(t2)
		txt.custom_minimum_size = Vector2(260, 0)
		h.add_child(txt)
		h.add_child(medal)
		grid.add_child(h)
	var count: Label = m.label("%d / %d unlocked" % [got, Catalog.ACHIEVEMENTS.size()], 22, Color(1, 1, 1, 0.8), 6)
	root.add_child(count)
	m.pin(count, Control.PRESET_CENTER_BOTTOM, 14)

func show_stats() -> void:
	var root: Control = m.new_screen("stats")
	m.frame(root, "Statistics", m.show_menu, Color("ffc46b"))
	var center: CenterContainer = m.center_box(root, 80.0)
	var hb:= HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	center.add_child(hb)
	var left: PanelContainer = m.panel(Vector2(440, 0))
	hb.add_child(left)
	var rows:= VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	left.add_child(rows)
	var attempts:= Save.stat("attempts")
	var flips:= Save.stat("flips")
	var data:= [
		["Attempts", m.fmt(attempts)],
		["Gravity flips", m.fmt(flips)],
		["Crashes", m.fmt(Save.stat("deaths"))],
		["Main levels done", "%d / %d" % [int(Save.stat("completions")), Levels.main_count()]],
		["Stars", m.fmt(Save.stat("stars"))],
		["Secret coins", m.fmt(Save.stat("coins"))],
		["Shards earned", m.fmt(Save.stat("shards_earned"))],
		["Prisms earned", m.fmt(Save.stat("prisms_earned"))],
		["Dailies / weeklies", "%d / %d" % [int(Save.stat("dailies")), int(Save.stat("weeklies"))]],
		["Orbs / pads / portals", "%s / %s / %s" % [m.fmt(Save.stat("orbs")), m.fmt(Save.stat("pads")), m.fmt(Save.stat("portals"))]],
		["First-try clears", m.fmt(Save.stat("perfect"))],
		["Time played", m.fmt_time(Save.stat("time"))],
		["Distance", m.fmt(Save.stat("distance")) + " blocks"],
		["Flips per attempt", "%.1f" % (flips / maxf(1.0, attempts))],
		["Icons owned", "%d / %d" % [Save.count_owned("icon"), Catalog.ICONS.size()]],
	]
	for row in data:
		var h:= HBoxContainer.new()
		rows.add_child(h)
		var n: Label = m.label(str(row[0]), 20, Color(1, 1, 1, 0.72), 5)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var v: Label = m.label(str(row[1]), 22, Color.WHITE, 6)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
	var right: PanelContainer = m.panel(Vector2(0, 0))
	hb.add_child(right)
	var sc:= ScrollContainer.new()
	sc.custom_minimum_size = Vector2(530, 480)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	var list:= VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	for i in Levels.main_count():
		var r = Widget.new()
		r.kind = "row"
		r.lv = { "p": Levels.main_params(i) }
		r.custom_minimum_size = Vector2(510, 40)
		list.add_child(r)
