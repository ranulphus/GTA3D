class_name RoadGraph
extends RefCounted

## A drivable road network derived from the city's road tiles — the way GTA1's
## engine generated ambient traffic at runtime. The .CMP map stores no lane network
## (its tiny `routes` block is only train/scripted paths, and the per-tile movement
## bits are unused on roads), so we rebuild it from the road surface.
##
## Every cell whose surface is a road tile becomes a node; 4-adjacent road cells join
## with an edge when their surfaces are within one step (so ramps connect, walls and
## roofs don't). This is the FULL road grid — deliberately not thinned to a centre
## line: a thinned skeleton fragments at junctions into dead-end stubs that trap cars
## in tiny loops. The full grid is connected by construction, and traffic stays on
## real streets by preferring to drive straight (see TrafficCar), turning only at
## genuine junctions/ends.
##
## World mapping matches MapBuilder: map x -> world X, map y -> world Z, and the
## surface block's stack level z puts the drivable top at world Y = z + 1.

const BUILDING_TYPE := 5      # block_type for buildings — a road sealed under one isn't drivable
const MAX_STEP := 1           # stack levels two road cells may differ and still link
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

## 4-neighbour offsets in map (x, y).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## cell (Vector2i) -> { z:int, pos:Vector3, links:Array[Vector2i] }
var nodes := {}
## Per-cell road surface stack level, or -1; indexed [x * DIM + y].
var surface_z := PackedInt32Array()
## Per-cell surface lid tile (any ground, not just road) — for the in-game inspector.
var surface_lid := PackedInt32Array()
## Per-cell "can a car be here" flag: any flush ground (road, sidewalk, plaza), but not
## buildings or water. GTA1's kerbs are flush, so a car can spill onto the ground beside
## a narrow road to corner; this is the wider corridor the cars are allowed to use, and
## what tells a knocked-off car it has truly left the drivable surface.
var drivable := PackedByteArray()


static func build(map: GTA1Map) -> RoadGraph:
	var g := RoadGraph.new()

	# Pass 1: per-cell surface (topmost solid, non-flat block) — its type, lid tile, and
	# height. GTA1's block_type 0 is ALL ground (roads, sidewalks, courtyards, river
	# beds), so type alone can't tell a road from a sidewalk. The giveaway is shape: the
	# CARRIAGEWAY is wide (several cells), while sidewalks are 1-cell strips along the
	# buildings. So we classify by surface TILE, picking the tiles that mostly appear in
	# wide blocks — see _derive_road_tiles. (Picking the common decalled tile instead
	# wrongly chose the sidewalk, since markings are sparse but pavement is everywhere.)
	# s_z = the level of the topmost DRIVABLE road block (a road tile with open space
	# above it, so a car can reach it). Scanning past non-road decks this way finds the
	# road UNDER a pedestrian walkway/overpass — whose deck (e.g. pavement) isn't road —
	# while a road sealed under a solid building (no gap above) is correctly ignored.
	# s_lid is that road tile when road, else the visible surface (for the inspector).
	var s_lid := PackedInt32Array(); s_lid.resize(DIM * DIM)
	var s_z := PackedInt32Array(); s_z.resize(DIM * DIM)
	for x in DIM:
		for y in DIM:
			var i := x * DIM + y
			s_lid[i] = 0; s_z[i] = -1
			var n := map.get_num_blocks(x, y)
			var vis_lid := 0
			var vis_set := false
			for z in range(n - 1, -1, -1):
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty() or b.is_flat():
					continue
				if not vis_set:
					vis_lid = b.lid; vis_set = true   # topmost solid = visible surface
				if ROAD_TILES.has(b.lid):
					# Drivable unless a BUILDING block sits directly on it (sealed under a
					# building). GTA1 walkway/overpass decks (block_type 2) sit right on the
					# road they cross with no air gap, so a gap test would wrongly reject the
					# road beneath them — only a building cap means truly not drivable.
					var above := map.get_block(x, y, z + 1)
					var capped := above != null and not above.is_empty() \
						and not above.is_flat() and above.block_type() == BUILDING_TYPE
					if not capped:
						s_z[i] = z; s_lid[i] = b.lid
						break
			if s_z[i] < 0:
				s_lid[i] = vis_lid


	# Pass 2: a node per carriageway cell, linked to neighbours within one height step.
	# Also flag every flush ground cell (road/sidewalk/plaza, not building or water) as
	# drivable — the wider corridor cars may spill into when cornering.
	# s_z already holds the drivable-road level per cell (-1 = not road), classified by
	# tile across any block_type. drivable is the road set for now (the wider-corridor
	# ground mask is rebuilt when the traffic layer needs it; unused while traffic is off).
	g.surface_z = s_z
	g.surface_lid = s_lid
	g.drivable.resize(DIM * DIM)
	for i in DIM * DIM:
		g.drivable[i] = 1 if s_z[i] >= 0 else 0
	for x in DIM:
		for y in DIM:
			var z := g.surface_z[x * DIM + y]
			if z < 0:
				continue
			var links: Array[Vector2i] = []
			for d in DIRS:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= DIM or ny >= DIM:
					continue
				var nz := g.surface_z[nx * DIM + ny]
				if nz >= 0 and absi(nz - z) <= MAX_STEP:
					links.append(Vector2i(nx, ny))
			g.nodes[Vector2i(x, y)] = {
				"z": z,
				"pos": Vector3(x + 0.5, z + 1, y + 0.5),
				"links": links,
			}
	return g


func is_road(cell: Vector2i) -> bool:
	return nodes.has(cell)


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
	for cell: Vector2i in nodes:
		if not region.has_point(cell):
			continue
		var a: Vector3 = (nodes[cell] as Dictionary).pos + Vector3(0, 0.12, 0)
		for n: Vector2i in (nodes[cell] as Dictionary).links:
			if cell < n and region.has_point(n):
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
func is_junction(cell: Vector2i) -> bool:
	return nodes.has(cell) and ((nodes[cell] as Dictionary).links as Array).size() >= 3


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
	for cell: Vector2i in nodes:
		var nd: Dictionary = nodes[cell]
		var c: Vector3 = nd.pos
		for n: Vector2i in (nd.links as Array[Vector2i]):
			var d := Vector3(n.x - cell.x, 0.0, n.y - cell.y).normalized()
			var base := c + Vector3(0, 0.15, 0) + right_of(d) * LANE_OFFSET
			var tail := base - d * 0.10
			var tip := base + d * 0.42
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
	for cell: Vector2i in nodes:
		if is_junction(cell):
			js.append((nodes[cell] as Dictionary).pos + Vector3(0, 0.16, 0))
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
