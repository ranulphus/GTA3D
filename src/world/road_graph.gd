class_name RoadGraph
extends RefCounted

## A drivable road network derived from the city's road tiles — the way GTA1's
## engine generated ambient traffic at runtime. The .CMP map stores no lane network
## (its tiny `routes` block is only train/scripted paths, and the per-tile movement
## bits are unused on roads), so we rebuild it from the road surface.
##
## GTA1 roads are several cells wide, so a raw cell grid is a thick blob where every
## interior cell looks like a junction. Instead we take the road area's MEDIAL AXIS:
## a distance transform (how deep each road cell is inside the road) whose ridge runs
## down the centre of every street. Centre cells become graph nodes; 4-adjacent centre
## cells join with an edge. The result is a one-cell-wide street network with real
## junctions (nodes where 3+ streets meet).
##
## World mapping matches MapBuilder: map x -> world X, map y -> world Z, and the
## surface block's stack level z puts the drivable top at world Y = z + 1.
##
## Cars follow this network, taking a non-reversing turn at each junction; a lane
## offset to the right of each edge keeps oncoming traffic apart (right-hand drive).

const ROAD_TYPE := 0          # block_type for road/ground
const MAX_STEP := 1           # stack levels two centre cells may differ and still link
const DIM := GTA1Map.DIM

## 4-neighbour offsets in map (x, y).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## cell (Vector2i) -> { z:int, pos:Vector3, links:Array[Vector2i] }
var nodes := {}
## Per-cell road surface stack level, or -1; indexed [x * DIM + y]. Lets the car ask
## "is this cell drivable, and at what height" without re-scanning the column.
var surface_z := PackedInt32Array()


static func build(map: GTA1Map) -> RoadGraph:
	var g := RoadGraph.new()

	# Pass 1: road mask + surface height per cell.
	g.surface_z.resize(DIM * DIM)
	for x in DIM:
		for y in DIM:
			g.surface_z[x * DIM + y] = _road_surface_z(map, x, y)

	# Pass 2: Chebyshev distance transform — distance from each road cell to the
	# nearest non-road cell. The road's centre is where this is locally largest.
	var dist := PackedInt32Array()
	dist.resize(DIM * DIM)
	var BIG := 1 << 20
	for i in DIM * DIM:
		dist[i] = BIG if g.surface_z[i] >= 0 else 0
	# Forward pass (top-left to bottom-right), then backward.
	for x in range(1, DIM):
		for y in range(1, DIM):
			var i := x * DIM + y
			if dist[i] == 0: continue
			dist[i] = mini(dist[i], 1 + mini(mini(dist[i - DIM], dist[i - 1]),
				mini(dist[i - DIM - 1], dist[(x + 1) * DIM + (y - 1)] if x + 1 < DIM else BIG)))
	for x in range(DIM - 2, -1, -1):
		for y in range(DIM - 2, -1, -1):
			var i := x * DIM + y
			if dist[i] == 0: continue
			dist[i] = mini(dist[i], 1 + mini(mini(dist[i + DIM], dist[i + 1]),
				mini(dist[i + DIM + 1], dist[(x - 1) * DIM + (y + 1)] if x - 1 >= 0 else BIG)))

	# Pass 3: keep cells on the medial ridge — a local maximum of `dist` along the
	# road's short axis. A horizontal street ridges along its column (y); a vertical
	# street along its row (x); a junction satisfies both. `>=` keeps the spine
	# unbroken across even-width roads (it can be two cells wide, thinned by linking).
	for x in range(1, DIM - 1):
		for y in range(1, DIM - 1):
			var i := x * DIM + y
			if dist[i] <= 0:
				continue
			# Centre of the road = a local maximum of `dist` over all 4 neighbours.
			# Along a straight corridor the distance is flat in the road direction and
			# falls off to the kerbs, so only the middle row/column survives this test.
			var is_ridge: bool = dist[i] >= dist[i - DIM] and dist[i] >= dist[i + DIM] \
				and dist[i] >= dist[i - 1] and dist[i] >= dist[i + 1]
			if is_ridge:
				var z := g.surface_z[i]
				g.nodes[Vector2i(x, y)] = {
					"z": z,
					"pos": Vector3(x + 0.5, z + 1, y + 0.5),
					"links": [] as Array[Vector2i],
				}

	# Pass 4: link adjacent centre cells within one height step.
	for cell: Vector2i in g.nodes:
		var nd: Dictionary = g.nodes[cell]
		for d in DIRS:
			var n: Vector2i = cell + d
			if g.nodes.has(n) and absi((g.nodes[n] as Dictionary).z - nd.z) <= MAX_STEP:
				(nd.links as Array[Vector2i]).append(n)
	return g


## Stack level of the topmost solid, non-flat ROAD block at (x, y), or -1 when the
## surface there is something a car can't be on (roof, field, water, bridge deck).
static func _road_surface_z(map: GTA1Map, x: int, y: int) -> int:
	var n := map.get_num_blocks(x, y)
	for z in range(n - 1, -1, -1):
		var b := map.get_block(x, y, z)
		if b == null or b.is_empty() or b.is_flat():
			continue
		return z if b.block_type() == ROAD_TYPE else -1
	return -1


## True when this node is a junction (3+ ways meet) — where a car must choose.
func is_junction(cell: Vector2i) -> bool:
	return nodes.has(cell) and ((nodes[cell] as Dictionary).links as Array).size() >= 3


## A bright wireframe of the network for top-down inspection: a line per edge, raised
## just above the road, with junction nodes dotted in a second colour. `region` limits
## the drawn area so a close render isn't swamped by the whole city.
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
			if cell < n and region.has_point(n):   # each undirected edge once
				var b: Vector3 = (nodes[n] as Dictionary).pos + Vector3(0, 0.12, 0)
				im.surface_add_vertex(a)
				im.surface_add_vertex(b)
	im.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = im
	lines.material_override = _unshaded(Color(0.1, 1.0, 0.9))
	holder.add_child(lines)

	# Junction dots as small boxes.
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	box.material = _unshaded(Color(1.0, 0.2, 0.6))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	var js: Array[Vector3] = []
	for cell: Vector2i in nodes:
		if region.has_point(cell) and is_junction(cell):
			js.append((nodes[cell] as Dictionary).pos + Vector3(0, 0.2, 0))
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
