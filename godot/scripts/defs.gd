# Static game data: spirits (enemies), heroes (towers), and upgrades.
extends RefCounted

static func col(hex: int, alpha: float = 1.0) -> Color:
	var c := Color.hex((hex << 8) | 0xff)
	c.a = alpha
	return c

# ---------------------------------------------------------------------
# Spirits. Popping one releases its "children".
# ---------------------------------------------------------------------
const ORDER := ["pink", "blue", "green", "gold", "violet", "shadow", "frost", "prism", "mask", "oni", "dragon"]

const ENEMIES := {
	"pink":   {"name": "Pink Wisp",    "color": 0xff7eb6, "speed": 1.0, "hp": 1.0,    "children": [],                                 "size": 0.7},
	"blue":   {"name": "Blue Wisp",    "color": 0x4f9bff, "speed": 1.4, "hp": 1.0,    "children": ["pink"],                           "size": 0.77},
	"green":  {"name": "Green Wisp",   "color": 0x55d66b, "speed": 1.8, "hp": 1.0,    "children": ["blue"],                           "size": 0.79},
	"gold":   {"name": "Gold Wisp",    "color": 0xffcf3a, "speed": 3.0, "hp": 1.0,    "children": ["green"],                          "size": 0.77},
	"violet": {"name": "Violet Wisp",  "color": 0xc779ff, "speed": 3.4, "hp": 1.0,    "children": ["gold"],                           "size": 0.74},
	"shadow": {"name": "Shadow Wisp",  "color": 0x2e2547, "speed": 1.8, "hp": 1.0,    "children": ["violet", "violet"],               "size": 0.61, "immune": "blast"},
	"frost":  {"name": "Frost Wisp",   "color": 0xeaf7ff, "speed": 2.0, "hp": 1.0,    "children": ["violet", "violet"],               "size": 0.61, "immune": "cold"},
	"prism":  {"name": "Prism Wisp",   "color": 0xffffff, "speed": 2.2, "hp": 1.0,    "children": ["shadow", "frost"],                "size": 0.84, "rainbow": true},
	"mask":   {"name": "Clay Mask",    "color": 0xd9a46a, "speed": 2.5, "hp": 10.0,   "children": ["prism", "prism"],                 "size": 1.05, "mask": true},
	"oni":    {"name": "ONI LORD",     "color": 0xe53935, "speed": 1.2, "hp": 320.0,  "children": ["mask", "mask", "mask", "mask"],   "size": 1.9, "boss": true},
	"dragon": {"name": "STORM DRAGON", "color": 0x26a69a, "speed": 0.6, "hp": 1100.0, "children": ["oni", "oni", "oni", "oni"],       "size": 2.2, "boss": true, "segments": 7},
}

static var _rbe := {}

# "Red Bloon Equivalent": total layers inside a spirit (lives lost if it leaks).
static func rbe(k: String) -> float:
	if _rbe.has(k):
		return _rbe[k]
	var d: Dictionary = ENEMIES[k]
	var total: float = d["hp"]
	for c in d["children"]:
		total += rbe(c)
	_rbe[k] = total
	return total

static func rank(k: String) -> int:
	return ORDER.find(k)

# ---------------------------------------------------------------------
# Heroes. Upgrade effects are data: {"key": add, "key*": multiply, "key=": set}.
# Dotted keys reach into nested dictionaries (e.g. "explode.r").
# ---------------------------------------------------------------------
const HERO_ORDER := ["ninja", "miko", "mage", "ice", "samurai", "mecha", "idol"]

const HEROES := {
	"ninja": {
		"name": "Kaede", "role": "Kunoichi", "cost": 340,
		"desc": "Fast shuriken thrower. Can see veiled spirits.",
		"base": {"kind": "proj", "range": 8.0, "rate": 0.75, "dmg": 1.0, "pierce": 2, "type": "sharp", "proj_speed": 30.0, "count": 1, "spread": 0.22, "camo": true, "proj": "shuriken"},
		"path_names": ["Blades", "Swiftness", "Shadow Arts"],
		"paths": [
			[["Razor Stars", 150, "+2 pierce per shuriken.", {"pierce": 2}],
			["Twin Toss", 300, "Throws 2 shuriken at once.", {"count=": 2}],
			["Flash Bomb Tags", 900, "Every 3rd throw is an exploding tag that stuns spirits.", {"flash_every=": 3}],
			["Grandmaster Shinobi", 4500, "Throws 5 heavy shuriken: +2 damage, +4 pierce, much faster.", {"count=": 5, "rate*": 0.5, "dmg": 2.0, "pierce": 4, "spread=": 0.5}]],
			[["Quick Hands", 200, "Throws 20% faster.", {"rate*": 0.8}],
			["Ninja Discipline", 350, "Throws faster and sees further.", {"rate*": 0.75, "range": 1.5}],
			["Shadow Step", 1600, "Doubles attack speed. Shuriken fly faster.", {"rate*": 0.5, "proj_speed": 15.0}],
			["Thousand Cuts", 8000, "Insane speed and +3 damage.", {"rate*": 0.33, "dmg": 3.0}]],
			[["Seeking Stars", 250, "Shuriken home in on spirits.", {"homing=": true}],
			["Kage Clone", 500, "+1 shuriken per throw.", {"count": 1}],
			["Spirit Sapper", 1200, "Deals 3x damage to bosses.", {"boss_mul=": 3.0}],
			["Shadow Legion", 6000, "+4 shuriken, +3 pierce, 6x boss damage.", {"count": 4, "pierce": 3, "boss_mul=": 6.0, "spread=": 0.6}]],
		],
	},
	"miko": {
		"name": "Hana", "role": "Shrine Maiden", "cost": 400,
		"desc": "Long-range sacred arrows. Strong single target.",
		"base": {"kind": "proj", "range": 13.0, "rate": 1.1, "dmg": 2.0, "pierce": 2, "type": "sharp", "proj_speed": 48.0, "count": 1, "spread": 0.1, "camo": false, "proj": "arrow"},
		"path_names": ["Sacred Arrows", "Eagle Eye", "Talismans"],
		"paths": [
			[["Blessed Tips", 250, "+1 damage, +1 vs Clay Masks.", {"dmg": 1.0, "mask_bonus": 1.0}],
			["Purifying Shot", 600, "+2 damage. Arrows become magic and hit any spirit.", {"dmg": 2.0, "type=": "magic"}],
			["Exorcist Bolt", 2200, "+6 damage, +5 vs masks, 2x boss damage.", {"dmg": 6.0, "mask_bonus": 5.0, "boss_mul=": 2.0}],
			["Goddess Arrow", 9000, "+20 damage, +6 pierce, 4x boss damage.", {"dmg": 20.0, "pierce": 6, "boss_mul=": 4.0}]],
			[["Far Sight", 150, "+3 range.", {"range": 3.0}],
			["Spirit Sense", 350, "Can see veiled spirits.", {"camo=": true}],
			["Rapid Draw", 1500, "Shoots twice as fast.", {"rate*": 0.5}],
			["Heaven's Rain", 7000, "Fires a fan of 6 arrows, even faster.", {"count=": 6, "spread=": 0.9, "rate*": 0.6}]],
			[["Paper Seal", 300, "+3 pierce.", {"pierce": 3}],
			["Binding Seal", 700, "Arrows slow spirits by 50%.", {"slow=": 0.5, "slow_dur=": 1.5}],
			["Sealing Barrier", 2500, "Arrows briefly stun spirits. +5 pierce.", {"stun=": 0.5, "pierce": 5}],
			["Grand Seal", 11000, "Stuns bosses too. +5 damage.", {"stun_boss=": true, "stun=": 0.6, "dmg": 5.0}]],
		],
	},
	"mage": {
		"name": "Rin", "role": "Blast Mage", "cost": 550,
		"desc": "Casts exploding fireballs. Cannot harm Shadow Wisps.",
		"base": {"kind": "proj", "range": 9.5, "rate": 1.4, "dmg": 1.0, "pierce": 1, "type": "blast", "proj_speed": 22.0, "count": 1, "spread": 0.3, "camo": false, "proj": "fireball", "explode": {"r": 2.0, "pierce": 14, "cluster": 0}},
		"path_names": ["Big Boom", "Rapid Cast", "Meteor"],
		"paths": [
			[["Larger Blast", 350, "Bigger explosions that hit more spirits.", {"explode.r": 0.8, "explode.pierce": 8}],
			["Heavy Charge", 650, "+1 damage, +10 blast pierce.", {"dmg": 1.0, "explode.pierce": 10}],
			["EXPLOSION!!", 2800, "Huge blasts: +3 damage, +30 pierce.", {"explode.r": 1.5, "dmg": 3.0, "explode.pierce": 30}],
			["Supernova", 12000, "Colossal blasts: +10 damage, 2x boss damage.", {"explode.r": 2.5, "dmg": 10.0, "explode.pierce": 60, "boss_mul=": 2.0}]],
			[["Quick Chant", 250, "Casts 25% faster.", {"rate*": 0.75}],
			["Double Cast", 700, "Casts 2 fireballs.", {"count=": 2}],
			["Cluster Fire", 2200, "Explosions split into 6 bomblets.", {"explode.cluster=": 6}],
			["Inferno Barrage", 9500, "Rapid triple fireballs.", {"rate*": 0.4, "count": 1}]],
			[["Far Cast", 200, "+2 range.", {"range": 2.0}],
			["Mask Crusher", 900, "+3 damage vs Clay Masks.", {"mask_bonus": 3.0}],
			["Meteor Strike", 3500, "4x boss damage, +4 damage.", {"boss_mul=": 4.0, "dmg": 4.0}],
			["Armageddon", 16000, "10x boss damage, +10 damage, stuns everything hit.", {"boss_mul=": 10.0, "dmg": 10.0, "stun=": 0.8, "stun_boss=": true}]],
		],
	},
	"ice": {
		"name": "Yuki", "role": "Ice Princess", "cost": 450,
		"desc": "Freezes nearby spirits in place. Frost Wisps are immune.",
		"base": {"kind": "pulse", "range": 4.5, "rate": 2.2, "dmg": 0.0, "pierce": 40, "type": "cold", "freeze": 1.0, "camo": false},
		"path_names": ["Deep Freeze", "Permafrost", "Frost Magic"],
		"paths": [
			[["Chill", 200, "Freezes 40% longer.", {"freeze": 0.4}],
			["Ice Shards", 600, "Pulses deal 1 damage.", {"dmg": 1.0}],
			["Absolute Zero", 2500, "Longer freeze, +2 damage, +40 pierce.", {"freeze": 1.0, "dmg": 2.0, "pierce": 40}],
			["Eternal Winter", 10000, "Freezes bosses too. +5 damage.", {"stun_boss=": true, "dmg": 5.0}]],
			[["Lingering Cold", 150, "Spirits stay slowed after thawing.", {"slow=": 0.55, "slow_dur=": 2.0}],
			["Wider Aura", 350, "+1.5 range.", {"range": 1.5}],
			["Snow Queen Aura", 2000, "Permanently slows everything in range, bosses included.", {"aura_slow=": 0.6}],
			["Glacial Domain", 8000, "+3 range, pulses twice as often.", {"range": 3.0, "rate*": 0.5}]],
			[["Frost Sight", 300, "Can see veiled spirits.", {"camo=": true}],
			["Quick Pulse", 500, "Pulses 25% faster.", {"rate*": 0.75}],
			["Frostbreaker", 1800, "Ice becomes magic: can freeze Frost Wisps.", {"type=": "magic"}],
			["Avalanche", 7500, "+4 damage, +6 vs masks.", {"dmg": 4.0, "mask_bonus": 6.0}]],
		],
	},
	"samurai": {
		"name": "Takeshi", "role": "Samurai", "cost": 600,
		"desc": "Close-range sweeping slashes that cut many spirits.",
		"base": {"kind": "slash", "range": 4.6, "rate": 0.9, "dmg": 2.0, "pierce": 6, "type": "sharp", "camo": false},
		"path_names": ["Blade", "Reach", "Spirit"],
		"paths": [
			[["Honed Edge", 300, "+1 damage.", {"dmg": 1.0}],
			["Twin Katana", 800, "+6 pierce, 15% faster.", {"pierce": 6, "rate*": 0.85}],
			["Iaido Master", 3000, "+4 damage, +4 vs masks.", {"dmg": 4.0, "mask_bonus": 4.0}],
			["Blade Saint", 13000, "+12 damage, +10 pierce, 3x boss damage.", {"dmg": 12.0, "pierce": 10, "boss_mul=": 3.0}]],
			[["Long Stride", 200, "+1 range.", {"range": 1.0}],
			["Wind Slash", 750, "Each swing also sends a flying wind blade.", {"wave=": {"dmg": 1.0, "pierce": 8, "speed": 18.0}}],
			["Crescent Moon", 2400, "Wind blades: +20 pierce, +3 damage.", {"wave.pierce": 20, "wave.dmg": 3.0}],
			["Storm God", 10000, "Swings 2.5x faster, +2 range.", {"rate*": 0.4, "range": 2.0}]],
			[["Mind's Eye", 250, "Can see veiled spirits.", {"camo=": true}],
			["Battle Cry", 900, "Swings 20% faster.", {"rate*": 0.8}],
			["Demon Slayer", 3200, "4x damage to bosses.", {"boss_mul=": 4.0}],
			["Shogun", 15000, "+8 damage, +10 pierce, much faster.", {"dmg": 8.0, "pierce": 10, "rate*": 0.6}]],
		],
	},
	"mecha": {
		"name": "Mika", "role": "Mecha Pilot", "cost": 900,
		"desc": "Rapid-fire energy beam that pierces through a line of spirits.",
		"base": {"kind": "beam", "range": 11.0, "rate": 0.28, "dmg": 1.0, "pierce": 3, "type": "magic", "count": 1, "width": 0.5, "camo": false},
		"path_names": ["Overcharge", "Targeting", "Rockets"],
		"paths": [
			[["Hot Plasma", 400, "+1 damage.", {"dmg": 1.0}],
			["Ion Beam", 1100, "+5 pierce.", {"pierce": 5}],
			["Hyper Beam", 4000, "+4 damage, wider beam.", {"dmg": 4.0, "width=": 1.0}],
			["Giga Drill Laser", 18000, "+10 damage, +20 pierce, 3x boss damage.", {"dmg": 10.0, "pierce": 20, "boss_mul=": 3.0, "width=": 1.5}]],
			[["Scanner Visor", 300, "Can see veiled spirits.", {"camo=": true}],
			["Long Barrel", 600, "+3 range.", {"range": 3.0}],
			["Twin Cannons", 3200, "Fires 2 beams at different targets.", {"count=": 2}],
			["Satellite Link", 14000, "Unlimited range, fires twice as fast.", {"range=": 120.0, "rate*": 0.5}]],
			[["Cooling Fins", 500, "Fires 20% faster.", {"rate*": 0.8}],
			["Micro Missiles", 1200, "Every 5th shot launches 4 homing missiles.", {"missile_every=": 5}],
			["Boss Lock", 3800, "3x boss damage.", {"boss_mul=": 3.0}],
			["Final Form", 20000, "Fires twice as fast, +6 damage.", {"rate*": 0.5, "dmg": 6.0}]],
		],
	},
	"idol": {
		"name": "Aiko", "role": "Pop Idol", "cost": 800,
		"desc": "Earns money each round and cheers on nearby heroes.",
		"base": {"kind": "support", "range": 7.0, "rate": 1.5, "dmg": 0.0, "pierce": 0, "income": 80, "buff_rate": 1.0, "buff_dmg": 0.0, "buff_pierce": 0, "buff_camo": false, "pulse_dmg": 0.0, "pulse_range": 4.0, "camo": true, "type": "magic"},
		"path_names": ["Fan Club", "Encore", "Live Wave"],
		"paths": [
			[["Merch Stand", 500, "+60 income per round.", {"income": 60}],
			["Concert", 1200, "+150 income per round.", {"income": 150}],
			["World Tour", 3500, "+400 income per round.", {"income": 400}],
			["Mega Star", 10000, "+1200 income per round.", {"income": 1200}]],
			[["Cheer", 400, "Nearby heroes attack 10% faster.", {"buff_rate=": 0.9}],
			["Spotlight", 800, "Nearby heroes can see veiled spirits.", {"buff_camo=": true}],
			["Hype Song", 2500, "Nearby heroes deal +1 damage.", {"buff_dmg=": 1.0}],
			["Legendary Idol", 9000, "Nearby heroes +3 pierce and attack 25% faster.", {"buff_pierce=": 3, "buff_rate=": 0.75}]],
			[["Sound Wave", 350, "Sings damaging sound waves around her.", {"pulse_dmg=": 1.0, "pierce=": 12}],
			["Bass Drop", 900, "Sound waves +2 damage.", {"pulse_dmg": 2.0}],
			["Savings Account", 2000, "Earns 5% interest on your money each round (max 800).", {"interest=": true}],
			["Fever Time", 12000, "Waves +5 damage, twice as fast, 3x boss damage.", {"pulse_dmg": 5.0, "rate*": 0.5, "boss_mul=": 3.0, "pierce": 20}]],
		],
	},
}

static func apply_upgrade(stats: Dictionary, fx: Dictionary) -> void:
	for raw_key in fx:
		var key: String = raw_key
		var op := "+"
		if key.ends_with("*") or key.ends_with("="):
			op = key.right(1)
			key = key.left(key.length() - 1)
		var parts := key.split(".")
		var target: Dictionary = stats
		for i in range(parts.size() - 1):
			if not target.has(parts[i]) or typeof(target[parts[i]]) != TYPE_DICTIONARY:
				target[parts[i]] = {}
			target = target[parts[i]]
		var leaf: String = parts[parts.size() - 1]
		var v = fx[raw_key]
		match op:
			"+":
				target[leaf] = target.get(leaf, 0) + v
			"*":
				target[leaf] = target.get(leaf, 1.0) * v
			"=":
				target[leaf] = v.duplicate(true) if typeof(v) == TYPE_DICTIONARY else v
