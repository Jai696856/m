# Player progression: lifetime stats, XP and levels, achievements, and the
# daily challenge. Everything is stored in the game's save ConfigFile.
extends RefCounted

const Maps = preload("res://scripts/maps.gd")

## [id, name, description, stat, target]. Stats starting with "#" count the
## entries of a saved set (e.g. distinct maps won).
const ACHIEVEMENTS := [
	["first_pop", "First Pop", "Pop your very first spirit.", "pops", 1],
	["pops_1k", "Pop Star", "Pop 1,000 spirits.", "pops", 1000],
	["pops_10k", "Spirit Sweeper", "Pop 10,000 spirits.", "pops", 10000],
	["pops_100k", "Purifier", "Pop 100,000 spirits.", "pops", 100000],
	["first_win", "Guardian of the Gate", "Win your first game.", "wins", 1],
	["wins_10", "Shrine Keeper", "Win 10 games.", "wins", 10],
	["wins_50", "Eternal Watch", "Win 50 games.", "wins", 50],
	["hard_win", "Hard as Stone", "Win a game on Hard.", "hard_wins", 1],
	["perfect", "Flawless", "Win without losing a single life.", "perfect_wins", 1],
	["tier_beginner", "First Steps", "Win on a Beginner map.", "won_tier_beginner", 1],
	["tier_intermediate", "Getting Serious", "Win on an Intermediate map.", "won_tier_intermediate", 1],
	["tier_advanced", "Advanced Tactics", "Win on an Advanced map.", "won_tier_advanced", 1],
	["tier_expert", "Expert Exorcist", "Win on an Expert map.", "won_tier_expert", 1],
	["modes_3", "Versatile", "Win in 3 different game modes.", "#modes_won", 3],
	["modes_5", "Master of Modes", "Win in all 5 challenge-able modes.", "#modes_won", 5],
	["maps_10", "Explorer", "Win on 10 different maps.", "#maps_won", 10],
	["maps_all", "Cartographer", "Win on every map.", "#maps_won", 46],
	["themes_6", "World Traveler", "Play a map of every theme.", "#themes_played", 6],
	["heroes_50", "Recruiter", "Place 50 heroes.", "heroes_placed", 50],
	["full_squad", "Full Squad", "Have all 7 hero types out in one game.", "squad", 7],
	["tier4", "Max Power", "Buy a tier 4 upgrade.", "tier4", 1],
	["tier4_25", "Overcharged", "Buy 25 tier 4 upgrades.", "tier4", 25],
	["ability_1", "Special Move", "Use a hero ability.", "abilities", 1],
	["ability_100", "Showstopper", "Use 100 hero abilities.", "abilities", 100],
	["oni", "Oni Slayer", "Defeat an Oni Lord.", "oni_pops", 1],
	["dragon", "Dragon Tamer", "Defeat a Storm Dragon.", "dragon_pops", 1],
	["freeplay_50", "Endless Night", "Reach round 50.", "best_round", 50],
	["freeplay_75", "Eternal Guardian", "Reach round 75.", "best_round", 75],
	["rich", "Treasure Hoard", "Earn $100,000 in total.", "cash_earned", 100000],
	["sell_10", "Second Thoughts", "Sell 10 heroes.", "sold", 10],
	["daily", "Daily Devotion", "Win a daily challenge.", "daily_wins", 1],
	["rounds_500", "Marathon", "Survive 500 rounds in total.", "rounds", 500],
	["level_10", "Rising Star", "Reach player level 10.", "level", 10],
	["level_25", "Legend of the Shrine", "Reach player level 25.", "level", 25],
]

const STAT_LABELS := [
	["games", "Games played"], ["wins", "Games won"], ["hard_wins", "Hard wins"], ["perfect_wins", "Flawless wins"],
	["pops", "Spirits popped"], ["oni_pops", "Oni Lords defeated"], ["dragon_pops", "Storm Dragons defeated"],
	["rounds", "Rounds survived"], ["best_round", "Highest round"], ["heroes_placed", "Heroes placed"],
	["upgrades", "Upgrades bought"], ["tier4", "Tier 4 upgrades"], ["abilities", "Abilities used"],
	["sold", "Heroes sold"], ["cash_earned", "Money earned"], ["#maps_won", "Maps conquered"],
	["#themes_played", "Themes explored"], ["daily_wins", "Daily challenges won"],
]

var save: ConfigFile
var on_unlock: Callable = Callable()   # (achievement: Array) -> void
var on_level: Callable = Callable()    # (level: int) -> void

func _init(cfg: ConfigFile) -> void:
	save = cfg

# ---------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------
func get_stat(k: String) -> float:
	if k == "level":
		return float(level())
	if k.begins_with("#"):
		return float((save.get_value("sets", k.substr(1), []) as Array).size())
	return float(save.get_value("stats", k, 0))

func add(k: String, n: float = 1.0, check_now: bool = true) -> void:
	save.set_value("stats", k, get_stat(k) + n)
	if check_now:
		check()

func set_max(k: String, v: float) -> void:
	if v > get_stat(k):
		save.set_value("stats", k, v)
		check()

func add_to_set(k: String, item: String) -> void:
	var arr: Array = save.get_value("sets", k, [])
	if not arr.has(item):
		arr.append(item)
		save.set_value("sets", k, arr)
		check()

# ---------------------------------------------------------------------
# XP and levels: level L -> L+1 needs 150 + 60 * L XP.
# ---------------------------------------------------------------------
func xp() -> float:
	return float(save.get_value("progress", "xp", 0.0))

static func xp_for_level(lv: int) -> float:
	return 150.0 + 60.0 * lv

func level() -> int:
	var total := xp()
	var lv := 1
	while total >= xp_for_level(lv):
		total -= xp_for_level(lv)
		lv += 1
	return lv

## Progress inside the current level: Vector2(have, need).
func level_progress() -> Vector2:
	var total := xp()
	var lv := 1
	while total >= xp_for_level(lv):
		total -= xp_for_level(lv)
		lv += 1
	return Vector2(total, xp_for_level(lv))

func add_xp(n: float) -> void:
	if n <= 0.0:
		return
	var before := level()
	save.set_value("progress", "xp", xp() + n)
	var after := level()
	if after > before:
		if on_level.is_valid():
			on_level.call(after)
		check()

# ---------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------
func is_unlocked(id: String) -> bool:
	return bool(save.get_value("achievements", id, false))

func unlocked_count() -> int:
	var n := 0
	for a in ACHIEVEMENTS:
		if is_unlocked(a[0]):
			n += 1
	return n

func check() -> void:
	for a in ACHIEVEMENTS:
		if is_unlocked(a[0]):
			continue
		if get_stat(a[3]) >= float(a[4]):
			save.set_value("achievements", a[0], true)
			add_xp(100.0)
			if on_unlock.is_valid():
				on_unlock.call(a)

# ---------------------------------------------------------------------
# Daily challenge: the same map, mode and difficulty for everyone each day.
# ---------------------------------------------------------------------
static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func daily() -> Dictionary:
	var key := today_key()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var modes := ["standard", "half_cash", "fortified", "rush"]
	var diffs := ["normal", "hard"]
	return {
		"key": key,
		"map": rng.randi() % Maps.MAPS.size(),
		"mode": modes[rng.randi() % modes.size()],
		"diff": diffs[rng.randi() % diffs.size()],
		"done": save.get_value("daily", key, false),
	}

func complete_daily() -> void:
	var key := today_key()
	if not bool(save.get_value("daily", key, false)):
		save.set_value("daily", key, true)
		add("daily_wins")
		add_xp(1000.0)

func reset() -> void:
	for section in ["stats", "sets", "progress", "achievements", "daily", "best", "medals"]:
		if save.has_section(section):
			save.erase_section(section)
