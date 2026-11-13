# Shared ground rendering for the game board and the menu village: the painted
# grass/sand material, the animated water material, and the small data texture both
# shaders read (contact shade and distance from the shore).
extends RefCounted

const Defs = preload("res://scripts/defs.gd")
const GroundShader = preload("res://shaders/ground.gdshader")
const WaterShader = preload("res://shaders/water.gdshader")

## World x/z area covered by the data texture, at one pixel per unit.
const RECT := Rect2(-72.0, -52.0, 144.0, 104.0)
const W := 144
const H := 104
## How far the sand reaches out from the shoreline (the land mesh ends here).
const SAND_REACH := 4.6

static func _rect_param(origin: Vector2) -> Vector4:
	return Vector4(RECT.position.x + origin.x, RECT.position.y + origin.y, 1.0 / RECT.size.x, 1.0 / RECT.size.y)

## Grass and sand for a theme (see THEMES in scripts/level/level.gd).
## `origin` is the world x/z of the scene's centre (the menu village sits far from the board).
static func ground_material(theme: Dictionary, origin: Vector2 = Vector2.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GroundShader
	var grass := Defs.col(theme["grass"])
	var light := grass
	var dark := grass
	for h in theme["patches"]:
		var c := Defs.col(h)
		if c.get_luminance() > light.get_luminance():
			light = c
		if c.get_luminance() < dark.get_luminance():
			dark = c
	var sand := Defs.col(theme["sand"])
	m.set_shader_parameter("grass", grass)
	m.set_shader_parameter("grass_light", grass.lerp(light, 0.75))
	m.set_shader_parameter("grass_dark", grass.lerp(dark, 0.75))
	m.set_shader_parameter("sand", sand)
	m.set_shader_parameter("sand_wet", sand.darkened(0.08).lerp(Defs.col(theme["shallow"]), 0.2))
	m.set_shader_parameter("world_rect", _rect_param(origin))
	m.set_shader_parameter("centre", origin)
	m.set_shader_parameter("horizon", Defs.col(theme["sky_horizon"]))
	return m

static func water_material(theme: Dictionary, origin: Vector2 = Vector2.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WaterShader
	m.set_shader_parameter("deep", Defs.col(theme["sea"]))
	m.set_shader_parameter("shallow", Defs.col(theme["shallow"]))
	m.set_shader_parameter("foam", Defs.col(theme["foam"]))
	m.set_shader_parameter("shore_edge", SAND_REACH)
	m.set_shader_parameter("world_rect", _rect_param(origin))
	m.set_shader_parameter("centre", origin)
	m.set_shader_parameter("horizon", Defs.col(theme["sky_horizon"]).lerp(Defs.col(theme["sea"]), 0.35))
	return m

## Bake the data texture.
##   inland: Callable(x, z) -> distance inland in units (negative in the sea), in the
##           scene's local x/z; pass an invalid Callable when there is no sea.
##   rects:  Rect2 areas in world x/z that shade the ground around them (track cells).
##   discs:  Vector3(x, z, radius) shade blobs (trees, houses, rocks).
static func bake(inland: Callable, rects: Array, discs: Array) -> ImageTexture:
	var shade := PackedFloat32Array()
	shade.resize(W * H)
	var ox := RECT.position.x
	var oz := RECT.position.y
	for r in rects:
		var rc: Rect2 = r
		var x0 := clampi(int(floor(rc.position.x - ox)), 0, W - 1)
		var x1 := clampi(int(ceil(rc.end.x - ox)) - 1, 0, W - 1)
		var z0 := clampi(int(floor(rc.position.y - oz)), 0, H - 1)
		var z1 := clampi(int(ceil(rc.end.y - oz)) - 1, 0, H - 1)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				shade[z * W + x] = 1.0
	for d in discs:
		var dv: Vector3 = d
		var rad := dv.z
		var cx := dv.x - ox
		var cz := dv.y - oz
		for z in range(clampi(int(cz - rad), 0, H - 1), clampi(int(cz + rad) + 1, 0, H - 1) + 1):
			for x in range(clampi(int(cx - rad), 0, W - 1), clampi(int(cx + rad) + 1, 0, W - 1) + 1):
				var dd := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
				if dd <= rad:
					shade[z * W + x] = maxf(shade[z * W + x], 0.85)
	shade = _blur(_blur(shade))
	var has_sea := inland.is_valid()
	var bytes := PackedByteArray()
	bytes.resize(W * H * 3)
	for z in range(H):
		for x in range(W):
			var i := z * W + x
			var g := 1.0
			if has_sea:
				g = clampf(0.5 + float(inland.call(ox + x + 0.5, oz + z + 0.5)) / 32.0, 0.0, 1.0)
			bytes[i * 3] = int(clampf(shade[i], 0.0, 1.0) * 255.0)
			bytes[i * 3 + 1] = int(g * 255.0)
			bytes[i * 3 + 2] = 0
	return ImageTexture.create_from_image(Image.create_from_data(W, H, false, Image.FORMAT_RGB8, bytes))

## One horizontal and one vertical box blur of radius 2.
static func _blur(src: PackedFloat32Array) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(W * H)
	for z in range(H):
		var row := z * W
		for x in range(W):
			var sum := 0.0
			for k in range(-2, 3):
				sum += src[row + clampi(x + k, 0, W - 1)]
			tmp[row + x] = sum * 0.2
	var out := PackedFloat32Array()
	out.resize(W * H)
	for z in range(H):
		for x in range(W):
			var sum2 := 0.0
			for k in range(-2, 3):
				sum2 += tmp[clampi(z + k, 0, H - 1) * W + x]
			out[z * W + x] = sum2 * 0.2
	return out
