extends RefCounted
## Deterministic cube physics, shared by the game and the level checker. Runs at a fixed 120 steps per second.
##
## Object kinds (k): 0 block, 1 spike, 2 saw, 3 gravity orb, 4 gravity pad,
## 5 gravity portal, 6 speed portal, 7 size portal, 8 dual portal.
## Dual mode: a mirrored twin cube runs on the opposite lane with opposite gravity. One press flips both;
## if either one crashes, the run is over.

const PS := 30.0
const MINI := 16.0
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
	var spd := 1.0
	var ps := 30.0
	var orb := -1
	var event := ""
	var used := {}
	var path: Array = []
	var twin = null        # the second cube while in dual mode
	var twin_died := false

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
		c.spd = spd
		c.ps = ps
		c.orb = orb
		c.event = event
		c.used = used.duplicate()
		c.path = path.duplicate()
		c.twin = twin.copy() if twin != null else null
		c.twin_died = twin_died
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


static func _hit(ax: float, ay: float, size: float, b: Dictionary) -> bool:
	return ax < b.x + b.w and ax + size > b.x and ay < b.y + b.h and ay + size > b.y


static func touching(s, lv: Dictionary, dy: float) -> bool:
	var y: float = s.y + dy
	var ps: float = s.ps
	if y + ps > FLOOR or y < CEIL:
		return true
	var o: Array = lv.objs
	var px: float = s.x
	var i := first_idx(o, px - float(lv.max_w))
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + ps:
			break
		i += 1
		if b.k == 0 and _hit(px, y, ps, b):
			return true
	return false


static func _flip(s, kick: float, ev: String) -> void:
	s.g = -s.g
	s.vy = s.g * kick
	s.coy = 0.0
	s.buf = 0.0
	s.ground = false
	s.flipped = true
	s.event = ev


static func step(s, lv: Dictionary, press: bool) -> void:
	var o: Array = lv.objs
	var i0 := first_idx(o, float(s.x) - float(lv.max_w) - 20.0)
	s.x += float(lv.speed) * s.spd * DT
	_body(s, lv, press, i0, true)
	if s.dead:
		return
	if s.twin != null:
		var t = s.twin
		t.x = s.x
		t.spd = s.spd
		t.ps = s.ps
		_body(t, lv, press, i0, false)
		if t.dead:
			s.dead = true
			s.twin_died = true
			return
		if t.flipped and not s.flipped:
			s.flipped = true
			s.event = t.event
	if float(s.x) >= float(lv.end):
		s.won = true
	s.f += 1


## Moves one cube vertically and checks it against everything. The primary cube also handles portals.
static func _body(s, lv: Dictionary, press: bool, i0: int, primary: bool) -> void:
	s.flipped = false
	s.event = ""
	if press:
		s.buf = BUFFER
	if s.buf > 0.0:
		if s.orb >= 0:
			s.used[s.orb] = true
			s.orb = -1
			_flip(s, KICK * 1.6, "orb")
		elif s.coy > 0.0:
			_flip(s, KICK, "flip")
	s.buf -= DT
	s.vy = clampf(s.vy + s.g * G * DT, -VMAX, VMAX)

	var o: Array = lv.objs
	var ps: float = s.ps
	var px: float = s.x

	# Horizontal move: small overlaps snap onto a block, anything else is a crash.
	var i := i0
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + ps:
			break
		i += 1
		if b.k != 0 or not _hit(px, s.y, ps, b):
			continue
		var top: float = s.y + ps - b.y
		var bot: float = b.y + b.h - s.y
		if top <= SNAP:
			s.y = b.y - ps
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
	if s.y + ps > FLOOR:
		s.y = FLOOR - ps
		s.vy = 0.0
	if s.y < CEIL:
		s.y = CEIL
		s.vy = 0.0
	i = i0
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + ps:
			break
		i += 1
		if b.k != 0 or not _hit(px, s.y, ps, b):
			continue
		if py + ps * 0.5 < b.y + b.h * 0.5:
			s.y = b.y - ps
		else:
			s.y = b.y + b.h
		s.vy = 0.0

	s.ground = touching(s, lv, s.g)
	s.coy = COYOTE if s.ground else s.coy - DT

	# Hazards and special objects
	var inset := ps * 0.1
	var hx: float = px + inset
	var hy: float = s.y + inset
	var hw := ps - inset * 2.0
	s.orb = -1
	i = i0
	while i < o.size():
		var b: Dictionary = o[i]
		if b.x >= px + ps:
			break
		i += 1
		var k := int(b.k)
		if k >= 5 and not primary:
			continue
		match k:
			1:
				var sy: float = (b.y + 12.0) if b.up else b.y
				if hx < b.x + 27.0 and hx + hw > b.x + 13.0 and hy < sy + 28.0 and hy + hw > sy:
					s.dead = true
					return
			2:
				if _circle_hit(b.cx, b.cy, float(b.r) - 2.0, hx, hy, hw):
					s.dead = true
					return
			3:
				if not s.used.has(b.id) and _circle_hit(b.cx, b.cy, float(b.r) + 8.0, px, s.y, ps):
					s.orb = b.id
			4:
				if not s.used.has(b.id) and _hit(px, s.y - 2.0, ps + 4.0, b) and ((b.up and s.g > 0.0) or (not b.up and s.g < 0.0)):
					s.used[b.id] = true
					_flip(s, KICK * 1.3, "pad")
			5:
				if not s.used.has(b.id) and px + ps > b.x:
					s.used[b.id] = true
					if s.g != float(b.dir):
						s.g = float(b.dir)
						s.vy = s.g * KICK * 0.5
						s.coy = 0.0
						s.ground = false
						s.flipped = true
					s.event = "portal"
			6:
				if not s.used.has(b.id) and px + ps > b.x:
					s.used[b.id] = true
					s.spd = float(b.mul)
					s.event = "speed"
			7:
				if not s.used.has(b.id) and px + ps > b.x:
					s.used[b.id] = true
					var n: float = MINI if b.mini else PS
					if n != s.ps:
						if s.g > 0.0:
							s.y += s.ps - n
						s.ps = n
					s.event = "size"
			8:
				if not s.used.has(b.id) and px + ps > b.x:
					s.used[b.id] = true
					s.event = "dual"
					if b.dual and s.twin == null:
						# The twin appears mirrored: same height from the opposite lane, opposite gravity.
						var t = State.new()
						t.x = s.x
						t.ps = s.ps
						t.spd = s.spd
						t.y = CEIL + FLOOR - s.y - s.ps
						t.vy = -s.vy
						t.g = -s.g
						t.ground = false
						t.coy = 0.0
						s.twin = t
					elif not b.dual:
						s.twin = null


static func _circle_hit(cx: float, cy: float, r: float, rx: float, ry: float, rw: float) -> bool:
	var qx := clampf(cx, rx, rx + rw)
	var qy := clampf(cy, ry, ry + rw)
	return (cx - qx) * (cx - qx) + (cy - qy) * (cy - qy) < r * r


## Depth-first search over "press now or not" whenever a flip is possible (on a surface, or touching an orb).
## Returns ok plus the frames to press on: a winning input recording.
static func solve(lv: Dictionary, budget := 3000000) -> Dictionary:
	var stack: Array = [State.new()]
	var seen := {}
	var n := 0
	var far := 0.0
	while not stack.is_empty() and n < budget:
		var s = stack.pop_back()
		while not s.dead and not s.won and not _can_act(s):
			step(s, lv, false)
			n += 1
		far = maxf(far, s.x)
		if s.won:
			return {"ok": true, "n": n, "path": s.path, "end": lv.end}
		if s.dead:
			continue
		var key := Vector4i(int(s.x / 4.0), int(s.y), int(s.g) * 2 + (1 if s.orb >= 0 else 0), (int(s.twin.y) * 4 + int(s.twin.g) + 2) if s.twin != null else -1)
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


static func _can_act(s) -> bool:
	if (s.coy > 0.0 and s.f % 4 == 0) or (s.orb >= 0 and s.f % 2 == 0):
		return true
	if s.twin != null:
		return (s.twin.coy > 0.0 and s.f % 4 == 0) or (s.twin.orb >= 0 and s.f % 2 == 0)
	return false
