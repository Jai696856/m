# Generates the 46 grid track routes and writes scripts/maps.gd:  python3 tools/mapgen.py scripts/maps.gd
import random, sys
COLS, ROWS = 15, 9          # cols 0..14 (col 15 sits under the shop panel), rows 0..8
DIRS = {'N': (0, -1), 'S': (0, 1), 'E': (1, 0), 'W': (-1, 0)}
LEFT = {'N': 'W', 'W': 'S', 'S': 'E', 'E': 'N'}
RIGHT = {v: k for k, v in LEFT.items()}

def inside(c): return 0 <= c[0] < COLS and 0 <= c[1] < ROWS
def add(c, d): return (c[0] + DIRS[d][0], c[1] + DIRS[d][1])

def edge_dir(c):
    """Outward directions available from a boundary cell."""
    out = []
    if c[1] == 0: out.append('N')
    if c[1] == ROWS - 1: out.append('S')
    if c[0] == 0: out.append('W')
    if c[0] == COLS - 1: out.append('E')
    return out

def gen(rng, lo, hi, edges):
    # entry
    side = rng.choice(edges)
    if side == 'N': first, d = (rng.randrange(1, COLS - 1), 0), 'S'
    elif side == 'S': first, d = (rng.randrange(1, COLS - 1), ROWS - 1), 'N'
    else: first, d = (0, rng.randrange(1, ROWS - 1)), 'E'   # 'W'
    entry = add(first, {'S': 'N', 'N': 'S', 'E': 'W'}[d])
    cells = [entry, first]
    used = {first}
    run = 1
    for _ in range(400):
        cur = cells[-1]
        # can we finish here?
        if len(cells) - 1 >= lo:
            for od in edge_dir(cur):
                opp = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}[od]
                if od == 'E' or od == opp: continue
                if od not in edges and not (od == 'W' and 'W' in edges): continue
                if od != d and run < 2: continue
                if od == {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}[d]: continue
                ex = add(cur, od)
                # exit must not sit next to the entry
                if abs(ex[0] - entry[0]) + abs(ex[1] - entry[1]) <= 2: continue
                cells.append(ex)
                return cells
        if len(cells) - 1 >= hi: return None
        opts = []
        if run < 2: choices = [(d, 1.0)]
        else: choices = [(d, 0.45 if run < 5 else 0.1), (LEFT[d], 0.3), (RIGHT[d], 0.3)]
        rng.shuffle(choices)
        choices.sort(key=lambda t: -t[1] * rng.random())
        moved = False
        for nd, _w in choices:
            nc = add(cur, nd)
            if not inside(nc) or nc in used: continue
            ok = True
            for k in DIRS:
                nb = add(nc, k)
                if nb != cur and nb in used: ok = False; break
            if not ok: continue
            # keep a 1-cell gap from the entry stub too
            if abs(nc[0] - entry[0]) + abs(nc[1] - entry[1]) == 1 and nc != first: continue
            cells.append(nc); used.add(nc)
            run = run + 1 if nd == d else 1
            d = nd; moved = True
            break
        if not moved: return None
    return None

def waypoints(cells):
    wp = [cells[0]]
    for i in range(1, len(cells) - 1):
        a, b, c = cells[i - 1], cells[i], cells[i + 1]
        if (b[0] - a[0], b[1] - a[1]) != (c[0] - b[0], c[1] - b[1]): wp.append(b)
    wp.append(cells[-1]); return wp

def validate(cells):
    idx = {c: i for i, c in enumerate(cells)}
    if len(idx) != len(cells): return False
    for i, c in enumerate(cells):
        if i and abs(c[0]-cells[i-1][0]) + abs(c[1]-cells[i-1][1]) != 1: return False
        for k in DIRS:
            n = add(c, k)
            if n in idx and abs(idx[n] - i) > 1: return False
    return True

def free_space(cells):
    """Count grass cells at least one cell away from the track (room for heroes/props)."""
    s = set(cells); n = 0
    for x in range(COLS):
        for y in range(ROWS):
            if (x, y) in s: continue
            if all((x+dx, y+dy) not in s for dx in (-1,0,1) for dy in (-1,0,1)): n += 1
    return n

TIERS = [('beginner', 50, 64, 13), ('intermediate', 41, 50, 12), ('advanced', 33, 41, 11), ('expert', 24, 33, 10)]
THEMES = ['meadow', 'autumn', 'snow', 'desert', 'sakura', 'dusk']
SHORES = ['left', 'top', 'bottom', 'none']
NAMES = {
 'beginner': ['Lantern Lane', 'Old Mill Meadow', 'Maple Hollow', 'Frostbell Fields', 'Sunstone Oasis', 'Petal Path',
              'Firefly Bend', 'Clover Coast', 'Amber Orchard', 'Snowdrop Ridge', 'Dune Market', 'Blossom Steps'],
 'intermediate': ['Twin Torii', 'Harvest Loop', 'Moonlit Moat', 'Pine Pass', 'Mirage Road', 'Cherry Terrace',
                  'Kitsune Crossing', 'Copperleaf Way', 'Glacier Gate', 'Saltwind Bay', 'Willow Wynd', 'Crimson Fall'],
 'advanced': ['Shrine Spiral', 'Ember Woods', 'Iceveil Maze', 'Sandglass Run', 'Hanami Knot', 'Tidewatch',
              'Lotus Labyrinth', 'Rustleaf Ridge', 'Aurora Steps', 'Scorpion Gulch', 'Starfall Garden'],
 'expert': ['Oni Gate', 'Wildfire Hollow', 'Whiteout', 'Sunscorch', 'Last Petal', 'Nightshade',
            'Thunder Shrine', 'Ashen Grove', 'Blizzard Peak', 'Mirage Throne'],
}

POOLS = {
 'meadow': ['Clover Coast', 'Lantern Lane', 'Old Mill Meadow', 'Willow Wynd', 'Firefly Bend', 'Twin Torii', 'Tidewatch', 'Thunder Shrine'],
 'autumn': ['Maple Hollow', 'Amber Orchard', 'Harvest Loop', 'Copperleaf Way', 'Rustleaf Ridge', 'Ember Woods', 'Ashen Grove', 'Wildfire Hollow'],
 'snow': ['Frostbell Fields', 'Snowdrop Ridge', 'Pine Pass', 'Glacier Gate', 'Iceveil Maze', 'Aurora Steps', 'Whiteout', 'Blizzard Peak'],
 'desert': ['Sunstone Oasis', 'Dune Market', 'Mirage Road', 'Saltwind Bay', 'Sandglass Run', 'Scorpion Gulch', 'Sunscorch', 'Mirage Throne'],
 'sakura': ['Petal Path', 'Blossom Steps', 'Cherry Terrace', 'Kitsune Crossing', 'Hanami Knot', 'Lotus Labyrinth', 'Last Petal', 'Shrine Spiral'],
 'dusk': ['Moonlit Moat', 'Twilight Pier', 'Owl Hollow', 'Ghostlight Bridge', 'Starfall Garden', 'Midnight Torii', 'Nightshade', 'Oni Gate'],
}
rng = random.Random(20261111)
maps = []
# Map 1 keeps the hand-made original route.
ORIG = [(3,-2),(3,1),(10,1),(10,3),(6,3),(6,5),(2,5),(2,7),(8,7),(8,5),(12,5),(12,3),(14,3),(14,7),(11,7),(11,8)]
def expand(wp):
    cells = [wp[0]]
    for a, b in zip(wp, wp[1:]):
        sx = (b[0] > a[0]) - (b[0] < a[0]); sy = (b[1] > a[1]) - (b[1] < a[1]); c = a
        while c != b: c = (c[0]+sx, c[1]+sy); cells.append(c)
    return cells
assert validate(expand(ORIG))
maps.append(dict(id='sakura_shore', name='Sakura Shore', tier='beginner', theme='meadow', shore='left', route=ORIG))
mi = 1
for tier, lo, hi, count in TIERS:
    names = NAMES[tier]
    made = 0 if tier != 'beginner' else 1
    k = 0
    while made < count:
        theme = THEMES[mi % len(THEMES)]
        shore = SHORES[(mi * 7) % len(SHORES)]
        if theme == 'desert' and shore == 'none': shore = 'bottom'
        edges = [e for e in ['N', 'S', 'W'] if not ({'left': 'W', 'top': 'N', 'bottom': 'S'}.get(shore) == e)]
        best = None
        for attempt in range(6000):
            cells = gen(rng, lo, hi, edges)
            if not cells or not validate(cells): continue
            inner = [c for c in cells if inside(c)]
            bw = max(c[0] for c in inner) - min(c[0] for c in inner) + 1
            bh = max(c[1] for c in inner) - min(c[1] for c in inner) + 1
            # Prefer tracks that spread over the board rather than huddling in a corner.
            score = bw * bh + rng.random() * 6
            if free_space(cells) < 18: continue
            if best is None or score > best[0]: best = (score, cells)
            if attempt > 600 and best: break
        if not best: continue
        cells = best[1]
        name = POOLS[theme].pop(0); k += 1
        maps.append(dict(id=name.lower().replace(' ', '_').replace("'", ''), name=name, tier=tier, theme=theme, shore=shore,
                         route=waypoints(cells)))
        made += 1; mi += 1

assert len(maps) == 46, len(maps)
for m in maps:
    c = expand(m['route']); assert validate(c), m['name']
    m['len'] = len(c) - 1
out = ['# Generated by tools/mapgen.py: every map is a grid route (see scripts/track/track.gd).',
       '# Tiers: beginner (long tracks) -> expert (short tracks, less time to pop spirits).',
       'extends RefCounted', '', 'const MAPS := [']
for i, m in enumerate(maps):
    r = ', '.join('Vector2i(%d, %d)' % p for p in m['route'])
    out.append('\t{"id": "%s", "name": "%s", "tier": "%s", "theme": "%s", "shore": "%s", "seed": %d,' % (m['id'], m['name'], m['tier'], m['theme'], m['shore'], 1000 + i * 37))
    out.append('\t\t"route": [%s]},' % r)
out.append(']')
out.append('')
out.append('const TIERS := ["beginner", "intermediate", "advanced", "expert"]')
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
from collections import Counter
print(Counter(m['tier'] for m in maps), Counter(m['theme'] for m in maps), Counter(m['shore'] for m in maps))
for m in maps: print(m['tier'][:3], m['len'], m['shore'], m['theme'], m['name'])
