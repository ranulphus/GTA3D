extends SceneTree
## Scan the whole map for genuine multi-level columns: a solid (non-flat, non-empty)
## block, then a gap of air, then another solid block above. Those are the only
## cells where a car could drive UNDER an upper deck. Reports counts and a sample.
##   godot --headless --path . --script res://tests/diag_overpass.gd
func _init() -> void:
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var gaps := 0
	var samples: Array = []
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			var n := map.get_num_blocks(x, y)
			# Build a solid-occupancy profile up the column.
			var solid := []
			for z in n:
				var b := map.get_block(x, y, z)
				solid.append(b != null and not b.is_empty() and not b.is_flat())
			# Look for solid ... air(>=1) ... solid (a real overhead deck).
			var found := false
			var seen_solid := false
			var seen_gap := false
			for z in n:
				if solid[z]:
					if seen_solid and seen_gap:
						found = true
						break
					seen_solid = true
				elif seen_solid:
					seen_gap = true
			if found:
				gaps += 1
				if samples.size() < 14:
					samples.append(Vector2i(x, y))
	print("multi-level (drive-under) columns: ", gaps)
	for s in samples:
		var line := "(%d,%d): " % [s.x, s.y]
		var n := map.get_num_blocks(s.x, s.y)
		for z in n:
			var b := map.get_block(s.x, s.y, z)
			var t := "."
			if b == null or b.is_empty(): t = "."
			elif b.is_flat(): t = "f"
			elif b.slope_type() != 0: t = "s"
			else: t = "#"
			line += t
		print(line)
	quit(0)
