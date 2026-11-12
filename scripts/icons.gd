# SVG icon set shared with the Figma UI kit ("Sakura UI" file, UI Kit page).
# Icons are white glyphs on a 24x24 grid; textures are tinted and cached here.
extends RefCounted

const ICONS := {
	"sword": '<path d="M19 3h2v2l-9 9-2-2 9-9Z M5 14l5 5-1.5 1.5L7 19l-2.5 2.5-1-1L6 18l-1.5-1.5L5 14Z"/>',
	"bolt": '<path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z"/>',
	"eye": '<path d="M12 5C6 5 2 12 2 12s4 7 10 7 10-7 10-7-4-7-10-7Zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8Z"/>',
	"arrows": '<path d="M3 7h12l-3-3 1.5-1.5L19 8l-5.5 5.5L12 12l3-3H3V7Zm0 8h12l-3-3 1.5-1.5L19 16l-5.5 5.5L12 20l3-3H3v-2Z"/>',
	"skull": '<path d="M12 2C7 2 4 5.5 4 10c0 2.5 1 4.3 2.5 5.4V19h3v-2h1v2h3v-2h1v2h3v-3.6C19 14.3 20 12.5 20 10c0-4.5-3-8-8-8Zm-3 11a2 2 0 1 1 0-4 2 2 0 0 1 0 4Zm6 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4Z"/>',
	"coin": '<path d="M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm0 4a5 5 0 1 1 0 10 5 5 0 0 1 0-10Z"/>',
	"heart": '<path d="M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11Z"/>',
	"star": '<path d="m12 2 2.9 6.6 7.1.6-5.4 4.7 1.7 7-6.3-3.8-6.3 3.8 1.7-7L2 9.2l7.1-.6L12 2Z"/>',
	"lock": '<path d="M7 10V7a5 5 0 0 1 10 0v3h1a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h1Zm2 0h6V7a3 3 0 0 0-6 0v3Z"/>',
	"play": '<path d="M7 4v16l13-8L7 4Z"/>',
	"spiral": '<path d="M12 4a8 8 0 1 0 8 8h-2a6 6 0 1 1-6-6 4 4 0 1 1-4 4h2a2 2 0 1 0 2-2V4Z"/>',
	"snow": '<path d="M11 2h2v4l2-2 1.4 1.4L13 8.8V11h2.2l3.4-3.4L20 9l-2 2h4v2h-4l2 2-1.4 1.4-3.4-3.4H13v2.2l3.4 3.4L15 20l-2-2v4h-2v-4l-2 2-1.4-1.4 3.4-3.4V13H8.8l-3.4 3.4L4 15l2-2H2v-2h4L4 9l1.4-1.4L8.8 11H11V8.8L7.6 5.4 9 4l2 2V2Z"/>',
	"burst": '<path d="m12 1 2.2 6.3L20 4l-3.3 5.8L23 12l-6.3 2.2L20 20l-5.8-3.3L12 23l-2.2-6.3L4 20l3.3-5.8L1 12l6.3-2.2L4 4l5.8 3.3L12 1Z"/>',
	"back": '<path d="M10 5 3 12l7 7v-4h5a5 5 0 0 0 0-10H10V5Z"/>',
	"left": '<path d="M15 3 6 12l9 9 2.5-2.5L11 12l6.5-6.5L15 3Z"/>',
	"right": '<path d="m9 3 9 9-9 9-2.5-2.5L13 12 6.5 5.5 9 3Z"/>',
	"target": '<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 3a7 7 0 1 1 0 14 7 7 0 0 1 0-14Zm0 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm0 2.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Z"/>',
	"wand": '<path d="m3 19 11-11 2 2L5 21l-2-2Zm13-17 1 2.5L19.5 5 17 6l-1 2.5L15 6l-2.5-1L15 4l1-2Zm5 7 .7 1.6 1.6.7-1.6.7L21 13l-.7-1.6-1.6-.7 1.6-.7L21 9Z"/>',
	"gear": '<path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm8.9 2.5-2-.4a7 7 0 0 0-.8-1.9l1.2-1.7-2-2-1.7 1.2a7 7 0 0 0-1.9-.8l-.4-2h-2.6l-.4 2a7 7 0 0 0-1.9.8L6.6 4.5l-2 2 1.2 1.7a7 7 0 0 0-.8 1.9l-2 .4v2.8l2 .4c.2.7.4 1.3.8 1.9l-1.2 1.7 2 2 1.7-1.2c.6.4 1.2.6 1.9.8l.4 2h2.6l.4-2c.7-.2 1.3-.4 1.9-.8l1.7 1.2 2-2-1.2-1.7c.4-.6.6-1.2.8-1.9l2-.4v-2.8Z"/>',
	"gem": '<path d="M7 3h10l5 6-10 13L2 9l5-6Zm.9 2L5.2 8.2h3.3L7.9 5Zm2.2 0 .7 3.2h2.4L13.9 5h-3.8Zm6 0-.6 3.2h3.3L16.1 5ZM5.7 10.2l5.1 6.6-1.8-6.6H5.7Zm5.4 0L12 16l.9-5.8h-1.8Zm3.9 0-1.8 6.6 5.1-6.6H15Z"/>',
	"hourglass": '<path d="M6 2h12v2h-1v3l-4 5 4 5v3h1v2H6v-2h1v-3l4-5-4-5V4H6V2Zm3 2v2.3L12 10l3-3.7V4H9Z"/>',
	"bomb": '<path d="M14.5 3.5 16 2l1.5 1.5L19 2l1 1-1.5 1.5L20 6l-1 1-1.6-1.6-1.3 1.3A7 7 0 1 1 13.4 4.6l1.1-1.1ZM10 9a3 3 0 0 0-3 3h2a1 1 0 0 1 1-1V9Z"/>',
	"music": '<path d="M9 3h12v13a3.5 3.5 0 1 1-2-3.2V7h-8v11a3.5 3.5 0 1 1-2-3.2V3Z"/>',
	"scroll": '<path d="M6 3h11a3 3 0 0 1 3 3v1h-3v12a2 2 0 0 1-2 2H6a3 3 0 0 1-3-3v-1h3V3Zm2 2v13h7V6a3 3 0 0 1 .2-1H8Zm1 2h5v2H9V7Zm0 4h5v2H9v-2Z"/>',
	"shirt": '<path d="M8 3h2a2 2 0 0 0 4 0h2l6 4-2.5 4L17 9.8V21H7V9.8L4.5 11 2 7l6-4Z"/>',
	"sprout": '<path d="M11 21v-7.2C7.5 13.5 4 11 4 6V5h1c3.2 0 5.6 1.6 6.6 4.3C12.6 6 15.2 4 19 4h1v1c0 5.3-3.7 8.1-7 8.6V21h-2Z"/>',
	"fist": '<path d="M7 5a2 2 0 0 1 4 0V4a2 2 0 0 1 4 0v1a2 2 0 0 1 4 0v8a7 7 0 0 1-7 7h-1a6 6 0 0 1-6-6v-3a2 2 0 0 1 2-1V5Z"/>',
	"shield": '<path d="M12 2 4 5v6c0 5 3.4 9.5 8 11 4.6-1.5 8-6 8-11V5l-8-3Z"/>',
	"flame": '<path d="M12 2s6 5 6 11a6 6 0 0 1-12 0c0-2.6 1.4-4.6 3-6 0 2 1 3.5 2.5 3.5C13 10.5 12 6 12 2Z"/>',
	"crown": '<path d="m3 7 5 4 4-7 4 7 5-4-2 12H5L3 7Zm2 14h14v2H5v-2Z"/>',
	"check": '<path d="m9 16.2-4.2-4.2-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2Z"/>',
}

static var _cache := {}

## A tinted icon texture of `px` pixels.
static func tex(name: String, color: Color = Color.WHITE, px: int = 64) -> Texture2D:
	var key := "%s_%s_%d" % [name, color.to_html(), px]
	if _cache.has(key):
		return _cache[key]
	var body: String = ICONS.get(name, ICONS["star"])
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="#%s">%s</svg>' % [color.to_html(false), body]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, px / 24.0)
	if err != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## Icon for each hero class tab.
const CLASS_ICONS := {"primary": "fist", "ranged": "target", "magic": "wand", "tech": "gear", "support": "heart"}
## Icon for each game mode.
const MODE_ICONS := {"standard": "shield", "half_cash": "coin", "fortified": "shield", "deflation": "hourglass", "rush": "bolt", "sandbox": "star"}

## Pick an icon that describes an upgrade from its effect dictionary.
static func for_upgrade(fx: Dictionary) -> String:
	var keys: Array = fx.keys()
	var has := func(prefix: String) -> bool:
		for k in keys:
			if String(k).begins_with(prefix):
				return true
		return false
	if has.call("coin_value") or has.call("auto_collect"):
		return "sprout"
	if has.call("income") or has.call("interest"):
		return "coin"
	if has.call("lives_regen"):
		return "heart"
	if has.call("boss_mul"):
		return "skull"
	if has.call("freeze") or has.call("slow") or has.call("aura_slow"):
		return "snow"
	if has.call("stun"):
		return "spiral"
	if has.call("camo") or has.call("buff_camo"):
		return "eye"
	if has.call("explode") or has.call("count") or has.call("missile") or has.call("flash") or has.call("wave"):
		return "burst"
	if has.call("buff"):
		return "star"
	if has.call("rate"):
		return "bolt"
	if has.call("range"):
		return "eye"
	if has.call("pierce") or has.call("homing"):
		return "arrows"
	return "sword"
