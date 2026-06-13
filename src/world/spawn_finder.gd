class_name SpawnFinder
extends RefCounted

## Finds a sensible place to drop a car: a flat, ground-level stretch of road
## running along +Z (the car's forward axis), wide enough for the car and clear
## ahead. Uses the real drivable surface height (get_surface_y) — GTA1 columns
## are mostly air with content at scattered levels, so the surface is the highest
## SOLID block, not the raw block count.

const ROAD_DIR := Vector2i(0, 1)
const MIN_RUN := 6
const MAX_GROUND_Y := 3   # skip building roofs; keep spawns at street level


static func find_drive_spawn(map: GTA1Map) -> Vector2i:
	var c := GTA1Map.DIM / 2
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
				var run := 0
				for s in range(1, 13):
					if _flat_road(map, x + ROAD_DIR.x * s, y + ROAD_DIR.y * s, h):
						run += 1
					else:
						break
				if run >= MIN_RUN and _fits(map, x, y, h):
					return Vector2i(x, y)
	return Vector2i(c, c)


## A ground-level cell whose surface block actually has a lid to drive on.
static func drivable(map: GTA1Map, x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= GTA1Map.DIM - 1 or y >= GTA1Map.DIM - 1:
		return false
	var h := map.get_surface_y(x, y)
	if h < 1 or h > MAX_GROUND_Y:
		return false
	return _surface_has_lid(map, x, y)


## True if the highest solid (non-flat) block has a lid (a real road/ground top).
static func _surface_has_lid(map: GTA1Map, x: int, y: int) -> bool:
	var n := map.get_num_blocks(x, y)
	for z in range(n - 1, -1, -1):
		var b := map.get_block(x, y, z)
		if b != null and not b.is_empty() and not b.is_flat():
			return b.lid > 0
	return false


static func _flat_road(map: GTA1Map, x: int, y: int, h: int) -> bool:
	return drivable(map, x, y) and map.get_surface_y(x, y) == h


## The cell and both immediate sides share the same surface height, so the
## ~1.5-wide car sits on a level road rather than straddling a step.
static func _fits(map: GTA1Map, x: int, y: int, h: int) -> bool:
	var perp := Vector2i(ROAD_DIR.y, ROAD_DIR.x)
	return _flat_road(map, x + perp.x, y + perp.y, h) and _flat_road(map, x - perp.x, y - perp.y, h)
