extends RefCounted
## Everything you can own, earn or buy, and everything that hands out rewards.
## An item's "src" says how you get it:
##   {}                                       free
##   {"req": stat, "n": N, "text": ...}       earned by playing
##   {"shop": id, "price": N, "cur": ...}     bought in a shop (cur is "shards" or "prisms")
##   {"trial": i} / {"path": id} / {"code": CODE}

const ICONS := [
	{"name": "Classic", "src": {}},
	{"name": "Smiley", "src": {}},
	{"name": "Diamond", "src": {}},
	{"name": "Visor", "src": {"req": "flips", "n": 100, "text": "Flip gravity 100 times"}},
	{"name": "Ring", "src": {"req": "attempts", "n": 50, "text": "Make 50 attempts"}},
	{"name": "Plus", "src": {"req": "completions", "n": 1, "text": "Complete 1 main level"}},
	{"name": "Checker", "src": {"req": "completions", "n": 3, "text": "Complete 3 main levels"}},
	{"name": "Target", "src": {"req": "flips", "n": 500, "text": "Flip gravity 500 times"}},
	{"name": "Grump", "src": {"req": "deaths", "n": 200, "text": "Crash 200 times"}},
	{"name": "Bolt", "src": {"req": "stars", "n": 15, "text": "Collect 15 stars"}},
	{"name": "Ghost", "src": {"req": "attempts", "n": 300, "text": "Make 300 attempts"}},
	{"name": "Heart", "src": {"req": "perfect", "n": 1, "text": "Beat a level on its first attempt"}},
	{"name": "Star", "src": {"req": "stars", "n": 40, "text": "Collect 40 stars"}},
	{"name": "Split", "src": {"req": "completions", "n": 9, "text": "Complete 9 main levels"}},
	{"name": "Dots", "src": {"req": "flips", "n": 3000, "text": "Flip gravity 3,000 times"}},
	{"name": "Crown", "src": {"req": "completions", "n": 30, "text": "Complete all 30 main levels"}},
	{"name": "Robo", "src": {"shop": "bazaar", "price": 120, "cur": "shards"}},
	{"name": "Cat", "src": {"shop": "bazaar", "price": 150, "cur": "shards"}},
	{"name": "Owl", "src": {"shop": "bazaar", "price": 180, "cur": "shards"}},
	{"name": "Pixel Skull", "src": {"shop": "bazaar", "price": 220, "cur": "shards"}},
	{"name": "Wave", "src": {"shop": "bazaar", "price": 250, "cur": "shards"}},
	{"name": "Gem", "src": {"shop": "bazaar", "price": 280, "cur": "shards"}},
	{"name": "Sun", "src": {"shop": "bazaar", "price": 300, "cur": "shards"}},
	{"name": "Moon", "src": {"shop": "bazaar", "price": 320, "cur": "shards"}},
	{"name": "Leaf", "src": {"shop": "bazaar", "price": 350, "cur": "shards"}},
	{"name": "Cyclops", "src": {"shop": "bazaar", "price": 400, "cur": "shards"}},
	{"name": "Spiral", "src": {"shop": "bazaar", "price": 450, "cur": "shards"}},
	{"name": "Circuit", "src": {"shop": "bazaar", "price": 500, "cur": "shards"}},
	{"name": "Void Eye", "src": {"shop": "vault", "price": 4, "cur": "prisms"}},
	{"name": "Prism", "src": {"shop": "vault", "price": 6, "cur": "prisms"}},
	{"name": "Comet", "src": {"shop": "vault", "price": 8, "cur": "prisms"}},
	{"name": "Crystal King", "src": {"shop": "vault", "price": 12, "cur": "prisms"}},
	{"name": "Sawblade", "src": {"trial": 0}},
	{"name": "Orb Core", "src": {"trial": 1}},
	{"name": "Turbo", "src": {"trial": 2}},
	{"name": "Mini Me", "src": {"trial": 3}},
	{"name": "Flip Master", "src": {"path": "flips"}},
	{"name": "Starborn", "src": {"path": "stars"}},
	{"name": "No Jump", "src": {"code": "NOJUMP"}},
	{"name": "Gold Cube", "src": {"req": "coins", "n": 45, "text": "Collect 45 secret coins"}},
]

const COLORS := [
	{"hex": "ffc94d", "src": {}}, {"hex": "5ce1ff", "src": {}}, {"hex": "ff5c8a", "src": {}},
	{"hex": "7ee04a", "src": {}}, {"hex": "ffffff", "src": {}}, {"hex": "b07aff", "src": {}},
	{"hex": "ff8a3d", "src": {"req": "stars", "n": 3, "text": "Collect 3 stars"}},
	{"hex": "3d6bff", "src": {"req": "stars", "n": 8, "text": "Collect 8 stars"}},
	{"hex": "ff4fd8", "src": {"req": "stars", "n": 15, "text": "Collect 15 stars"}},
	{"hex": "00e0b0", "src": {"req": "stars", "n": 25, "text": "Collect 25 stars"}},
	{"hex": "ffe14d", "src": {"req": "stars", "n": 40, "text": "Collect 40 stars"}},
	{"hex": "ff2e2e", "src": {"req": "stars", "n": 60, "text": "Collect 60 stars"}},
	{"hex": "8a8a99", "src": {"req": "stars", "n": 80, "text": "Collect 80 stars"}},
	{"hex": "2a2a3a", "src": {"req": "stars", "n": 110, "text": "Collect 110 stars"}},
	{"hex": "c0ff3d", "src": {"req": "stars", "n": 140, "text": "Collect 140 stars"}},
	{"hex": "ff9cf5", "src": {"req": "stars", "n": 170, "text": "Collect 170 stars"}},
	{"hex": "ff6b6b", "src": {"shop": "bazaar", "price": 100, "cur": "shards"}},
	{"hex": "4dffa6", "src": {"shop": "bazaar", "price": 120, "cur": "shards"}},
	{"hex": "a0c4ff", "src": {"shop": "bazaar", "price": 140, "cur": "shards"}},
	{"hex": "ffd6a5", "src": {"shop": "bazaar", "price": 160, "cur": "shards"}},
	{"hex": "9b5de5", "src": {"shop": "bazaar", "price": 180, "cur": "shards"}},
	{"hex": "f15bb5", "src": {"shop": "bazaar", "price": 200, "cur": "shards"}},
	{"hex": "00bbf9", "src": {"code": "UPSIDEDOWN"}},
	{"hex": "d4af37", "src": {"shop": "vault", "price": 3, "cur": "prisms"}},
]

const TRAILS := [
	{"name": "No trail", "src": {}},
	{"name": "Squares", "src": {}},
	{"name": "Streak", "src": {}},
	{"name": "Sparkle", "src": {"shop": "studio", "price": 150, "cur": "shards"}},
	{"name": "Rainbow", "src": {"shop": "studio", "price": 400, "cur": "shards"}},
	{"name": "Bubbles", "src": {"shop": "studio", "price": 250, "cur": "shards"}},
	{"name": "Pixels", "src": {"req": "flips", "n": 1000, "text": "Flip gravity 1,000 times"}},
	{"name": "Flames", "src": {"shop": "vault", "price": 8, "cur": "prisms"}},
	{"name": "Comet Dust", "src": {"code": "DASHDASH"}},
]

const DEATHS := [
	{"name": "Burst", "src": {}},
	{"name": "Shatter", "src": {"shop": "studio", "price": 200, "cur": "shards"}},
	{"name": "Shockwave", "src": {"shop": "studio", "price": 150, "cur": "shards"}},
	{"name": "Confetti", "src": {"shop": "studio", "price": 300, "cur": "shards"}},
	{"name": "Pixel Rain", "src": {"req": "deaths", "n": 500, "text": "Crash 500 times"}},
	{"name": "Implode", "src": {"shop": "vault", "price": 6, "cur": "prisms"}},
]

## Menu music styles (the synth's genres): 0 chip, 1 synthwave, 2 breakbeat, 3 house, 4 half-time, 5 ambient
const THEMES := [
	{"name": "Default Drift", "genre": 1, "bpm": 112, "root": 45, "src": {}},
	{"name": "Chip Parade", "genre": 0, "bpm": 128, "root": 48, "src": {"shop": "sound", "price": 200, "cur": "shards"}},
	{"name": "Neon Nights", "genre": 3, "bpm": 122, "root": 41, "src": {"shop": "sound", "price": 250, "cur": "shards"}},
	{"name": "Slow Orbit", "genre": 5, "bpm": 90, "root": 43, "src": {"shop": "sound", "price": 200, "cur": "shards"}},
	{"name": "Break Room", "genre": 2, "bpm": 150, "root": 40, "src": {"shop": "sound", "price": 300, "cur": "shards"}},
	{"name": "Heavy Floor", "genre": 4, "bpm": 140, "root": 38, "src": {"shop": "vault", "price": 5, "cur": "prisms"}},
]

## Extras sold in shops
const EXTRAS := [
	{"id": "glow", "name": "Icon Glow", "desc": "A soft glow around your cube", "src": {"shop": "bazaar", "price": 300, "cur": "shards"}},
	{"id": "jukebox", "name": "Jukebox", "desc": "Listen to every level's song", "src": {"shop": "sound", "price": 150, "cur": "shards"}},
	{"id": "sfx_retro", "name": "Retro Sounds", "desc": "Square-wave flip and crash sounds", "src": {"shop": "sound", "price": 180, "cur": "shards"}},
	{"id": "ghost_gold", "name": "Golden Ghost", "desc": "Your ghost runs in gold", "src": {"shop": "studio", "price": 220, "cur": "shards"}},
]

const SHOPS := [
	{"id": "bazaar", "name": "Cube Bazaar", "keeper": "Boxley", "hue": 0.1,
		"greet": ["Fresh cubes, fresh colours!", "Every cube deserves a new coat.", "Shards in, style out."],
		"unlock": {}},
	{"id": "studio", "name": "Trail Studio", "keeper": "Streak", "hue": 0.85,
		"greet": ["Leave a mark on the sky.", "Crashing is better with style.", "Trails, sparkles, the works."],
		"unlock": {"req": "stars", "n": 10, "text": "Collect 10 stars to open the Trail Studio"}},
	{"id": "sound", "name": "Sound Shack", "keeper": "Woofer", "hue": 0.55,
		"greet": ["Turn it up!", "Every level has a song. I have them all.", "Bass? I've got bass."],
		"unlock": {"req": "completions", "n": 3, "text": "Complete 3 main levels to open the Sound Shack"}},
	{"id": "vault", "name": "Prism Vault", "keeper": "Lumen", "hue": 0.72,
		"greet": ["Prisms only, traveller.", "Rare things for rare players.", "Have you tried the lock on the main menu?"],
		"unlock": {"req": "coins", "n": 15, "text": "Collect 15 secret coins to open the Prism Vault"}},
]

## Secret codes for the lock on the main menu: reward kind, amount or item.
const CODES := {
	"FLIP": {"shards": 100, "text": "+100 shards"},
	"NOJUMP": {"item": "icon:38", "text": "the No Jump icon"},
	"UPSIDEDOWN": {"item": "color:22", "text": "a new colour"},
	"DASHDASH": {"item": "trail:8", "text": "the Comet Dust trail"},
	"GRAVITY": {"prisms": 3, "text": "+3 prisms"},
	"1964": {"shards": 196, "text": "+196 shards"},
	"CEILING": {"shards": 150, "text": "+150 shards"},
}

## name, description, stat, target, shard reward
const ACHIEVEMENTS := [
	["Upside Down", "Flip gravity for the first time", "flips", 1, 10],
	["Flip Fanatic", "Flip 500 times", "flips", 500, 50],
	["Gravity Juggler", "Flip 5,000 times", "flips", 5000, 200],
	["Persistent", "Make 100 attempts", "attempts", 100, 40],
	["Never Quit", "Make 1,000 attempts", "attempts", 1000, 150],
	["Crash Test", "Crash 100 times", "deaths", 100, 30],
	["First Clear", "Complete a main level", "completions", 1, 25],
	["Seasoned", "Complete 10 main levels", "completions", 10, 150],
	["Gravity Master", "Complete all 30 main levels", "completions", 30, 1000],
	["Star Collector", "Collect 25 stars", "stars", 25, 75],
	["Constellation", "Collect 100 stars", "stars", 100, 300],
	["Shiny", "Collect a secret coin", "coins", 1, 20],
	["Coin Hunter", "Collect 30 secret coins", "coins", 30, 200],
	["Treasure Map", "Collect all 90 main-level coins", "coins", 90, 800],
	["Daily Habit", "Beat a daily level", "dailies", 1, 40],
	["Week Streak", "Beat 7 daily levels", "dailies", 7, 150],
	["Weekly Warrior", "Beat a weekly level", "weeklies", 1, 100],
	["Trial by Fire", "Finish a trial", "trials", 1, 150],
	["Champion", "Finish all 4 trials", "trials", 4, 600],
	["Orb Bouncer", "Use 100 gravity orbs", "orbs", 100, 60],
	["Pad Hopper", "Hit 100 gravity pads", "pads", 100, 60],
	["Portal Hopper", "Pass 50 portals", "portals", 50, 40],
	["Treasure Seeker", "Open 10 chests", "chests", 10, 80],
	["Quest Runner", "Finish 10 quests", "quests", 10, 120],
	["Practice Pays", "Finish 5 levels in practice mode", "practice", 5, 50],
	["Flawless", "Beat 3 levels on their first attempt", "perfect", 3, 200],
	["Architect", "Build 3 levels in the Forge", "forge", 3, 60],
	["Codebreaker", "Unlock a secret code", "codes", 1, 50],
	["Big Spender", "Buy 5 shop items", "purchases", 5, 80],
	["Dedicated", "Play for one hour", "time", 3600, 100],
]

## stat, min, max, shards per unit (rounded), text
const QUESTS := [
	["flips", 80, 200, 0.6, "Flip gravity %d times"],
	["attempts", 15, 40, 3.0, "Make %d attempts"],
	["coins", 1, 3, 40.0, "Collect %d secret coins"],
	["clears", 1, 3, 50.0, "Complete %d levels"],
	["orbs", 10, 30, 3.0, "Use %d gravity orbs"],
	["pads", 10, 30, 3.0, "Hit %d gravity pads"],
	["shards_earned", 100, 250, 0.5, "Earn %d shards"],
	["portals", 8, 20, 4.0, "Pass %d portals"],
	["distance", 1500, 4000, 0.04, "Travel %d blocks"],
	["checkpoints", 5, 15, 6.0, "Place %d practice checkpoints"],
]

## Progress paths: a stat with five milestones. The last milestone also gives an icon.
const PATHS := [
	{"id": "flips", "name": "Path of Flips", "stat": "flips", "steps": [100, 500, 1500, 4000, 10000], "hue": 0.12},
	{"id": "stars", "name": "Path of Stars", "stat": "stars", "steps": [10, 30, 60, 100, 150], "hue": 0.15},
	{"id": "coins", "name": "Path of Coins", "stat": "coins", "steps": [5, 15, 30, 60, 90], "hue": 0.1},
	{"id": "explorer", "name": "Path of Days", "stat": "dailies", "steps": [1, 3, 7, 14, 30], "hue": 0.55},
]
const PATH_REWARDS := [100, 200, 400, 700, 1000]


static func list(kind: String) -> Array:
	match kind:
		"icon":
			return ICONS
		"color":
			return COLORS
		"trail":
			return TRAILS
		"death":
			return DEATHS
		"theme":
			return THEMES
		"extra":
			return EXTRAS
	return []


static func shop_items(shop_id: String) -> Array:
	var out := []
	for kind in ["icon", "color", "trail", "death", "theme", "extra"]:
		var l := list(kind)
		for i in l.size():
			var src: Dictionary = l[i].src
			if src.get("shop", "") == shop_id:
				out.append({"kind": kind, "idx": i, "item": l[i], "price": int(src.price), "cur": str(src.cur)})
	out.sort_custom(func(a, b): return a.price < b.price if a.cur == b.cur else a.cur == "shards")
	return out


static func shop(id: String) -> Dictionary:
	for s in SHOPS:
		if s.id == id:
			return s
	return {}
