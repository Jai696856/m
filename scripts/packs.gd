# Hero packs: optional local add-ons in res://packs/<name>/pack.gd.
# The packs/ folder is git-ignored and excluded from exports, so a pack only exists on
# the device it was copied to. A pack script extends RefCounted and provides:
#
#   func hero_class() -> Dictionary              {"id", "name", "color"}
#   func heroes() -> Dictionary                  key -> hero definition (same shape as Defs.HEROES),
#                                                plus optional "level" (player level to unlock)
#   func abilities() -> Dictionary               key -> {"name", "cd", "desc"}
#   func build_hero(key: String) -> Dictionary   a model from Models.make_chibi
#   func use_ability(game, hero, stats) -> void  the hero's ability
extends RefCounted

const Defs = preload("res://scripts/defs.gd")
const Models = preload("res://scripts/models.gd")

static var loaded: Array = []

static func load_all(game) -> void:
	if not loaded.is_empty():
		return
	var dir := DirAccess.open("res://packs")
	if dir == null:
		return
	for name in dir.get_directories():
		var path := "res://packs/%s/pack.gd" % name
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		if script == null:
			continue
		var pack = script.new()
		var cls: Dictionary = pack.hero_class()
		var defs: Dictionary = pack.heroes()
		var abil: Dictionary = pack.abilities()
		for key in defs:
			var d: Dictionary = defs[key]
			Defs.register_hero(key, d, cls, int(d.get("level", 1)))
			Models.pack_builders[key] = pack
			if abil.has(key):
				game.ABILITIES[key] = abil[key]
				game.pack_abilities[key] = pack
		loaded.append(pack)
		print("Loaded hero pack: ", name, " (", defs.size(), " heroes)")
