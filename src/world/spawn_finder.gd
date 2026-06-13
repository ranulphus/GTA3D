class_name SpawnFinder
extends RefCounted

## Finds a good place to drop the car: an OPEN, flat, ground-level patch that is
## road-shaped — long in one direction and narrow across — so the car lands on an
## actual street facing down it, not wedged against a wall and not stranded in the
## middle of a wide grass park (which is open but fenced-in, so you can't drive
## out). Uses the real drivable surface height (get_surface_y): GTA1 columns are
## mostly air with content at scattered levels, so the surface is the highest
## SOLID block, not the raw block count.

const MIN_RUN := 6          # shortest run that still counts as "a street ahead"
const ROAD_MIN_LEN := 10    # a real street stretches at least this far...
const ROAD_MAX_WIDTH := 6   # ...and is no wider than this across (parks are wider)
const MAX_GROUND_Y := 3     # skip building roofs; keep spawns at street level


## Position + forward direction (unit grid step) for the car. Direction points
## down the road's long axis so the car spawns aimed along the street.
static func find_drive_spawn_full(map: GTA1Map) -> Dictionary:
	var c := GTA1Map.DIM / 2
	var fallback := {}
	for radius in range(0, 120):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var x := c + dx
				var y := c + dy
				if not drivable(map, x, y):
					continue
				var h := map.get_surface_y(x, y)
				if not _open_3x3(map, x, y, h):
					continue
				var run_z := _run(map, x, y, h, 0, 1) + _run(map, x, y, h, 0, -1) + 1
				var run_x := _run(map, x, y, h, 1, 0) + _run(map, x, y, h, -1, 0) + 1
				var length := maxi(run_z, run_x)
				var width := mini(run_z, run_x)
				var dir := Vector2i(0, 1) if run_z >= run_x else Vector2i(1, 0)
				if fallback.is_empty() and length >= MIN_RUN:
					fallback = {"pos": Vector2i(x, y), "dir": dir}
				if length >= ROAD_MIN_LEN and width <= ROAD_MAX_WIDTH:
					return {"pos": Vector2i(x, y), "dir": dir}
	if not fallback.is_empty():
		return fallback
	return {"pos": Vector2i(c, c), "dir": Vector2i(0, 1)}


## Back-compat: just the grid position.
static func find_drive_spawn(map: GTA1Map) -> Vector2i:
	return find_drive_spawn_full(map)["pos"]


## A street-level cell whose surface is a real, wall-less road/ground top (a lid
## with no side textures) — i.e. something the car can sit and drive on.
static func drivable(map: GTA1Map, x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= GTA1Map.DIM - 1 or y >= GTA1Map.DIM - 1:
		return false
	var h := map.get_surface_y(x, y)
	if h < 1 or h > MAX_GROUND_Y:
		return false
	var sb := map.get_block(x, y, h - 1)
	if sb == null or sb.lid <= 0:
		return false
	# Side textures mean a wall/fence/building face here — not open ground.
	return sb.left == 0 and sb.right == 0 and sb.top == 0 and sb.bottom == 0


## Every one of the 8 surrounding cells is drivable ground at the same height, so
## the car drops onto open road rather than wedged against a kerb, wall or fence.
static func _open_3x3(map: GTA1Map, x: int, y: int, h: int) -> bool:
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			if not drivable(map, x + ox, y + oy):
				return false
			if map.get_surface_y(x + ox, y + oy) != h:
				return false
	return true


## Count consecutive drivable, same-height cells stepping (dx,dy) from (x,y),
## excluding the start cell. Capped so wide-open areas don't run forever.
static func _run(map: GTA1Map, x: int, y: int, h: int, dx: int, dy: int) -> int:
	var run := 0
	for s in range(1, 40):
		var nx := x + dx * s
		var ny := y + dy * s
		if drivable(map, nx, ny) and map.get_surface_y(nx, ny) == h:
			run += 1
		else:
			break
	return run
