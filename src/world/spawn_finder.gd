class_name SpawnFinder
extends RefCounted

## Finds a sensible place to drop a car: a flat, drivable stretch of road that
## runs along +Z (the car's forward axis), wide enough for the car and clear
## ahead. "Drivable" = the cell's top block has a lid to drive on; "flat" = the
## run keeps the same surface height so the car isn't blocked by a step/wall.
##
## (GTA1 columns include sub-surface fill, so a road is typically 2-3 blocks
## tall, not 1 — we match on the TOP surface, not the raw block count.)

const ROAD_DIR := Vector2i(0, 1)
const MIN_RUN := 6


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
				var h := map.get_num_blocks(x, y)
				var run := 0
				for s in range(1, 13):
					if _drivable_at(map, x + ROAD_DIR.x * s, y + ROAD_DIR.y * s, h):
						run += 1
					else:
						break
				if run >= MIN_RUN and _fits(map, x, y, h, ROAD_DIR):
					return Vector2i(x, y)
	return Vector2i(c, c)


## True when the cell has a top surface (lid) the car can rest/drive on.
static func drivable(map: GTA1Map, x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= GTA1Map.DIM - 1 or y >= GTA1Map.DIM - 1:
		return false
	var n := map.get_num_blocks(x, y)
	if n < 1:
		return false
	var b := map.get_block(x, y, n - 1)   # top block
	return b != null and b.lid > 0


static func _drivable_at(map: GTA1Map, x: int, y: int, h: int) -> bool:
	return drivable(map, x, y) and map.get_num_blocks(x, y) == h


## The cell and both immediate sides are drivable at the same height, so the
## ~1.5-wide car sits on a level road rather than straddling a step.
static func _fits(map: GTA1Map, x: int, y: int, h: int, dir: Vector2i) -> bool:
	var perp := Vector2i(dir.y, dir.x)
	return _drivable_at(map, x + perp.x, y + perp.y, h) and _drivable_at(map, x - perp.x, y - perp.y, h)
