# Procedural parts for the chibi characters: drawn anime faces, shaped hair shells
# with real fringes, lathe-turned bodies and the wisps' teardrop body.
# Pure mesh and texture generation; scripts/models.gd assembles the characters.
extends RefCounted

const HEAD_R := 0.6

## The face is drawn on a patch of the head sphere: longitude -FACE_LON..FACE_LON
## (0 = straight ahead, + = the character's left), latitude FACE_TOP down to -FACE_BOTTOM.
const FACE_LON := 66.0
const FACE_TOP := 38.0
const FACE_BOTTOM := 52.0
const FACE_PX := 384     # texture width; height follows the patch's aspect

static var _meshes := {}
static var _textures := {}

static func _dir(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))

# ---------------------------------------------------------------------
# Face
# ---------------------------------------------------------------------
## The curved patch the face texture sits on, just above the head sphere.
static func face_mesh() -> ArrayMesh:
	if _meshes.has("face"):
		return _meshes["face"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 22
	var rows := 15
	var r := HEAD_R * 1.004
	for j in range(cols):
		for i in range(rows):
			var quad: Array = []
			for c in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var u := float(j + c[0]) / cols
				var v := float(i + c[1]) / rows
				var d := _dir(lerpf(-FACE_LON, FACE_LON, u), lerpf(FACE_TOP, -FACE_BOTTOM, v))
				quad.append([d, Vector2(u, v)])
			for q in quad:
				st.set_normal(q[0])
				st.set_uv(q[1])
				st.add_vertex((q[0] as Vector3) * r)
	var mesh := st.commit()
	_meshes["face"] = mesh
	return mesh

static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

## Draws a face as SVG and rasterises it. Options:
##   skin, eye, hair: Color
##   eyes:  "round" | "sharp" | "gentle" | "closed" | "wink"
##   mouth: "smile" | "open" | "grin" | "flat" | "cat" | "o"
##   brow:  tilt in degrees (positive = stern, negative = worried)
##   male:  smaller eyes without long lashes
##   blush: bool
static func face_texture(o: Dictionary) -> Texture2D:
	var skin: Color = o.get("skin", Color(1.0, 0.89, 0.82))
	var eye: Color = o.get("eye", Color(0.3, 0.5, 0.9))
	var hair: Color = o.get("hair", Color(0.2, 0.15, 0.2))
	var eyes: String = o.get("eyes", "round")
	var mouth: String = o.get("mouth", "smile")
	var brow: float = o.get("brow", 0.0)
	var male: bool = o.get("male", false)
	var blush: bool = o.get("blush", true)
	var key := "face_%s_%s_%s_%s_%s_%s_%s_%s" % [skin.to_html(false), eye.to_html(false), hair.to_html(false), eyes, mouth, brow, male, blush]
	if _textures.has(key):
		return _textures[key]
	var ink := "#2a2038"
	var w := FACE_LON * 2.0
	var h := FACE_TOP + FACE_BOTTOM
	var s := '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="%s %s %s %s">' % [w, h, -FACE_LON, -FACE_TOP, w, h]
	s += '<defs><linearGradient id="iris" x1="0" y1="0" x2="0" y2="1">'
	s += '<stop offset="0" stop-color="%s"/><stop offset="0.5" stop-color="%s"/><stop offset="1" stop-color="%s"/>' % [_hex(eye.darkened(0.6)), _hex(eye), _hex(eye.lightened(0.5))]
	s += '</linearGradient></defs>'
	s += '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % [-FACE_LON, -FACE_TOP, w, h, _hex(skin)]
	var ex := 24.0
	var ey := 8.5
	var rx := 10.2 if male else 11.0
	var ry := 12.6 if male else 15.6
	if blush:
		for sg in [-1.0, 1.0]:
			s += '<ellipse cx="%s" cy="24" rx="8.2" ry="4.3" fill="#ff7fa8" opacity="0.4"/>' % [sg * 38.0]
	for sg in [-1.0, 1.0]:
		var closed: bool = eyes == "closed" or (eyes == "wink" and sg > 0.0)
		s += '<g transform="translate(%s %s) scale(%s 1)">' % [sg * ex, ey, sg]
		if closed:
			s += '<path d="M -9.5 3 Q 0 -9.5 9.5 3" fill="none" stroke="%s" stroke-width="3.6" stroke-linecap="round"/>' % ink
		else:
			# Outline, iris, shade under the lid, pupil, glow at the bottom
			s += '<ellipse rx="%s" ry="%s" fill="%s"/>' % [rx, ry, ink]
			s += '<ellipse cy="0.7" rx="%s" ry="%s" fill="url(#iris)"/>' % [rx - 1.9, ry - 2.1]
			s += '<ellipse cy="%s" rx="%s" ry="%s" fill="#000000" opacity="0.22"/>' % [-ry * 0.62, rx - 1.9, ry * 0.36]
			s += '<ellipse cy="-1.2" rx="3.5" ry="%s" fill="%s"/>' % [5.4 if not male else 4.6, _hex(eye.darkened(0.78))]
			s += '<ellipse cy="%s" rx="%s" ry="3.3" fill="%s" opacity="0.75"/>' % [ry * 0.52, rx * 0.55, _hex(eye.lightened(0.7))]
			if eyes == "sharp":
				# Slanted lid: the inner corner sits lower, for a determined look
				s += '<polygon points="%s,%s %s,%s %s,%s %s,%s" fill="%s"/>' % [-rx - 3, -ry - 3, rx + 4, -ry - 3, rx + 4, -ry * 0.72, -rx - 3, -ry * 0.34, _hex(skin)]
				s += '<path d="M %s %s L %s %s" fill="none" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % [-rx - 0.6, -ry * 0.34, rx + 2.2, -ry * 0.76, ink]
			elif eyes == "gentle":
				s += '<polygon points="%s,%s %s,%s %s,%s %s,%s" fill="%s"/>' % [-rx - 3, -ry - 3, rx + 4, -ry - 3, rx + 4, -ry * 0.42, -rx - 3, -ry * 0.72, _hex(skin)]
				s += '<path d="M %s %s Q 0 %s %s %s" fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round"/>' % [-rx - 0.4, -ry * 0.7, -ry * 0.72, rx + 1.8, -ry * 0.4, ink]
			else:
				s += '<path d="M %s %s Q %s %s 0.6 %s Q %s %s %s %s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % [-rx - 0.6, -ry * 0.3, -rx * 0.9, -ry - 0.9, -ry - 0.9, rx * 0.98, -ry - 0.6, rx + 1.9, -ry * 0.42, ink, 2.4 if male else 3.2]
			if not male:
				s += '<path d="M %s %s L %s %s" fill="none" stroke="%s" stroke-width="2.4" stroke-linecap="round"/>' % [rx + 0.8, -ry * 0.62, rx + 4.6, -ry * 0.86, ink]
		s += '</g>'
		if not closed:
			s += '<circle cx="%s" cy="%s" r="3.5" fill="#ffffff"/>' % [sg * ex - 3.3, ey - ry * 0.42]
			s += '<circle cx="%s" cy="%s" r="1.7" fill="#ffffff" opacity="0.9"/>' % [sg * ex + 3.6, ey + ry * 0.3]
		# Brow
		s += '<g transform="translate(%s %s) scale(%s 1) rotate(%s)">' % [sg * (ex + 0.5), ey - ry - 6.5, sg, brow]
		s += '<path d="M -7.5 0.8 Q 0 -1.8 8.5 0.4" fill="none" stroke="%s" stroke-width="2.7" stroke-linecap="round"/></g>' % _hex(hair.darkened(0.3))
	var lip := "#b03a58"
	match mouth:
		"open":
			s += '<path d="M -5.2 29.6 Q 0 39.4 5.2 29.6 Z" fill="#8f2a47" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % lip
			s += '<ellipse cx="0" cy="34.6" rx="2.5" ry="1.7" fill="#ff8fa3"/>'
		"grin":
			s += '<path d="M -7.4 29.2 Q 0 38 7.4 29.2 Z" fill="#ffffff" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % lip
		"flat":
			s += '<path d="M -3.6 31.8 L 3.6 31.8" fill="none" stroke="%s" stroke-width="1.9" stroke-linecap="round"/>' % lip
		"cat":
			s += '<path d="M -5.4 30.2 Q -2.7 34 0 30.8 Q 2.7 34 5.4 30.2" fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round"/>' % lip
		"o":
			s += '<ellipse cx="0" cy="32.4" rx="2.3" ry="2.9" fill="#8f2a47"/>'
		_:
			s += '<path d="M -4.8 30.4 Q 0 35.2 4.8 30.4" fill="none" stroke="%s" stroke-width="1.9" stroke-linecap="round"/>' % lip
	s += '</svg>'
	var img := Image.new()
	var err := img.load_svg_from_string(s, FACE_PX / w)
	if err != OK:
		img = Image.create(FACE_PX, int(FACE_PX * h / w), false, Image.FORMAT_RGBA8)
		img.fill(skin)
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex

# ---------------------------------------------------------------------
# Hair
# ---------------------------------------------------------------------
static func _tri(x: float) -> float:
	# Triangle wave: 0 at whole numbers, 1 halfway between
	return 1.0 - absf(fposmod(x, 1.0) - 0.5) * 2.0

static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

const FRINGE_HALF := 58.0   # the fringe spans longitudes -58..58

## Latitude of the hairline across the forehead for a fringe style.
static func _fringe(bangs: String, lon: float) -> float:
	var a := absf(lon)
	match bangs:
		"straight":
			return 12.5 + 1.3 * cos(lon * PI / FRINGE_HALF * 4.0) - 10.0 * _smooth((a - 44.0) / 14.0)
		"swept":
			var f := fposmod((lon + FRINGE_HALF) / 29.0, 1.0)
			var tip := f / 0.72 if f < 0.72 else (1.0 - f) / 0.28
			return 23.0 + 0.13 * lon - 13.0 * pow(tip, 0.8)
		"parted":
			return 35.0 - 25.0 * pow(a / FRINGE_HALF, 1.25) - 3.0 * _tri(a / 19.0 + 0.5) * _smooth(a / 20.0)
		"spiky":
			var k := (lon + FRINGE_HALF) / (FRINGE_HALF * 2.0 / 4.0)
			return 31.0 - 14.0 * pow(_tri(k), 0.75)
		"none":
			return 30.0
		_:
			# Five pointed locks, the middle one longest
			var k2 := (lon + FRINGE_HALF) / (FRINGE_HALF * 2.0 / 5.0)
			return 27.0 - (17.0 - 3.5 * a / FRINGE_HALF) * pow(_tri(k2), 0.7)

## A hair shell around the head with a shaped fringe, side locks and optional length.
##   bangs: "zigzag" | "straight" | "swept" | "parted" | "spiky" | "none"
##   length: "short" | "bob" | "long"
static func hair_mesh(bangs: String, length: String) -> ArrayMesh:
	var key := "hair_%s_%s" % [bangs, length]
	if _meshes.has(key):
		return _meshes[key]
	var cols := 72
	var rows := 10
	var drops := 7
	var side_lat := -26.0
	var back_lat := -40.0
	var grid: Array = []   # grid[j][i] = [position, normal]
	for j in range(cols + 1):
		var lon := -180.0 + 360.0 * j / cols
		var a := absf(lon)
		var edge := _fringe(bangs, FRINGE_HALF if lon > 0.0 else -FRINGE_HALF)
		var lat_min: float
		if a <= FRINGE_HALF:
			lat_min = _fringe(bangs, lon)
		elif a <= 96.0:
			lat_min = lerpf(edge, side_lat, _smooth((a - FRINGE_HALF) / 16.0))
		else:
			lat_min = lerpf(side_lat, back_lat, _smooth((a - 96.0) / 40.0)) + 3.5 * _tri(a / 21.0)
		# How far the hair hangs below the shell
		var drop := 0.0
		match length:
			"bob":
				drop = 0.46 * _smooth((a - 60.0) / 16.0)
			"long":
				drop = lerpf(0.66, 1.3, _smooth((a - 92.0) / 44.0)) * _smooth((a - 60.0) / 14.0)
		drop *= 1.0 - 0.2 * _tri(a / 15.0)
		var column: Array = []
		for i in range(rows + 1):
			var lat := lerpf(90.0, lat_min, float(i) / rows)
			var d := _dir(lon, lat)
			var puff := 1.085 + 0.04 * maxf(0.0, sin(deg_to_rad(lat))) + 0.02 * _smooth((a - 100.0) / 60.0)
			column.append([d * HEAD_R * puff, d])
		var e: Vector3 = column[rows][0]
		var flat_n := Vector3(e.x, 0, e.z).normalized()
		for k in range(1, drops + 1):
			var t := float(k) / drops
			var widen := 1.0 + 0.07 * t - 0.1 * t * t * t
			column.append([Vector3(e.x * widen, e.y - drop * t, e.z * widen), flat_n if drop > 0.01 else (column[rows][1] as Vector3)])
		grid.append(column)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := rows + drops
	for j in range(cols):
		for i in range(total):
			var a0: Array = grid[j][i]
			var b0: Array = grid[j + 1][i]
			var c0: Array = grid[j + 1][i + 1]
			var d0: Array = grid[j][i + 1]
			for q in [a0, b0, c0, a0, c0, d0]:
				st.set_normal(q[1])
				st.add_vertex(q[0])
		# Rim: gives the bottom edge some thickness
		var o1: Vector3 = grid[j][total][0]
		var o2: Vector3 = grid[j + 1][total][0]
		var n1: Vector3 = grid[j][total][1]
		var n2: Vector3 = grid[j + 1][total][1]
		var i1 := o1 - n1 * 0.05
		var i2 := o2 - n2 * 0.05
		for q2 in [[o1, n1], [i2, n2], [o2, n2], [o1, n1], [i1, n1], [i2, n2]]:
			st.set_normal(q2[1])
			st.add_vertex(q2[0])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

## The band of light across the crown ("angel ring").
static func shine_mesh() -> ArrayMesh:
	if _meshes.has("shine"):
		return _meshes["shine"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 40
	var span := 104.0
	var pts: Array = []
	for j in range(cols + 1):
		var lon := lerpf(-span, span, float(j) / cols)
		var fade := 1.0 - pow(absf(lon) / span, 2.2)
		var mid := 52.0 + 1.5 * cos(deg_to_rad(lon * 2.0))
		var half := 4.3 * fade
		var zig := 2.4 * _tri(lon / 13.0) * fade
		var r := HEAD_R * (1.085 + 0.04 * sin(deg_to_rad(mid)) + 0.006)
		pts.append([_dir(lon, mid + half), _dir(lon, mid - half - zig), r])
	for j in range(cols):
		var a: Array = pts[j]
		var b: Array = pts[j + 1]
		for q in [[a[0], a[2]], [b[0], b[2]], [b[1], b[2]], [a[0], a[2]], [b[1], b[2]], [a[1], a[2]]]:
			st.set_normal(q[0])
			st.add_vertex((q[0] as Vector3) * float(q[1]))
	var mesh := st.commit()
	_meshes["shine"] = mesh
	return mesh

# ---------------------------------------------------------------------
# Lathe-turned shapes
# ---------------------------------------------------------------------
static func _catmull(points: Array, sub: int) -> Array:
	var out: Array = []
	for i in range(points.size() - 1):
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for k in range(sub):
			var t := float(k) / sub
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[points.size() - 1])
	return out

## Surface of revolution around Y. `profile` lists Vector2(radius, height) from the
## bottom up; it is smoothed first. `bend` curls the top backwards (for wisps).
static func lathe(key: String, profile: Array, seg: int = 24, cap_bottom: bool = false, bend: float = 0.0) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var pts := _catmull(profile, 3)
	var n := pts.size()
	var y0: float = (pts[0] as Vector2).y
	var y1: float = (pts[n - 1] as Vector2).y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = []
	for i in range(n):
		var p: Vector2 = pts[i]
		var prev: Vector2 = pts[maxi(i - 1, 0)]
		var next: Vector2 = pts[mini(i + 1, n - 1)]
		var tan := (next - prev).normalized()
		var nrm2 := Vector2(tan.y, -tan.x)   # outward in the (radius, height) plane
		var row: Array = []
		var curl := bend * pow(maxf(0.0, (p.y - lerpf(y0, y1, 0.45)) / maxf(0.001, y1 - y0)), 1.7)
		for j in range(seg + 1):
			var a := TAU * j / seg
			row.append([Vector3(sin(a) * p.x, p.y, cos(a) * p.x - curl), Vector3(sin(a) * nrm2.x, nrm2.y, cos(a) * nrm2.x).normalized()])
		ring.append(row)
	for i in range(n - 1):
		for j in range(seg):
			var a0: Array = ring[i + 1][j]
			var b0: Array = ring[i + 1][j + 1]
			var c0: Array = ring[i][j + 1]
			var d0: Array = ring[i][j]
			for q in [a0, b0, c0, a0, c0, d0]:
				st.set_normal(q[1])
				st.add_vertex(q[0])
	if cap_bottom:
		var c := Vector3(0, y0, 0)
		for j in range(seg):
			for q2 in [c, (ring[0][j][0] as Vector3), (ring[0][j + 1][0] as Vector3)]:
				st.set_normal(Vector3.DOWN)
				st.add_vertex(q2)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

## A wisp: a round drop whose pointed tip curls back. One unit in radius.
static func teardrop() -> ArrayMesh:
	return lathe("teardrop", [
		Vector2(0.0, -0.96), Vector2(0.5, -0.86), Vector2(0.88, -0.5), Vector2(1.0, -0.02), Vector2(0.94, 0.4),
		Vector2(0.72, 0.8), Vector2(0.46, 1.12), Vector2(0.25, 1.4), Vector2(0.1, 1.64), Vector2(0.0, 1.8),
	], 24, false, 0.62)

# ---------------------------------------------------------------------
# Wisp faces: eyes, highlights, mouth, blush and a gloss spot merged into one
# vertex-coloured mesh, so each spirit's whole face is a single draw call.
# ---------------------------------------------------------------------
static func _blob(st: SurfaceTool, centre: Vector3, radii: Vector3, col: Color, tilt: float = 0.0) -> void:
	var seg := 10
	var rings := 6
	var basis := Basis(Vector3(0, 0, 1), tilt) * Basis.from_scale(radii)
	for i in range(rings):
		for j in range(seg):
			var corners: Array = []
			for c in [[0, 0], [0, 1], [1, 1], [0, 0], [1, 1], [1, 0]]:
				var v := PI * float(i + c[0]) / rings
				var u := TAU * float(j + c[1]) / seg
				corners.append(Vector3(sin(v) * sin(u), cos(v), sin(v) * cos(u)))
			for d in corners:
				st.set_color(col)
				st.set_normal(d)
				st.add_vertex(centre + basis * (d as Vector3))

## kind: "wisp" (cute), "shadow" (red eyes), "mask" (stern slits)
static func wisp_face(kind: String = "wisp") -> ArrayMesh:
	var key := "wispface_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color(0.13, 0.08, 0.17)
	var eye := Color(1.0, 0.3, 0.42) if kind == "shadow" else dark
	if kind == "mask":
		for sg in [-1.0, 1.0]:
			_blob(st, Vector3(0.34 * sg, 0.12, 0.925), Vector3(0.2, 0.075, 0.05), dark, -0.38 * sg)
			_blob(st, Vector3(0.36 * sg, 0.13, 0.965), Vector3(0.05, 0.04, 0.02), Color(1.0, 0.85, 0.3))
		_blob(st, Vector3(0.0, -0.3, 0.945), Vector3(0.2, 0.04, 0.03), dark)
	else:
		for sg in [-1.0, 1.0]:
			_blob(st, Vector3(0.33 * sg, 0.1, 0.915), Vector3(0.15, 0.225, 0.06), eye)
			_blob(st, Vector3(0.33 * sg + 0.055, 0.2, 0.972), Vector3(0.055, 0.07, 0.02), Color.WHITE)
			_blob(st, Vector3(0.33 * sg - 0.05, 0.0, 0.975), Vector3(0.028, 0.034, 0.015), Color.WHITE)
			_blob(st, Vector3(0.6 * sg, -0.13, 0.765), Vector3(0.12, 0.065, 0.03), Color(1.0, 0.56, 0.7))
		if kind == "shadow":
			for sg2 in [-1.0, 1.0]:
				_blob(st, Vector3(0.33 * sg2, 0.36, 0.9), Vector3(0.17, 0.035, 0.03), Color(0.1, 0.06, 0.14), -0.4 * sg2)
		_blob(st, Vector3(0.0, -0.2, 0.972), Vector3(0.07, 0.042, 0.02), Color(0.45, 0.14, 0.25))
	# Gloss spot on the upper left, like a wet jelly
	_blob(st, Vector3(-0.44, 0.56, 0.69), Vector3(0.17, 0.1, 0.035), Color.WHITE, 0.6)
	_blob(st, Vector3(-0.62, 0.36, 0.69), Vector3(0.05, 0.04, 0.02), Color.WHITE)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh
