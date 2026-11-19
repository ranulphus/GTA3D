class_name RoadGraph
extends RefCounted

## A drivable road network derived from the city's road tiles — the way GTA1's
## engine generated ambient traffic at runtime. The .CMP map stores no lane network
## (its tiny `routes` block is only train/scripted paths, and the per-tile movement
## bits are unused on roads), so we rebuild it from the road surface.
##
## Every drivable road SURFACE becomes a node — and a cell can hold several, one per
## level: an overpass deck and the street running under it are separate nodes, keyed
## Vector3i(map x, map y, level). Two 4-adjacent nodes link only where their surfaces
## meet at the same height along the shared edge (computed from the block shape, so
## ramps join the levels they climb between, while a deck never "steps" onto the
## street a level below it). This is the FULL road grid — deliberately not thinned to
## a centre line: a thinned skeleton fragments at junctions into dead-end stubs that
## trap cars in tiny loops. Traffic stays on real streets by preferring to drive
## straight (see TrafficDriver), turning only at genuine junctions/ends.
##
## World mapping matches MapBuilder: map x -> world X, map y -> world Z, and the
## surface block's stack level z puts the drivable top at world Y = z + 1.

const BUILDING_TYPE := 5      # block_type for buildings — a road sealed under one isn't drivable
const EDGE_TOL := 0.3          # how closely two surfaces' shared edge heights must match to link
const DIM := GTA1Map.DIM
const LANE_OFFSET := 0.22     # how far right of centre a lane sits (drive-on-the-right)

## The carriageway LID tiles for NYC (STYLE001), identified by eye from the swatch
## sheets — full road surfaces incl. 90-degree turns and the SLOW markings (133-135).
## NOT laybys (38/51/54/60/61/62 — never driven) or pavement (8/9). Tile indices are
## per-style, so MIAMI/SANB will need their own sets.
const ROAD_TILES := {
	1: true, 2: true, 3: true, 4: true, 5: true, 6: true, 13: true, 16: true, 23: true,
	24: true, 25: true, 70: true, 74: true, 75: true, 76: true, 80: true, 81: true,
	82: true, 89: true, 90: true, 119: true, 120: true, 122: true, 133: true, 134: true,
	135: true,
}


## The right-hand side of a horizontal travel direction, in world axes (map x -> +X,
## map y -> +Z). Facing +X (east) the right hand points +Z (south); facing +Z (south)
## it points -X (west) — i.e. US drive-on-the-right. Cars and the overlay both offset
## their lane by LANE_OFFSET along this.
static func right_of(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0.0, d.x)

## 4-neighbour offsets in map (x, y): east, west, south (+y), north (-y).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Index of the opposite direction in DIRS.
const OPPOSITE: Array[int] = [1, 0, 3, 2]

## Vector3i(x, y, level) -> { z:int, lid:int, pos:Vector3, edges:PackedFloat32Array,
##   links:Array[Vector3i] }. `edges` holds the surface height at each DIRS edge.
var nodes := {}
## Vector2i cell -> Array[int] of the road levels in that cell, topmost first.
var levels := {}
## Per-cell TOPMOST road level, or -1; indexed [x * DIM + y].
var surface_z := PackedInt32Array()
## Per-cell surface lid tile (the top road tile, else the visible ground) — for the
## in-game inspector when no road level is under the cursor.
var surface_lid := PackedInt32Array()
## Per-cell "can a car be here" flag: any flush ground (road, sidewalk, plaza), but not
## buildings or water. GTA1's kerbs are flush, so a car can spill onto the ground beside
## a narrow road to corner; this is the wider corridor the cars are allowed to use, and
## what tells a knocked-off car it has truly left the drivable surface.
var drivable := PackedByteArray()


static func build(map: GTA1Map) -> RoadGraph:
	var g := RoadGraph.new()
	g.surface_z.resize(DIM * DIM)
	g.surface_lid.resize(DIM * DIM)
	g.drivable.resize(DIM * DIM)

	# Pass 1: every drivable road surface in each column. GTA1's block_type 0 is ALL
	# ground (roads, sidewalks, courtyards, river beds), so type alone can't tell a road
	# from a sidewalk — we classify by the carriageway TILE instead (ROAD_TILES), on any
	# block type. A road block counts unless a BUILDING block sits directly on it (sealed
	# inside a building): GTA1 overpass and walkway decks sit right on the road they
	# cross with no air gap, yet MapBuilder draws such decks as a lid with no walls, so
	# the road below stays drivable — and is kept as its own level, under the deck node.
	# Some bridge-deck cells are FLAT blocks wearing a road tile (often under a railing
	# decal); MapBuilder draws a flat's lid at the cell top and collision comes from that
	# mesh, so they drive like a solid road at the same level and count too.
	for x in DIM:
		for y in DIM:
			var i := x * DIM + y
			g.surface_z[i] = -1
			var vis_lid := 0
			var vis_set := false
			var cell_levels: Array[int] = []
			for z in range(map.get_num_blocks(x, y) - 1, -1, -1):
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				if not vis_set and not b.is_flat():
					vis_lid = b.lid; vis_set = true   # topmost solid = visible surface
				if not ROAD_TILES.has(b.lid):
					continue
				var above := map.get_block(x, y, z + 1)
				if above != null and not above.is_empty() and not above.is_flat() \
						and above.block_type() == BUILDING_TYPE:
					continue   # sealed under a building
				var below := map.get_block(x, y, z - 1) if z > 0 else null
				var edges := _edge_heights(b, below, z)
				var centre := 0.0
				for e in edges:
					centre += e
				g.nodes[Vector3i(x, y, z)] = {
					"z": z,
					"lid": b.lid,
					"pos": Vector3(x + 0.5, centre / 4.0, y + 0.5),
					"edges": edges,
					"links": [] as Array[Vector3i],
				}
				cell_levels.append(z)
			if not cell_levels.is_empty():
				g.levels[Vector2i(x, y)] = cell_levels
				g.surface_z[i] = cell_levels[0]
				g.surface_lid[i] = (g.nodes[Vector3i(x, y, cell_levels[0])] as Dictionary).lid
			else:
				g.surface_lid[i] = vis_lid
			# drivable is the road set for now (the wider-corridor ground mask is rebuilt
			# when the traffic layer needs it; unused while traffic is off).
			g.drivable[i] = 1 if not cell_levels.is_empty() else 0

	# Pass 1b: streets that run on under a deck through a "bedrock" cell. GTA1 leaves
	# some columns under an overpass with nothing at street level, and MapBuilder fills
	# those with a floor at the street surface (_emit_bedrock) so the car drives straight
	# through — but the road map saw a one-row hole in the street there. Add a street
	# node for such a cell when it is covered (something above) and the same street
	# level continues on both opposite sides of it.
	var sz := MapBuilder.STREET_Z
	for x in DIM:
		for y in DIM:
			var c := Vector2i(x, y)
			if map.get_num_blocks(x, y) <= sz + 1:
				continue   # nothing above street level: an open hole, not under a deck
			if not _is_void(map, x, y, 0) or not _is_void(map, x, y, sz):
				continue
			var covered := false
			for z in range(sz + 1, map.get_num_blocks(x, y)):
				covered = covered or not _is_void(map, x, y, z)
			if not covered:
				continue
			var between := (g._has_level(c + DIRS[0], sz) and g._has_level(c + DIRS[1], sz)) \
				or (g._has_level(c + DIRS[2], sz) and g._has_level(c + DIRS[3], sz))
			if not between:
				continue
			var h := sz + 1.0
			g.nodes[Vector3i(x, y, sz)] = {
				"z": sz,
				"lid": MapBuilder.BEDROCK_LID,
				"pos": Vector3(x + 0.5, h, y + 0.5),
				"edges": PackedFloat32Array([h, h, h, h]),
				"links": [] as Array[Vector3i],
			}
			var lv: Array[int] = []
			if g.levels.has(c):
				lv.assign(g.levels[c])
			lv.append(sz)
			lv.sort()
			lv.reverse()   # topmost first
			g.levels[c] = lv
			g.drivable[x * DIM + y] = 1
			if g.surface_z[x * DIM + y] < 0:
				g.surface_z[x * DIM + y] = sz

	# Pass 2: link 4-adjacent surfaces that meet at the same height on their shared edge.
	for key: Vector3i in g.nodes:
		var nd: Dictionary = g.nodes[key]
		var edges: PackedFloat32Array = nd.edges
		var links: Array[Vector3i] = nd.links
		for di in DIRS.size():
			var n := Vector2i(key.x, key.y) + DIRS[di]
			if not g.levels.has(n):
				continue
			for nz: int in g.levels[n]:
				var nk := Vector3i(n.x, n.y, nz)
				var ne: PackedFloat32Array = (g.nodes[nk] as Dictionary).edges
				if absf(edges[di] - ne[OPPOSITE[di]]) <= EDGE_TOL:
					links.append(nk)
	return g


static func _is_void(map: GTA1Map, x: int, y: int, z: int) -> bool:
	var b := map.get_block(x, y, z)
	return b == null or b.is_empty()


func _has_level(cell: Vector2i, z: int) -> bool:
	return levels.has(cell) and (levels[cell] as Array).has(z)


## Surface height (world Y) of a road block at level z along each DIRS edge (E, W, S,
## N). A flat-topped block is level at z + 1; a ramp follows its SlopeData lid. A FLAT
## block sitting on a ramp is drawn following that ramp one unit up (MapBuilder), so it
## takes the ramp's shape at its own level.
static func _edge_heights(b: GTA1Block, below: GTA1Block, z: int) -> PackedFloat32Array:
	var st := b.slope_type()
	if st == 0 and b.is_flat() and below != null and not below.is_empty():
		st = below.slope_type()
	if st == 0:
		return PackedFloat32Array([z + 1.0, z + 1.0, z + 1.0, z + 1.0])
	# Lid corners in cell-local space: x -> +X (east), y up, z -> +Z (south / map +y).
	var lid: PackedVector3Array = SlopeData.faces[st][0]
	var out := PackedFloat32Array()
	for di in DIRS.size():
		var sum := 0.0
		var cnt := 0
		for v in lid:
			var on_edge := false
			match di:
				0: on_edge = v.x > 0.99
				1: on_edge = v.x < 0.01
				2: on_edge = v.z > 0.99
				3: on_edge = v.z < 0.01
			if on_edge:
				sum += v.y; cnt += 1
		if cnt == 0:   # a diagonal ramp's missing edge: fall back to the lid average
			for v in lid:
				sum += v.y
			cnt = lid.size()
		out.append(z + sum / cnt)
	return out


## Is there a road surface at ANY level in this cell?
func is_road(cell: Vector2i) -> bool:
	return levels.has(cell)


## Sentinel for "no node".
const NONE := Vector3i(-1, -1, -1)


## The road node in `cell` whose surface is nearest to world height `y` — i.e. the
## level a car (or the inspector's hit point) at that height is on — or NONE. Heights
## above a surface by up to a level count as on it; the deck wins over the street
## beneath when `y` is at or above the deck.
func node_at(cell: Vector2i, y: float) -> Vector3i:
	if not levels.has(cell):
		return NONE
	var best := NONE
	var best_d := 1e9
	for z: int in levels[cell]:
		var k := Vector3i(cell.x, cell.y, z)
		var d := absf(y - (nodes[k] as Dictionary).pos.y)
		if d < best_d:
			best_d = d
			best = k
	return best


## Map cell (x, y) of a node key.
static func cell_of(key: Vector3i) -> Vector2i:
	return Vector2i(key.x, key.y)


## Surface lid tile at a cell (0 = none) — for the in-game tile inspector.
func lid_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= DIM or cell.y >= DIM:
		return 0
	return surface_lid[cell.x * DIM + cell.y]


## Is this cell flush ground a car may be on (road or the ground beside it)? Used to
## tell a knocked-off car when it has genuinely left the drivable surface.
func is_drivable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= DIM or cell.y >= DIM:
		return false
	return drivable[cell.x * DIM + cell.y] == 1


## A wireframe of the network for top-down inspection: a line per edge, raised just
## above the road. `region` limits the drawn area. (Debug only; not used in game.)
func build_debug_mesh(region := Rect2i(0, 0, DIM, DIM)) -> Node3D:
	var holder := Node3D.new()
	holder.name = "RoadGraphDebug"
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for key: Vector3i in nodes:
		if not region.has_point(cell_of(key)):
			continue
		var a: Vector3 = (nodes[key] as Dictionary).pos + Vector3(0, 0.12, 0)
		for n: Vector3i in (nodes[key] as Dictionary).links:
			if key < n and region.has_point(cell_of(n)):
				var b: Vector3 = (nodes[n] as Dictionary).pos + Vector3(0, 0.12, 0)
				im.surface_add_vertex(a)
				im.surface_add_vertex(b)
	im.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = im
	lines.material_override = _unshaded(Color(0.1, 1.0, 0.9))
	holder.add_child(lines)
	return holder


## True when this node is a junction (3+ ways meet) — where a car must choose.
func is_junction(key: Vector3i) -> bool:
	return nodes.has(key) and ((nodes[key] as Dictionary).links as Array).size() >= 3


## In-world overlay for eyeballing the road map: a yellow arrow on the road for every
## link (so you can see which cells are road, how they connect, and which way you can
## travel), plus a magenta marker at each junction (where a car must choose). Built once
## and toggled in game; bright/unshaded so it reads against the dark asphalt.
func build_arrow_overlay() -> Node3D:
	var holder := Node3D.new()
	holder.name = "RoadMapOverlay"

	# One arrow per DIRECTED link, offset to the right of travel (US drive-on-the-right):
	# a two-way street then shows two opposing arrow lines, one on each side, like lanes.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Arrows tilt with the road: each runs along the 3D line to the linked node, so on
	# a ramp it lies on the slope and an overpass's arrows stay on the deck.
	for key: Vector3i in nodes:
		var nd: Dictionary = nodes[key]
		var c: Vector3 = nd.pos
		for n: Vector3i in (nd.links as Array[Vector3i]):
			var d := Vector3(n.x - key.x, 0.0, n.y - key.y).normalized()
			var np: Vector3 = (nodes[n] as Dictionary).pos
			var d3 := (np - c).normalized()
			var base := c + Vector3(0, 0.15, 0) + right_of(d) * LANE_OFFSET
			var tail := base - d3 * 0.10
			var tip := base + d3 * 0.42
			var barb_l := d.rotated(Vector3.UP, deg_to_rad(150.0)) * 0.15
			var barb_r := d.rotated(Vector3.UP, deg_to_rad(-150.0)) * 0.15
			im.surface_add_vertex(tail); im.surface_add_vertex(tip)
			im.surface_add_vertex(tip); im.surface_add_vertex(tip + barb_l)
			im.surface_add_vertex(tip); im.surface_add_vertex(tip + barb_r)
	im.surface_end()
	var arrows := MeshInstance3D.new()
	arrows.mesh = im
	arrows.material_override = _unshaded(Color(1.0, 0.9, 0.1))
	holder.add_child(arrows)

	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.08, 0.3)
	box.material = _unshaded(Color(1.0, 0.2, 0.7))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	var js: Array[Vector3] = []
	for key: Vector3i in nodes:
		if is_junction(key):
			js.append((nodes[key] as Dictionary).pos + Vector3(0, 0.16, 0))
	mm.instance_count = js.size()
	for i in js.size():
		mm.set_instance_transform(i, Transform3D(Basis(), js[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	holder.add_child(mmi)
	return holder


static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
