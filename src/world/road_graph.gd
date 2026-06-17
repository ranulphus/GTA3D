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

const ROAD_TYPE := 0          # block_type for road/ground
const MAX_STEP := 1           # stack levels two road cells may differ and still link
const DIM := GTA1Map.DIM

## 4-neighbour offsets in map (x, y).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## cell (Vector2i) -> { z:int, pos:Vector3, links:Array[Vector2i] }
var nodes := {}
## Per-cell road surface stack level, or -1; indexed [x * DIM + y].
var surface_z := PackedInt32Array()
## Per-cell "can a car be here" flag: any flush ground (road, sidewalk, plaza), but not
## buildings or water. GTA1's kerbs are flush, so a car can spill onto the ground beside
## a narrow road to corner; this is the wider corridor the cars are allowed to use, and
## what tells a knocked-off car it has truly left the drivable surface.
var drivable := PackedByteArray()


static func build(map: GTA1Map) -> RoadGraph:
	var g := RoadGraph.new()
	var water := WaterBuilder.detect_water_tile(map)

	# Pass 1: per-cell surface (topmost solid, non-flat block) — its type, lid tile,
	# height, and whether a flat decal sits above it. GTA1's block_type 0 is ALL ground
	# (roads, sidewalks, courtyards, river beds), so type alone can't tell a street from
	# a plaza or the harbour. The giveaway is the surface TILE: the carriageway uses a
	# small set of asphalt tiles, and lane-marking decals (flat blocks) ride on them.
	var s_type := PackedInt32Array(); s_type.resize(DIM * DIM)
	var s_lid := PackedInt32Array(); s_lid.resize(DIM * DIM)
	var s_z := PackedInt32Array(); s_z.resize(DIM * DIM)
	var s_decal := PackedByteArray(); s_decal.resize(DIM * DIM)
	for x in DIM:
		for y in DIM:
			var i := x * DIM + y
			s_type[i] = -1; s_lid[i] = 0; s_z[i] = -1; s_decal[i] = 0
			var n := map.get_num_blocks(x, y)
			var sz := -1
			for z in range(n - 1, -1, -1):
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty() or b.is_flat():
					continue
				sz = z; s_type[i] = b.block_type(); s_lid[i] = b.lid
				break
			if sz < 0:
				continue
			s_z[i] = sz
			for z in range(sz + 1, n):   # a flat (decal) block above the surface?
				var b := map.get_block(x, y, z)
				if b != null and not b.is_empty() and b.is_flat():
					s_decal[i] = 1
					break

	# Derive the carriageway tile set: among road-type surfaces wearing a decal, the
	# lids that ride under markings, biggest first, stopping at the first sharp drop.
	var counts := {}
	for i in DIM * DIM:
		if s_type[i] == ROAD_TYPE and s_decal[i] == 1 and s_lid[i] != water and s_lid[i] > 0:
			counts[s_lid[i]] = counts.get(s_lid[i], 0) + 1
	var asphalt := _derive_asphalt(counts)

	# Pass 2: a node per carriageway cell, linked to neighbours within one height step.
	# Also flag every flush ground cell (road/sidewalk/plaza, not building or water) as
	# drivable — the wider corridor cars may spill into when cornering.
	g.surface_z.resize(DIM * DIM)
	g.drivable.resize(DIM * DIM)
	for i in DIM * DIM:
		g.surface_z[i] = s_z[i] if (s_type[i] == ROAD_TYPE and asphalt.has(s_lid[i])) else -1
		g.drivable[i] = 1 if ((s_type[i] == 0 or s_type[i] == 4) and s_lid[i] != water and s_z[i] >= 0) else 0
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


## Pick the carriageway tiles from a lid->count histogram (counts of road-type cells
## wearing a marking decal): take the most common, then keep adding while each next is
## at least half the previous, and stop at the first sharp drop. That isolates the one
## or two asphalt tiles from the long tail of incidental decalled surfaces.
static func _derive_asphalt(counts: Dictionary) -> Dictionary:
	var lids: Array = counts.keys()
	lids.sort_custom(func(a, b): return counts[a] > counts[b])
	var set := {}
	var prev := 0
	for lid in lids:
		var c: int = counts[lid]
		if set.is_empty():
			set[lid] = true; prev = c
		elif c >= prev / 2 and set.size() < 4:
			set[lid] = true; prev = c
		else:
			break
	return set


func is_road(cell: Vector2i) -> bool:
	return nodes.has(cell)


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

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for cell: Vector2i in nodes:
		var nd: Dictionary = nodes[cell]
		var c: Vector3 = nd.pos + Vector3(0, 0.15, 0)
		for n: Vector2i in (nd.links as Array[Vector2i]):
			var d := Vector3(n.x - cell.x, 0.0, n.y - cell.y).normalized()
			var tail := c - d * 0.12
			var tip := c + d * 0.40
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
