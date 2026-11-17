extends RefCounted
## Deterministic cube physics, shared by the game and the level checker.
## The game runs it at a fixed 120 steps per second.

const PS := 30.0
const G := 5200.0
const VMAX := 1150.0
const KICK := 180.0
const SNAP := 10.0
const COYOTE := 0.07
const BUFFER := 0.13
const DT := 1.0 / 120.0
const CEIL := 40.0
const FLOOR := 360.0


class State:
	var x := 0.0
	var y := 330.0
	var vy := 0.0
	var g := 1.0
	var ground := true
	var coy := 0.07
	var buf := 0.0
	var dead := false
	var won := false
	var flipped := false
	var f := 0
	var path: Array = []

	func copy():
		var c = get_script().new()
		c.x = x
		c.y = y
		c.vy = vy
		c.g = g
		c.ground = ground
		c.coy = coy
		c.buf = buf
		c.dead = dead
		c.won = won
		c.flipped = flipped
		c.f = f
		c.path = path.duplicate()
		return c


static func first_idx(o: Array, min_x: float) -> int:
	var lo := 0
	var hi := o.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float(o[mid].x) < min_x:
			lo = mid + 1
		else:
			hi = mid
	return lo


static func _hit(ax: float, ay: float, b: Dictionary) -> bool:
	return ax < b.x + b.w and ax + PS > b.x and ay < b.y + b.h and ay + PS > b.y


static func touching(s, lv: Dictionary, dy: float) -> bool:
	var y: float = s.y + dy
	if y + PS > FLOOR or y < CEIL:
		return true
	var o: Array = lv.objs
	var px: float = s.x
	var i := first_idx(o, px - float(lv.max_w))
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + PS:
			break
		i += 1
		if b.k == 0 and _hit(px, y, b):
			return true
	return false


static func step(s, lv: Dictionary, press: bool) -> void:
	s.flipped = false
	if press:
		s.buf = BUFFER
	if s.buf > 0.0 and s.coy > 0.0:
		s.g = -s.g
		s.vy = s.g * KICK
		s.coy = 0.0
		s.buf = 0.0
		s.ground = false
		s.flipped = true
	s.buf -= DT
	s.vy = clampf(s.vy + s.g * G * DT, -VMAX, VMAX)

	var o: Array = lv.objs
	var i0 := first_idx(o, float(s.x) - float(lv.max_w) - 20.0)
	s.x += float(lv.speed) * DT
	var px: float = s.x

	# Horizontal move: small overlaps snap onto a block, anything else is a crash.
	var i := i0
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + PS:
			break
		i += 1
		if b.k != 0 or not _hit(px, s.y, b):
			continue
		var top: float = s.y + PS - b.y
		var bot: float = b.y + b.h - s.y
		if top <= SNAP:
			s.y = b.y - PS
			if s.vy > 0.0:
				s.vy = 0.0
		elif bot <= SNAP:
			s.y = b.y + b.h
			if s.vy < 0.0:
				s.vy = 0.0
		else:
			s.dead = true
			return

	# Vertical move: land on floor, ceiling or blocks.
	var py: float = s.y
	s.y += s.vy * DT
	if s.y + PS > FLOOR:
		s.y = FLOOR - PS
		s.vy = 0.0
	if s.y < CEIL:
		s.y = CEIL
		s.vy = 0.0
	i = i0
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + PS:
			break
		i += 1
		if b.k != 0 or not _hit(px, s.y, b):
			continue
		if py + PS * 0.5 < b.y + b.h * 0.5:
			s.y = b.y - PS
		else:
			s.y = b.y + b.h
		s.vy = 0.0

	s.ground = touching(s, lv, s.g)
	s.coy = COYOTE if s.ground else s.coy - DT

	# Hazards use forgiving hitboxes.
	var hx: float = px + 3.0
	var hy: float = s.y + 3.0
	var hw := PS - 6.0
	i = i0
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + PS:
			break
		i += 1
		if b.k == 1:
			var sy: float = (b.y + 12.0) if b.up else b.y
			if hx < b.x + 27.0 and hx + hw > b.x + 13.0 and hy < sy + 28.0 and hy + hw > sy:
				s.dead = true
				return
		elif b.k == 2:
			var cx: float = b.cx
			var cy: float = b.cy
			var qx := clampf(cx, hx, hx + hw)
			var qy := clampf(cy, hy, hy + hw)
			var r: float = b.r - 2.0
			if (cx - qx) * (cx - qx) + (cy - qy) * (cy - qy) < r * r:
				s.dead = true
				return
	if px >= float(lv.end):
		s.won = true
	s.f += 1


## Depth-first search over "flip now or not" whenever the cube is on a surface.
## Returns ok plus the list of frames to flip on (a winning input recording).
static func solve(lv: Dictionary) -> Dictionary:
	var stack: Array = [State.new()]
	var seen := {}
	var n := 0
	var far := 0.0
	while not stack.is_empty() and n < 4000000:
		var s = stack.pop_back()
		while not s.dead and not s.won and not (s.coy > 0.0 and s.f % 4 == 0):
			step(s, lv, false)
			n += 1
		far = maxf(far, s.x)
		if s.won:
			return {"ok": true, "n": n, "path": s.path, "end": lv.end}
		if s.dead:
			continue
		var key := Vector3i(int(s.x / 4.0), int(s.y), int(s.g))
		if seen.has(key):
			continue
		seen[key] = true
		var a = s.copy()
		a.path.append(a.f)
		step(a, lv, true)
		var b = s.copy()
		step(b, lv, false)
		n += 2
		stack.append(a)
		stack.append(b)
	return {"ok": false, "n": n, "far": far, "end": lv.end, "path": []}
