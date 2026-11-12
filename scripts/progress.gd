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
	["nightmare_win", "Nightmare Walker", "Win a game on Nightmare.", "nightmare_wins", 1],
	["perfect", "Flawless", "Win without losing a single life.", "perfect_wins", 1],
	["tier_beginner", "First Steps", "Win on a Beginner map.", "won_tier_beginner", 1],
	["tier_intermediate", "Getting Serious", "Win on an Intermediate map.", "won_tier_intermediate", 1],
	["tier_advanced", "Advanced Tactics", "Win on an Advanced map.", "won_tier_advanced", 1],
	["tier_expert", "Expert Exorcist", "Win on an Expert map.", "won_tier_expert", 1],
	["modes_3", "Versatile", "Win in 3 different game modes.", "#modes_won", 3],
	["modes_5", "Master of Modes", "Win in 5 different game modes.", "#modes_won", 5],
	["modes_7", "Mode Legend", "Win in all 7 challenge modes.", "#modes_won", 7],
	["maps_10", "Explorer", "Win on 10 different maps.", "#maps_won", 10],
	["maps_all", "Cartographer", "Win on every map.", "#maps_won", 46],
	["almanac", "Spirit Scholar", "Fill the Spirit Almanac: pop every kind of spirit.", "#spirits_seen", 15],
	["themes_6", "World Traveler", "Play a map of every theme.", "#themes_played", 6],
	["heroes_50", "Recruiter", "Place 50 heroes.", "heroes_placed", 50],
	["full_squad", "Full Squad", "Have 7 different heroes out in one game.", "squad", 7],
	["tier4", "Max Power", "Buy a tier 4 upgrade.", "tier4", 1],
	["tier4_25", "Overcharged", "Buy 25 tier 4 upgrades.", "tier4", 25],
	["ability_1", "Special Move", "Use a hero ability.", "abilities", 1],
	["ability_100", "Showstopper", "Use 100 hero abilities.", "abilities", 100],
	["oni", "Oni Slayer", "Defeat an Oni Lord.", "oni_pops", 1],
	["dragon", "Dragon Tamer", "Defeat a Storm Dragon.", "dragon_pops", 1],
	["shogun", "Shogun's Fall", "Defeat a Shadow Shogun.", "shogun_pops", 1],
	["freeplay_50", "Endless Night", "Reach round 50.", "best_round", 50],
	["freeplay_75", "Eternal Guardian", "Reach round 75.", "best_round", 75],
	["rich", "Treasure Hoard", "Earn $100,000 in total.", "cash_earned", 100000],
	["sell_10", "Second Thoughts", "Sell 10 heroes.", "sold", 10],
	["daily", "Daily Devotion", "Win a daily challenge.", "daily_wins", 1],
	["rounds_500", "Marathon", "Survive 500 rounds in total.", "rounds", 500],
	["unlock_1", "Fresh Training", "Unlock a hero upgrade with hero XP.", "unlocks_bought", 1],
	["unlock_30", "Dojo Master", "Unlock 30 hero upgrades.", "unlocks_bought", 30],
	["mastery_1", "True Master", "Master a hero.", "masteries", 1],
	["level_10", "Rising Star", "Reach player level 10.", "level", 10],
	["level_25", "Legend of the Shrine", "Reach player level 25.", "level", 25],
	["crops_1", "Green Thumb", "Collect a coin bundle from a farm.", "crops", 1],
	["crops_500", "Rice Baron", "Collect 500 coin bundles.", "crops", 500],
	["tap_100", "Quick Hands", "Tap 100 coin bundles yourself.", "crops_tapped", 100],
	["power_1", "Divine Help", "Use a power.", "powers_used", 1],
	["power_50", "Power Hungry", "Use 50 powers.", "powers_used", 50],
	["quest_1", "Errand Runner", "Complete a daily quest.", "quests_done", 1],
	["quest_30", "Quest Master", "Complete 30 daily quests.", "quests_done", 30],
	["gems_1k", "Gem Collector", "Earn 1,000 Spirit Gems in total.", "gems_earned", 1000],
	["skin_1", "New Look", "Buy a hero skin.", "skins_bought", 1],
	["skin_10", "Fashion Icon", "Buy 10 hero skins.", "skins_bought", 10],
	["tutorial", "Quick Learner", "Finish the tutorial.", "tutorial_done", 1],
	["pops_1m", "Spirit Legend", "Pop 1,000,000 spirits.", "pops", 1000000],
	["wins_100", "Living Legend", "Win 100 games.", "wins", 100],
	["freeplay_100", "Beyond Eternity", "Reach round 100.", "best_round", 100],
	["masteries_5", "Grand Master", "Master 5 heroes.", "masteries", 5],
]

const STAT_LABELS := [
	["games", "Games played"], ["wins", "Games won"], ["hard_wins", "Hard wins"], ["nightmare_wins", "Nightmare wins"], ["perfect_wins", "Flawless wins"],
	["pops", "Spirits popped"], ["oni_pops", "Oni Lords defeated"], ["shogun_pops", "Shadow Shoguns defeated"], ["dragon_pops", "Storm Dragons defeated"],
	["rounds", "Rounds survived"], ["best_round", "Highest round"], ["heroes_placed", "Heroes placed"],
	["upgrades", "Upgrades bought"], ["tier4", "Tier 4 upgrades"], ["abilities", "Abilities used"],
	["sold", "Heroes sold"], ["cash_earned", "Money earned"], ["#maps_won", "Maps conquered"],
	["#themes_played", "Themes explored"], ["daily_wins", "Daily challenges won"], ["unlocks_bought", "Upgrades unlocked"],
	["crops", "Coin bundles collected"], ["powers_used", "Powers used"], ["quests_done", "Quests completed"],
	["gems_earned", "Spirit Gems earned"], ["skins_bought", "Skins bought"],
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
		add_gems(20 * (after - before))
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
			add_gems(25)
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
		add_gems(100)

# ---------------------------------------------------------------------
# Hero XP and upgrade unlocks. Each hero earns its own XP from its pops and
# from rounds survived; spending it permanently unlocks upgrades, in order.
# Tier 1 of every path is free.
# ---------------------------------------------------------------------
const UNLOCK_COST := [0, 0, 250, 1000, 4000]   # by tier (index 1..4)

func hero_xp(k: String) -> float:
	return float(save.get_value("hero_xp", k, 0.0))

func add_hero_xp(k: String, n: float) -> void:
	if n > 0.0:
		save.set_value("hero_xp", k, hero_xp(k) + n)

func upgrade_unlocked(k: String, path: int, tier: int) -> bool:
	if tier <= 1:
		return true
	return bool(save.get_value("unlocks", "%s|%d|%d" % [k, path, tier], false))

## "" if the upgrade can be unlocked now, otherwise the reason it can't.
func unlock_blocker(k: String, path: int, tier: int) -> String:
	if upgrade_unlocked(k, path, tier):
		return "Unlocked"
	if not upgrade_unlocked(k, path, tier - 1):
		return "Unlock tier %d first" % (tier - 1)
	if hero_xp(k) < UNLOCK_COST[tier]:
		return "Needs %d XP" % UNLOCK_COST[tier]
	return ""

func unlock_upgrade(k: String, path: int, tier: int) -> bool:
	if unlock_blocker(k, path, tier) != "":
		return false
	save.set_value("hero_xp", k, hero_xp(k) - UNLOCK_COST[tier])
	save.set_value("unlocks", "%s|%d|%d" % [k, path, tier], true)
	add("unlocks_bought")
	return true

## Mastery: the final node of each hero's tree. Needs all 12 upgrades unlocked.
const MASTERY_COST := 8000

func mastered(k: String) -> bool:
	return bool(save.get_value("mastery", k, false))

func mastery_blocker(k: String) -> String:
	if mastered(k):
		return "Mastered"
	for p in range(3):
		for t in range(2, 5):
			if not upgrade_unlocked(k, p, t):
				return "Unlock all 12 upgrades first"
	if hero_xp(k) < MASTERY_COST:
		return "Needs %d XP" % MASTERY_COST
	return ""

func unlock_mastery(k: String) -> bool:
	if mastery_blocker(k) != "":
		return false
	save.set_value("hero_xp", k, hero_xp(k) - MASTERY_COST)
	save.set_value("mastery", k, true)
	add("masteries")
	return true

## Test/debug helper: unlock every upgrade of every hero.
func unlock_everything(hero_keys: Array) -> void:
	if xp() < 12000.0:
		save.set_value("progress", "xp", 12000.0)   # player level 18: every hero recruited
	for k in hero_keys:
		for p in range(3):
			for t in range(2, 5):
				save.set_value("unlocks", "%s|%d|%d" % [k, p, t], true)

# ---------------------------------------------------------------------
# Spirit Gems: earned from wins, achievements, level-ups and quests; spent on
# powers and hero skins.
# ---------------------------------------------------------------------
var on_gems: Callable = Callable()   # (amount: int) -> void

func gems() -> int:
	return int(save.get_value("progress", "gems", 0))

func add_gems(n: int) -> void:
	if n <= 0:
		return
	save.set_value("progress", "gems", gems() + n)
	save.set_value("stats", "gems_earned", get_stat("gems_earned") + n)
	if on_gems.is_valid():
		on_gems.call(n)

func spend_gems(n: int) -> bool:
	if gems() < n:
		return false
	save.set_value("progress", "gems", gems() - n)
	return true

## One-shot powers bought with gems and used during a game.
## [id, name, description, icon, price, colour]
const POWERS := [
	["time_stop", "Time Stop", "Freezes every spirit for 6 seconds (bosses 2).", "hourglass", 40, 0x7fd6ff],
	["shrine_bomb", "Shrine Bomb", "Blasts every spirit on the map.", "bomb", 60, 0xff6b5b],
	["cash_drop", "Cash Drop", "Instantly gives $1,500 (works in every mode).", "coin", 35, 0xffd34d],
	["heal", "Healing Charm", "Restores 50 lives.", "heart", 30, 0xff7ac8],
	["battle_cry", "Battle Cry", "Every hero attacks twice as fast for 15 seconds.", "flame", 50, 0xffa53c],
	["golden_touch", "Golden Touch", "Popped spirits give 5x money for 20 seconds.", "crown", 45, 0xffe066],
]

static func power_def(id: String) -> Array:
	for pw in POWERS:
		if pw[0] == id:
			return pw
	return []

func power_count(id: String) -> int:
	return int(save.get_value("powers", id, 0))

func buy_power(id: String) -> bool:
	var pw := power_def(id)
	if pw.is_empty() or not spend_gems(int(pw[4])):
		return false
	save.set_value("powers", id, power_count(id) + 1)
	return true

func take_power(id: String) -> bool:
	if power_count(id) <= 0:
		return false
	save.set_value("powers", id, power_count(id) - 1)
	add("powers_used")
	return true

# ---------------------------------------------------------------------
# Daily quests: three goals a day, measured from the stats at the moment the
# day's quests were first rolled.
# [id, text, stat, target, gems, xp]
# ---------------------------------------------------------------------
const QUEST_POOL := [
	["pop_500", "Pop 500 spirits", "pops", 500, 20, 150],
	["pop_3000", "Pop 3,000 spirits", "pops", 3000, 40, 300],
	["win_1", "Win a game", "wins", 1, 40, 300],
	["rounds_25", "Survive 25 rounds", "rounds", 25, 25, 200],
	["upgrades_15", "Buy 15 upgrades", "upgrades", 15, 20, 150],
	["abilities_5", "Use 5 hero abilities", "abilities", 5, 25, 200],
	["place_20", "Place 20 heroes", "heroes_placed", 20, 20, 150],
	["crops_25", "Collect 25 coin bundles", "crops", 25, 30, 200],
	["earn_25k", "Earn $25,000 in games", "cash_earned", 25000, 30, 250],
	["tier4_1", "Buy a tier 4 upgrade", "tier4", 1, 35, 300],
	["power_2", "Use 2 powers", "powers_used", 2, 15, 100],
	["oni_1", "Defeat an Oni Lord", "oni_pops", 1, 40, 300],
	["hard_win", "Win a game on Hard", "hard_wins", 1, 60, 500],
]
const QUESTS_PER_DAY := 3

func quests() -> Array:
	var key := today_key()
	var rolled: Array = save.get_value("quests", key, [])
	if rolled.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key + "quests")
		var pool := range(QUEST_POOL.size())
		for i in range(QUESTS_PER_DAY):
			var j: int = pool.pop_at(rng.randi() % pool.size())
			var q: Array = QUEST_POOL[j]
			rolled.append({"id": q[0], "base": get_stat(q[2]), "claimed": false})
		# Only today's quests are kept
		if save.has_section("quests"):
			save.erase_section("quests")
		save.set_value("quests", key, rolled)
	var out: Array = []
	for i in range(rolled.size()):
		var r: Dictionary = rolled[i]
		for q in QUEST_POOL:
			if q[0] == r["id"]:
				var have := minf(float(q[3]), get_stat(q[2]) - float(r["base"]))
				out.append({"index": i, "id": q[0], "text": q[1], "have": have, "need": float(q[3]), "gems": int(q[4]), "xp": float(q[5]), "claimed": bool(r["claimed"]), "done": have >= float(q[3])})
	return out

func claim_quest(i: int) -> bool:
	var qs := quests()
	if i < 0 or i >= qs.size():
		return false
	var q: Dictionary = qs[i]
	if q["claimed"] or not q["done"]:
		return false
	var rolled: Array = save.get_value("quests", today_key(), [])
	rolled[i]["claimed"] = true
	save.set_value("quests", today_key(), rolled)
	add_gems(q["gems"])
	add_xp(q["xp"])
	add("quests_done")
	return true

# ---------------------------------------------------------------------
# Hero skins: colour styles bought with gems. Skin 0 is the default look.
# [name, outfit colour (0 = default), price]
# ---------------------------------------------------------------------
const SKINS := [
	["Classic", 0, 0],
	["Sakura", 0xff8fc8, 120],
	["Midnight", 0x2c3570, 200],
	["Golden", 0xf2c230, 400],
]

func skin_owned(k: String, i: int) -> bool:
	return i == 0 or bool(save.get_value("skins", "%s|%d" % [k, i], false))

func buy_skin(k: String, i: int) -> bool:
	if i <= 0 or i >= SKINS.size() or skin_owned(k, i):
		return false
	if not spend_gems(int(SKINS[i][2])):
		return false
	save.set_value("skins", "%s|%d" % [k, i], true)
	add("skins_bought")
	select_skin(k, i)
	return true

func select_skin(k: String, i: int) -> void:
	if skin_owned(k, i):
		save.set_value("skin_sel", k, i)

func skin(k: String) -> int:
	return int(save.get_value("skin_sel", k, 0))

func reset() -> void:
	for section in ["stats", "sets", "progress", "achievements", "daily", "best", "medals", "hero_xp", "unlocks", "mastery", "powers", "quests", "skins", "skin_sel"]:
		if save.has_section(section):
			save.erase_section(section)
