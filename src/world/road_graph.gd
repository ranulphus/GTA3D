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


static func build(map: GTA1Map) -> RoadGraph:
	var g := RoadGraph.new()

	# Pass 1: road mask + surface height per cell.
	g.surface_z.resize(DIM * DIM)
	for x in DIM:
		for y in DIM:
			g.surface_z[x * DIM + y] = _road_surface_z(map, x, y)

	# Pass 2: a node per road cell, linked to road neighbours within one step.
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


func is_road(cell: Vector2i) -> bool:
	return nodes.has(cell)


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
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 1.0, 0.9)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lines.material_override = m
	holder.add_child(lines)
	return holder
