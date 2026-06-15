extends SceneTree

## Probe how water (river/sea) vs sunken interiors (subway) look in the data, so we
## can build a water surface that fills the rivers without flooding the subways.
## For a region prints each cell's column: which z-levels hold blocks, their type,
## whether the low surface is OPEN to the sky (water-like) or COVERED (subway-like).
##   godot --headless --path . --script res://tests/diag_water.gd -- NYC 76 84 116 124

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var city := a[0] if a.size() > 0 else "NYC"
	var x0 := (a[1] as String).to_int() if a.size() > 1 else 76
	var x1 := (a[2] as String).to_int() if a.size() > 2 else 84
	var y0 := (a[3] as String).to_int() if a.size() > 3 else 116
	var y1 := (a[4] as String).to_int() if a.size() > 4 else 124
	var map := GTA1Map.load_file("res://data/%s.CMP" % city)

	# Map-wide stats: how do block_type and lid tiles distribute at low surfaces?
	var btype_count := {}
	var lowopen := 0       # surface z<=1, nothing above -> water-like
	var lowcovered := 0    # has a low block (z=0) AND blocks higher up -> subway-like
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			var n := map.get_num_blocks(x, y)
			if n == 0:
				continue
			var sy := map.get_surface_y(x, y)
			var b0 := map.get_block(x, y, 0)
			var has_low := b0 != null and not b0.is_empty()
			var has_high := false
			for z in range(2, n):
				var bz := map.get_block(x, y, z)
				if bz != null and not bz.is_empty():
					has_high = true
			if has_low and has_high:
				lowcovered += 1
			elif sy <= 1:
				lowopen += 1
			var sb := map.get_block(x, y, maxi(sy - 1, 0))
			if sb != null and not sb.is_empty():
				var bt := sb.block_type()
				btype_count[bt] = btype_count.get(bt, 0) + 1
	print("block_type counts at surface: ", btype_count)
	print("low+open (water-like): ", lowopen, "   low+covered (subway-like): ", lowcovered)

	# Lid histograms: what tile sits on the surface of low+open cells (water) vs
	# low+covered cells (subway floors) — to pick a water predicate that separates them.
	var open_lids := {}
	var cov_lids := {}
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			var n := map.get_num_blocks(x, y)
			if n == 0:
				continue
			var sy := map.get_surface_y(x, y)
			var b0 := map.get_block(x, y, 0)
			var has_low := b0 != null and not b0.is_empty()
			var has_high := false
			for z in range(2, n):
				var bz := map.get_block(x, y, z)
				if bz != null and not bz.is_empty():
					has_high = true
			var sb := map.get_block(x, y, maxi(sy - 1, 0))
			var lid := sb.lid if sb != null else -1
			if has_low and has_high:
				cov_lids[lid] = cov_lids.get(lid, 0) + 1
			elif sy <= 1:
				open_lids[lid] = open_lids.get(lid, 0) + 1
	print("top low+open surface lids:   ", _top(open_lids))
	print("top low+covered surface lids: ", _top(cov_lids))

	# Sample cells that dip to z=0 but are NOT water (subway/interior floors): these
	# must stay dry. water_tile from WaterBuilder; print a few so we can render one.
	var wt := WaterBuilder.detect_water_tile(map)
	print("water tile = ", wt, " — sample dry-but-low (subway-like) cells:")
	var shown := 0
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			if shown >= 12:
				break
			var n := map.get_num_blocks(x, y)
			if n < 3:
				continue
			var b0 := map.get_block(x, y, 0)
			if b0 == null or b0.is_empty() or b0.lid == wt:
				continue   # empty or water -> not a dry subway floor
			var high := false
			for z in range(2, n):
				var bz := map.get_block(x, y, z)
				if bz != null and not bz.is_empty():
					high = true
			if high and b0.lid > 0:
				print("  subwayish (%d,%d): z0 lid=%d  watered=%s" % [x, y, b0.lid, WaterBuilder.is_water(map, x, y, wt)])
				shown += 1

	print("\n=== column dump (%d,%d)-(%d,%d) ===" % [x0, y0, x1, y1])
	for x in range(x0, x1 + 1):
		var row := ""
		for y in range(y0, y1 + 1):
			var n := map.get_num_blocks(x, y)
			var parts := PackedStringArray()
			for z in n:
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				parts.append("z%d[t%d,lid%d%s]" % [z, b.block_type(), b.lid, "F" if b.is_flat() else ""])
			row = "(%3d,%3d) n=%d sy=%d  %s" % [x, y, n, map.get_surface_y(x, y), " ".join(parts)]
			print(row)
	quit(0)


func _top(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return d[a] > d[b])
	var out := PackedStringArray()
	for i in mini(6, keys.size()):
		out.append("lid%d=%d" % [keys[i], d[keys[i]]])
	return ", ".join(out)
