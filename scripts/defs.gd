# Static game data: spirits (enemies), heroes (towers), and upgrades.
extends RefCounted

static func col(hex: int, alpha: float = 1.0) -> Color:
	var c := Color.hex((hex << 8) | 0xff)
	c.a = alpha
	return c

# ---------------------------------------------------------------------
# Spirits. Popping one releases its "children".
# ---------------------------------------------------------------------
const ORDER := ["pink", "blue", "green", "gold", "violet", "shadow", "frost", "kitsune", "crane", "prism", "lantern", "mask", "oni", "shogun", "dragon"]

const ENEMIES := {
	"pink":   {"name": "Pink Wisp",    "color": 0xff7eb6, "speed": 1.0, "hp": 1.0,    "children": [],                                 "size": 0.7},
	"blue":   {"name": "Blue Wisp",    "color": 0x4f9bff, "speed": 1.4, "hp": 1.0,    "children": ["pink"],                           "size": 0.77},
	"green":  {"name": "Green Wisp",   "color": 0x55d66b, "speed": 1.8, "hp": 1.0,    "children": ["blue"],                           "size": 0.79},
	"gold":   {"name": "Gold Wisp",    "color": 0xffcf3a, "speed": 3.0, "hp": 1.0,    "children": ["green"],                          "size": 0.77},
	"violet": {"name": "Violet Wisp",  "color": 0xc779ff, "speed": 3.4, "hp": 1.0,    "children": ["gold"],                           "size": 0.74},
	"shadow": {"name": "Shadow Wisp",  "color": 0x2e2547, "speed": 1.8, "hp": 1.0,    "children": ["violet", "violet"],               "size": 0.61, "immune": "blast"},
	"frost":  {"name": "Frost Wisp",   "color": 0xeaf7ff, "speed": 2.0, "hp": 1.0,    "children": ["violet", "violet"],               "size": 0.61, "immune": "cold"},
	"kitsune": {"name": "Fox Spirit",  "color": 0xff9d3a, "speed": 3.0, "hp": 2.0,    "children": ["violet", "violet"],               "size": 0.8, "fox": true},
	"crane":  {"name": "Paper Crane",  "color": 0xf4f1ea, "speed": 3.8, "hp": 1.0,    "children": ["kitsune"],                        "size": 0.7, "crane": true},
	"prism":  {"name": "Prism Wisp",   "color": 0xffffff, "speed": 2.2, "hp": 1.0,    "children": ["shadow", "frost"],                "size": 0.84, "rainbow": true},
	"lantern": {"name": "Lantern Ghost", "color": 0xffb347, "speed": 1.1, "hp": 6.0,  "children": ["kitsune", "kitsune"],             "size": 0.95, "lantern": true, "immune": "sharp"},
	"mask":   {"name": "Clay Mask",    "color": 0xd9a46a, "speed": 2.5, "hp": 10.0,   "children": ["prism", "prism"],                 "size": 1.05, "mask": true},
	"oni":    {"name": "ONI LORD",     "color": 0xe53935, "speed": 1.2, "hp": 320.0,  "children": ["mask", "mask", "mask", "mask"],   "size": 1.9, "boss": true},
	"shogun": {"name": "SHADOW SHOGUN", "color": 0x3a2d5c, "speed": 0.9, "hp": 650.0, "children": ["oni", "oni", "lantern", "lantern"], "size": 2.0, "boss": true},
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
const HERO_ORDER := ["ninja", "miko", "mage", "ice", "samurai", "mecha", "idol", "ren", "kenta", "saya", "sora", "riku", "hina", "hiro", "nao", "kaito", "rei", "ichika", "gen", "lumi", "komugi"]

## Five classes of four heroes each (the shop shows one class per tab).
const CLASSES := [
	{"id": "primary", "name": "STRIKERS", "color": 0xff6b5b, "heroes": ["ninja", "samurai", "ren", "kaito"]},
	{"id": "ranged", "name": "MARKSMEN", "color": 0x5bc0ff, "heroes": ["miko", "kenta", "saya", "rei"]},
	{"id": "magic", "name": "MYSTICS", "color": 0xb37bff, "heroes": ["mage", "ice", "sora", "ichika"]},
	{"id": "tech", "name": "ENGINEERS", "color": 0xffb02e, "heroes": ["mecha", "riku", "hina", "gen"]},
	{"id": "support", "name": "SUPPORT", "color": 0x5fd36b, "heroes": ["idol", "hiro", "nao", "lumi", "komugi"]},
]

## Player level needed before a hero can be recruited.
const UNLOCK_LEVEL := {
	"ninja": 1, "miko": 1, "mage": 1, "samurai": 2, "ice": 3, "idol": 4, "kenta": 5, "mecha": 6,
	"ren": 7, "saya": 8, "sora": 9, "riku": 10, "hiro": 11, "hina": 12, "nao": 13,
	"kaito": 14, "rei": 15, "ichika": 16, "gen": 17, "lumi": 18, "komugi": 3,
}

static func hero_class(k: String) -> Dictionary:
	for c in CLASSES:
		if (c["heroes"] as Array).has(k):
			return c
	return CLASSES[0]

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
	"ren": {
		"name": "Ren", "role": "Brawler", "cost": 380,
		"desc": "Lightning-fast punches at very close range.",
		"base": {"kind": "slash", "range": 3.4, "rate": 0.42, "dmg": 1.0, "pierce": 3, "type": "sharp", "camo": false},
		"path_names": ["Iron Fists", "Footwork", "Chi"],
		"paths": [
			[["Knuckle Wraps", 250, "+1 damage.", {"dmg": 1.0}],
			 ["Combo Strikes", 600, "+2 pierce, 15% faster.", {"pierce": 2, "rate*": 0.85}],
			 ["Tiger Claw", 2200, "+3 damage, +3 vs masks.", {"dmg": 3.0, "mask_bonus": 3.0}],
			 ["Dragon Fist", 9500, "+10 damage, +6 pierce, 3x boss damage.", {"dmg": 10.0, "pierce": 6, "boss_mul=": 3.0}]],
			[["Light Feet", 200, "Punches 20% faster.", {"rate*": 0.8}],
			 ["Long Reach", 300, "+1 range.", {"range": 1.0}],
			 ["Whirlwind Kicks", 1800, "Twice as fast, +4 pierce.", {"rate*": 0.5, "pierce": 4}],
			 ["Hundred Fists", 8500, "Blinding speed, +3 damage.", {"rate*": 0.33, "dmg": 3.0}]],
			[["Inner Sight", 250, "Can see veiled spirits.", {"camo=": true}],
			 ["Stunning Blow", 700, "Punches briefly stun spirits.", {"stun=": 0.25}],
			 ["Shockwave Palm", 2000, "Each punch sends a shockwave down the track.", {"wave=": {"dmg": 1.0, "pierce": 10, "speed": 16.0}}],
			 ["Inner Storm", 11000, "Shockwaves +4 damage, +20 pierce, 4x boss damage.", {"wave.dmg": 4.0, "wave.pierce": 20, "boss_mul=": 4.0}]],
		],
	},
	"kenta": {
		"name": "Kenta", "role": "Spear Thrower", "cost": 450,
		"desc": "Hurls spears that skewer long lines of spirits.",
		"base": {"kind": "proj", "range": 10.0, "rate": 1.2, "dmg": 2.0, "pierce": 6, "type": "sharp", "proj_speed": 34.0, "count": 1, "spread": 0.15, "camo": false, "proj": "arrow"},
		"path_names": ["Long Spears", "Volley", "Hunter"],
		"paths": [
			[["Barbed Tips", 200, "+4 pierce.", {"pierce": 4}],
			 ["Heavy Spears", 550, "+1 damage, +4 pierce.", {"dmg": 1.0, "pierce": 4}],
			 ["Impaler", 2600, "+4 damage, +3 vs masks, +10 pierce.", {"dmg": 4.0, "mask_bonus": 3.0, "pierce": 10}],
			 ["Sky Piercer", 10500, "+12 damage, +30 pierce, 3x boss damage.", {"dmg": 12.0, "pierce": 30, "boss_mul=": 3.0}]],
			[["Quick Throw", 250, "Throws 20% faster.", {"rate*": 0.8}],
			 ["Double Throw", 700, "Throws 2 spears.", {"count=": 2, "spread=": 0.2}],
			 ["Spear Storm", 2400, "Throws 4 spears, faster.", {"count=": 4, "rate*": 0.7}],
			 ["Legion Volley", 9000, "Throws 8 spears twice as fast.", {"count=": 8, "spread=": 0.6, "rate*": 0.5}]],
			[["Keen Eyes", 150, "+3 range.", {"range": 3.0}],
			 ["Tracker", 350, "Can see veiled spirits.", {"camo=": true}],
			 ["Pinning Throw", 1500, "Spears slow and briefly stun spirits.", {"slow=": 0.4, "slow_dur=": 2.0, "stun=": 0.3}],
			 ["Monster Hunter", 8000, "4x boss damage, +6 damage.", {"boss_mul=": 4.0, "dmg": 6.0}]],
		],
	},
	"saya": {
		"name": "Saya", "role": "Cannoneer", "cost": 700,
		"desc": "Lobs huge cannonballs from very long range. Can't harm Shadow Wisps.",
		"base": {"kind": "proj", "range": 14.0, "rate": 2.2, "dmg": 2.0, "pierce": 1, "type": "blast", "proj_speed": 20.0, "count": 1, "spread": 0.2, "camo": false, "proj": "fireball", "explode": {"r": 2.6, "pierce": 22, "cluster": 0}},
		"path_names": ["Heavy Shells", "Reload", "Special Ammo"],
		"paths": [
			[["Bigger Shells", 400, "Bigger blasts that hit more spirits.", {"explode.r": 0.8, "explode.pierce": 10}],
			 ["Packed Powder", 900, "+2 damage.", {"dmg": 2.0}],
			 ["Siege Shell", 3200, "+5 damage, huge blasts, 3x boss damage.", {"dmg": 5.0, "explode.r": 1.5, "boss_mul=": 3.0}],
			 ["Doomsday Gun", 14000, "+15 damage, +60 blast pierce, 6x boss damage.", {"dmg": 15.0, "explode.pierce": 60, "boss_mul=": 6.0}]],
			[["Oiled Breech", 300, "Fires 25% faster.", {"rate*": 0.75}],
			 ["Crew Drill", 800, "Fires 25% faster again.", {"rate*": 0.75}],
			 ["Twin Barrels", 2800, "Fires 2 shells.", {"count=": 2}],
			 ["Carpet Barrage", 11000, "Fires 4 shells, much faster.", {"rate*": 0.4, "count=": 4, "spread=": 0.5}]],
			[["Spotter", 250, "+3 range.", {"range": 3.0}],
			 ["Shrapnel", 1200, "Blasts burst into 5 bomblets.", {"explode.cluster=": 5}],
			 ["Shock Shells", 2500, "Blasts stun spirits.", {"stun=": 0.6}],
			 ["Purifying Blast", 9500, "Shells become magic, +4 damage.", {"type=": "magic", "dmg": 4.0}]],
		],
	},
	"sora": {
		"name": "Sora", "role": "Storm Caller", "cost": 750,
		"desc": "Calls down lightning that arcs through a line of spirits.",
		"base": {"kind": "beam", "range": 9.5, "rate": 0.9, "dmg": 2.0, "pierce": 5, "type": "magic", "count": 1, "width": 0.7, "camo": false, "beam_color": 0xfff36b},
		"path_names": ["High Voltage", "Tempest", "Clouds"],
		"paths": [
			[["Charged Air", 350, "+1 damage.", {"dmg": 1.0}],
			 ["Forked Bolts", 800, "+5 pierce.", {"pierce": 5}],
			 ["Thunderclap", 3000, "+4 damage, bolts stun briefly.", {"dmg": 4.0, "stun=": 0.3}],
			 ["Raijin's Wrath", 12500, "+12 damage, +15 pierce, 3x boss damage.", {"dmg": 12.0, "pierce": 15, "boss_mul=": 3.0}]],
			[["Gale", 300, "Strikes 20% faster.", {"rate*": 0.8}],
			 ["Wide Sky", 450, "+2 range.", {"range": 2.0}],
			 ["Chain Storm", 2600, "Two bolts at different targets.", {"count=": 2}],
			 ["Endless Storm", 10000, "Four bolts, twice as fast.", {"count=": 4, "rate*": 0.5}]],
			[["Storm Eye", 300, "Can see veiled spirits.", {"camo=": true}],
			 ["Heavy Rain", 700, "Bolts slow spirits.", {"slow=": 0.6, "slow_dur=": 1.5}],
			 ["Static Field", 2200, "Constantly slows everything in range.", {"aura_slow=": 0.7}],
			 ["Eye of the Storm", 9000, "+4 range, +6 damage.", {"range": 4.0, "dmg": 6.0}]],
		],
	},
	"riku": {
		"name": "Riku", "role": "Drone Pilot", "cost": 650,
		"desc": "Sends homing drones after spirits. Can see veiled spirits.",
		"base": {"kind": "proj", "range": 12.0, "rate": 0.55, "dmg": 1.0, "pierce": 2, "type": "sharp", "proj_speed": 24.0, "count": 1, "spread": 0.3, "camo": true, "proj": "missile", "homing": true},
		"path_names": ["Payload", "Swarm", "Sensors"],
		"paths": [
			[["Sharper Props", 250, "+2 pierce.", {"pierce": 2}],
			 ["Heavier Drones", 600, "+1 damage.", {"dmg": 1.0}],
			 ["Micro Rockets", 2400, "Drones explode on impact.", {"explode=": {"r": 1.5, "pierce": 10, "cluster": 0}, "type=": "blast"}],
			 ["Hellfire Drones", 10000, "+6 damage, bigger blasts, 3x boss damage.", {"dmg": 6.0, "explode.r": 1.0, "boss_mul=": 3.0}]],
			[["Fast Charge", 300, "Launches 20% faster.", {"rate*": 0.8}],
			 ["Wingman", 900, "Launches 2 drones.", {"count=": 2}],
			 ["Drone Swarm", 3000, "Launches 4 drones.", {"count=": 4}],
			 ["Hive Mind", 11500, "Launches 7 drones, much faster.", {"count=": 7, "rate*": 0.6}]],
			[["Long-Range Antenna", 200, "+3 range.", {"range": 3.0}],
			 ["Marked Target", 700, "+3 damage vs Clay Masks.", {"mask_bonus": 3.0}],
			 ["Boss Tracker", 2600, "4x boss damage.", {"boss_mul=": 4.0}],
			 ["Satellite Uplink", 9500, "Unlimited range, +3 damage.", {"range=": 120.0, "dmg": 3.0}]],
		],
	},
	"hina": {
		"name": "Hina", "role": "Turret Engineer", "cost": 850,
		"desc": "Builds a rapid-fire turret that never stops shooting.",
		"base": {"kind": "proj", "range": 9.0, "rate": 0.16, "dmg": 1.0, "pierce": 1, "type": "sharp", "proj_speed": 40.0, "count": 1, "spread": 0.08, "camo": false, "proj": "frag"},
		"path_names": ["Caliber", "Fire Rate", "Targeting"],
		"paths": [
			[["Hollow Points", 300, "+1 pierce.", {"pierce": 1}],
			 ["Heavy Rounds", 800, "+1 damage.", {"dmg": 1.0}],
			 ["Armor Piercing", 2800, "+2 damage, +2 pierce, +3 vs masks.", {"dmg": 2.0, "pierce": 2, "mask_bonus": 3.0}],
			 ["Rail Turret", 12000, "+10 damage, +10 pierce, 3x boss damage.", {"dmg": 10.0, "pierce": 10, "boss_mul=": 3.0}]],
			[["Greased Gears", 400, "Fires 20% faster.", {"rate*": 0.8}],
			 ["Faster Motors", 900, "Fires 20% faster again.", {"rate*": 0.8}],
			 ["Twin Guns", 2800, "Fires 2 bullets.", {"count=": 2, "spread=": 0.12}],
			 ["Bullet Hell", 11000, "Fires 4 bullets, even faster.", {"count=": 4, "rate*": 0.6, "spread=": 0.3}]],
			[["Scope", 250, "+2 range.", {"range": 2.0}],
			 ["Thermal Sights", 400, "Can see veiled spirits.", {"camo=": true}],
			 ["Incendiary Rounds", 2000, "Bullets become magic, +1 damage.", {"type=": "magic", "dmg": 1.0}],
			 ["Sentry Network", 8500, "+4 range, faster, 2x boss damage.", {"range": 4.0, "rate*": 0.7, "boss_mul=": 2.0}]],
		],
	},
	"hiro": {
		"name": "Hiro", "role": "Merchant", "cost": 1000,
		"desc": "Runs a stall that earns lots of money every round.",
		"base": {"kind": "support", "range": 6.0, "rate": 1.5, "dmg": 0.0, "pierce": 0, "income": 120, "buff_rate": 1.0, "buff_dmg": 0.0, "buff_pierce": 0, "buff_camo": false, "pulse_dmg": 0.0, "pulse_range": 4.0, "camo": true, "type": "magic"},
		"path_names": ["Trade", "Bank", "Patronage"],
		"paths": [
			[["Busy Stall", 600, "+80 income per round.", {"income": 80}],
			 ["Shop Front", 1500, "+200 income per round.", {"income": 200}],
			 ["Trade Route", 4000, "+500 income per round.", {"income": 500}],
			 ["Golden Empire", 14000, "+1500 income per round.", {"income": 1500}]],
			[["Savings", 1000, "Earns 5% interest on your money each round (max 800).", {"interest=": true}],
			 ["Investments", 1600, "+100 income per round.", {"income": 100}],
			 ["Compound Interest", 4500, "+300 income per round.", {"income": 300}],
			 ["Treasury", 12000, "+1000 income per round.", {"income": 1000}]],
			[["Good Deals", 500, "Nearby heroes attack 5% faster.", {"buff_rate=": 0.95}],
			 ["Better Gear", 1200, "Nearby heroes +1 pierce.", {"buff_pierce=": 1}],
			 ["War Chest", 3500, "Nearby heroes +1 damage.", {"buff_dmg=": 1.0}],
			 ["Patron of Heroes", 10000, "Nearby heroes +2 damage and 20% faster.", {"buff_dmg=": 2.0, "buff_rate=": 0.8}]],
		],
	},
	"nao": {
		"name": "Nao", "role": "Shrine Healer", "cost": 750,
		"desc": "Restores lives every round and protects nearby heroes.",
		"base": {"kind": "support", "range": 7.0, "rate": 1.5, "dmg": 0.0, "pierce": 0, "income": 0, "lives_regen": 3, "buff_rate": 1.0, "buff_dmg": 0.0, "buff_pierce": 0, "buff_camo": false, "pulse_dmg": 0.0, "pulse_range": 4.0, "camo": true, "type": "magic"},
		"path_names": ["Blessings", "Wards", "Purify"],
		"paths": [
			[["Prayer", 400, "+3 lives per round.", {"lives_regen": 3}],
			 ["Healing Charm", 900, "+5 lives per round.", {"lives_regen": 5}],
			 ["Sacred Spring", 3000, "+15 lives per round.", {"lives_regen": 15}],
			 ["Eternal Shrine", 10000, "+40 lives per round.", {"lives_regen": 40}]],
			[["Spirit Ward", 350, "Nearby heroes can see veiled spirits.", {"buff_camo=": true}],
			 ["Calm Mind", 700, "Nearby heroes attack 8% faster.", {"buff_rate=": 0.92}],
			 ["Guardian Ward", 2500, "Nearby heroes +2 pierce.", {"buff_pierce=": 2}],
			 ["Divine Ward", 9500, "Nearby heroes +2 damage and 20% faster.", {"buff_dmg=": 2.0, "buff_rate=": 0.8}]],
			[["Cleansing Bell", 400, "Rings out waves that hurt nearby spirits.", {"pulse_dmg=": 1.0, "pierce=": 15}],
			 ["Temple Bell", 900, "Waves +2 damage.", {"pulse_dmg": 2.0}],
			 ["Holy Light", 2800, "Waves +4 damage and reach further.", {"pulse_dmg": 4.0, "pulse_range": 1.5}],
			 ["Exorcism", 11000, "Waves +10 damage, twice as fast, 4x boss damage.", {"pulse_dmg": 10.0, "rate*": 0.5, "boss_mul=": 4.0, "pierce": 25}]],
		],
	},
	"kaito": {
		"name": "Kaito", "role": "Pirate Captain", "cost": 520,
		"desc": "Cutlass sweeps up close, and a flintlock that blasts shockwaves down the track.",
		"base": {"kind": "slash", "range": 4.2, "rate": 0.8, "dmg": 2.0, "pierce": 5, "type": "sharp", "camo": false},
		"path_names": ["Cutlass", "Flintlock", "Crew"],
		"paths": [
			[["Sharpened Steel", 300, "+1 damage.", {"dmg": 1.0}],
			 ["Twin Cutlasses", 750, "+5 pierce, 15% faster.", {"pierce": 5, "rate*": 0.85}],
			 ["Storm Slash", 2800, "+4 damage, +4 vs masks.", {"dmg": 4.0, "mask_bonus": 4.0}],
			 ["King of the Seas", 12000, "+12 damage, +10 pierce, 3x boss damage.", {"dmg": 12.0, "pierce": 10, "boss_mul=": 3.0}]],
			[["Powder Horn", 250, "+1 range.", {"range": 1.0}],
			 ["Flintlock Shot", 700, "Each swing also fires a cannon shockwave.", {"wave=": {"dmg": 2.0, "pierce": 8, "speed": 20.0}}],
			 ["Grapeshot", 2400, "Shockwaves +3 damage, +15 pierce.", {"wave.dmg": 3.0, "wave.pierce": 15}],
			 ["Broadside", 9500, "Twice as fast, +2 range.", {"rate*": 0.5, "range": 2.0}]],
			[["Lookout", 250, "Can see veiled spirits.", {"camo=": true}],
			 ["Sea Legs", 800, "Swings 20% faster.", {"rate*": 0.8}],
			 ["Treasure Hunter", 2600, "4x boss damage.", {"boss_mul=": 4.0}],
			 ["Grand Fleet", 13000, "+8 damage, +12 pierce, much faster.", {"dmg": 8.0, "pierce": 12, "rate*": 0.6}]],
		],
	},
	"rei": {
		"name": "Rei", "role": "Ki Blaster", "cost": 800,
		"desc": "Charges up ki and fires a wide energy wave through every spirit in its path.",
		"base": {"kind": "beam", "range": 11.0, "rate": 1.4, "dmg": 3.0, "pierce": 8, "type": "magic", "count": 1, "width": 1.0, "camo": false, "beam_color": 0xff9a26},
		"path_names": ["Ki Power", "Rapid Blasts", "Focus"],
		"paths": [
			[["Focused Ki", 400, "+1 damage.", {"dmg": 1.0}],
			 ["Wide Wave", 900, "+6 pierce, wider waves.", {"pierce": 6, "width=": 1.4}],
			 ["Mega Wave", 3200, "+6 damage.", {"dmg": 6.0}],
			 ["Ultimate Wave", 13500, "+18 damage, +20 pierce, 3x boss damage.", {"dmg": 18.0, "pierce": 20, "boss_mul=": 3.0, "width=": 2.0}]],
			[["Quick Charge", 350, "Fires 20% faster.", {"rate*": 0.8}],
			 ["Double Palm", 1000, "Two waves at different targets.", {"count=": 2}],
			 ["Ki Barrage", 3000, "Fires twice as fast.", {"rate*": 0.5}],
			 ["Endless Barrage", 11000, "Four waves, faster again.", {"count=": 4, "rate*": 0.6}]],
			[["Sense Ki", 300, "Can see veiled spirits.", {"camo=": true}],
			 ["Long Reach", 600, "+3 range.", {"range": 3.0}],
			 ["Spirit Breaker", 2600, "4x boss damage.", {"boss_mul=": 4.0}],
			 ["Limit Break", 10000, "+5 range, +8 damage.", {"range": 5.0, "dmg": 8.0}]],
		],
	},
	"ichika": {
		"name": "Ichika", "role": "Curse Exorcist", "cost": 700,
		"desc": "Throws sealing talismans that burst into rings of exorcising energy.",
		"base": {"kind": "pulse", "range": 5.0, "rate": 1.6, "dmg": 1.0, "pierce": 25, "type": "magic", "freeze": 0.0, "camo": false},
		"path_names": ["Exorcism", "Seals", "Barrier"],
		"paths": [
			[["Blessed Ink", 350, "+1 damage.", {"dmg": 1.0}],
			 ["Purge", 900, "+2 damage, +3 vs masks.", {"dmg": 2.0, "mask_bonus": 3.0}],
			 ["Grand Exorcism", 3000, "+5 damage, +25 pierce.", {"dmg": 5.0, "pierce": 25}],
			 ["Heaven's Judgement", 12500, "+15 damage, 4x boss damage.", {"dmg": 15.0, "boss_mul=": 4.0}]],
			[["Binding Seal", 300, "Rings slow spirits.", {"slow=": 0.6, "slow_dur=": 1.5}],
			 ["Paralysis Seal", 800, "Rings stun spirits briefly.", {"freeze": 0.4}],
			 ["Iron Seal", 2600, "Longer stuns, works on bosses.", {"freeze": 0.6, "stun_boss=": true}],
			 ["Eternal Seal", 9500, "Permanently slows everything nearby.", {"aura_slow=": 0.5, "freeze": 0.6}]],
			[["Wider Circle", 250, "+1.5 range.", {"range": 1.5}],
			 ["Spirit Sight", 350, "Can see veiled spirits.", {"camo=": true}],
			 ["Rapid Rites", 2200, "Pulses twice as fast.", {"rate*": 0.5}],
			 ["Sacred Ground", 9000, "+3 range, +4 damage.", {"range": 3.0, "dmg": 4.0}]],
		],
	},
	"gen": {
		"name": "Gen", "role": "Gadgeteer", "cost": 600,
		"desc": "A hero-academy student who lobs sticky gadget grenades that slow and stun.",
		"base": {"kind": "proj", "range": 10.0, "rate": 1.3, "dmg": 1.0, "pierce": 1, "type": "blast", "proj_speed": 22.0, "count": 1, "spread": 0.2, "camo": false, "proj": "frag", "slow": 0.6, "slow_dur": 1.5, "explode": {"r": 2.0, "pierce": 14, "cluster": 0}},
		"path_names": ["Grenades", "Workshop", "Support Gear"],
		"paths": [
			[["Bigger Charges", 300, "Bigger blasts.", {"explode.r": 0.6, "explode.pierce": 8}],
			 ["Glue Bombs", 700, "Slows much harder.", {"slow=": 0.35, "slow_dur=": 2.5}],
			 ["Flashbangs", 2400, "Blasts stun spirits, +2 damage.", {"stun=": 0.6, "dmg": 2.0}],
			 ["Ultimate Support Item", 10500, "+10 damage, stuns bosses, 3x boss damage.", {"dmg": 10.0, "stun_boss=": true, "boss_mul=": 3.0}]],
			[["Quick Toss", 300, "Throws 20% faster.", {"rate*": 0.8}],
			 ["Double Grenade", 800, "Throws 2 grenades.", {"count=": 2}],
			 ["Cluster Grenades", 2600, "Blasts split into 5 bomblets.", {"explode.cluster=": 5}],
			 ["Gadget Storm", 9500, "Throws 4, twice as fast.", {"count=": 4, "rate*": 0.5}]],
			[["Goggles", 250, "Can see veiled spirits.", {"camo=": true}],
			 ["Targeting Visor", 500, "+3 range.", {"range": 3.0}],
			 ["Plasma Charges", 2000, "Blasts become magic, +2 damage.", {"type=": "magic", "dmg": 2.0}],
			 ["Mastermind", 8500, "+4 range, 4x boss damage.", {"range": 4.0, "boss_mul=": 4.0}]],
		],
	},
	"lumi": {
		"name": "Lumi", "role": "Magical Girl", "cost": 900,
		"desc": "Sparkling starlight heals the shrine and powers up nearby heroes.",
		"base": {"kind": "support", "range": 7.5, "rate": 1.2, "dmg": 0.0, "pierce": 12, "income": 0, "lives_regen": 1, "buff_rate": 0.92, "buff_dmg": 0.0, "buff_pierce": 0, "buff_camo": false, "pulse_dmg": 1.0, "pulse_range": 4.5, "camo": true, "type": "magic"},
		"path_names": ["Starlight", "Friendship", "Moon Power"],
		"paths": [
			[["Twinkle", 400, "Sparkles +1 damage.", {"pulse_dmg": 1.0}],
			 ["Shooting Star", 900, "Sparkles +2 damage, reach further.", {"pulse_dmg": 2.0, "pulse_range": 1.0}],
			 ["Supernova Heart", 3000, "Sparkles +5 damage, twice as fast.", {"pulse_dmg": 5.0, "rate*": 0.5}],
			 ["Galaxy Princess", 12000, "Sparkles +12 damage, 4x boss damage.", {"pulse_dmg": 12.0, "boss_mul=": 4.0, "pierce": 25}]],
			[["Pep Talk", 400, "Nearby heroes attack faster.", {"buff_rate=": 0.85}],
			 ["Team Spirit", 900, "Nearby heroes +1 pierce.", {"buff_pierce=": 1}],
			 ["Power of Friendship", 2800, "Nearby heroes +2 damage.", {"buff_dmg=": 2.0}],
			 ["Bonds Beyond Time", 10000, "Nearby heroes +3 pierce, much faster.", {"buff_pierce=": 3, "buff_rate=": 0.7}]],
			[["Moon Charm", 300, "+2 lives per round.", {"lives_regen": 2}],
			 ["Moonlight Shield", 800, "+4 lives per round.", {"lives_regen": 4}],
			 ["Full Moon", 2500, "+10 lives per round.", {"lives_regen": 10}],
			 ["Eternal Moon", 9000, "+25 lives per round, nearby heroes see veiled spirits.", {"lives_regen": 25, "buff_camo=": true}]],
		],
	},
	"komugi": {
		"name": "Komugi", "role": "Rice Farmer", "cost": 1100,
		"desc": "Tends a rice paddy that grows coin bundles during each round. Tap the bundles to collect them.",
		"base": {"kind": "support", "farm": true, "range": 4.5, "rate": 1.2, "dmg": 0.0, "pierce": 6, "income": 0, "lives_regen": 0, "buff_rate": 1.0, "buff_dmg": 0.0, "buff_pierce": 0, "buff_camo": false, "pulse_dmg": 0.0, "pulse_range": 3.5, "camo": false, "type": "magic", "crop_rate": 6.0, "coin_value": 25, "collect_time": 9.0, "auto_collect": false},
		"path_names": ["Harvest", "Market", "Scarecrow"],
		"paths": [
			[["Fertile Soil", 450, "Grows bundles 25% faster.", {"crop_rate*": 0.75}],
			 ["Twin Paddies", 1100, "Bundles are worth +$20.", {"coin_value": 20}],
			 ["Golden Rice", 3500, "Bundles worth 1.6x and grow faster.", {"coin_value*": 1.6, "crop_rate*": 0.8}],
			 ["Rice Empire", 11000, "Bundles worth 2.5x and grow much faster.", {"coin_value*": 2.5, "crop_rate*": 0.6}]],
			[["Harvest Basket", 300, "Bundles stay twice as long before collecting themselves.", {"collect_time": 9.0}],
			 ["Farm Hand", 900, "Bundles are collected automatically.", {"auto_collect=": true}],
			 ["Market Stall", 2600, "+$250 income at the end of every round.", {"income": 250}],
			 ["Rice Exchange", 8500, "+$900 income per round, and 5% interest on your money (max $800).", {"income": 900, "interest=": true}]],
			[["Scarecrow", 350, "A scarecrow shakes off nearby spirits.", {"pulse_dmg": 1.0}],
			 ["Crow Flock", 1000, "Crows deal +2 damage and spot veiled spirits.", {"pulse_dmg": 2.0, "camo=": true}],
			 ["Harvest Festival", 3200, "+3 lives per round, nearby heroes attack 10% faster.", {"lives_regen": 3, "buff_rate=": 0.9, "pulse_dmg": 2.0}],
			 ["Spirit of the Field", 10500, "Huge scarecrow sweeps: +10 damage, longer reach.", {"pulse_dmg": 10.0, "pulse_range": 1.5, "pierce": 14, "rate*": 0.6}]],
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
