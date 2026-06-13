extends SceneTree

## Text-only diagnostics about the GTA1 map: flat-block prevalence, block_type
## distribution at the surface, how many surface cells carry side-wall textures,
## rotation distribution, and a small text grid of a road region so road layout
## can be inspected without rendering. Fast (no GPU).
##
##   godot --headless --path . --script res://tests/diag_map.gd -- NYC

func _init() -> void:
	var city := "NYC"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		city = extra[0]

	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	if map == null:
		push_error("no map"); quit(1); return

	var DIM := GTA1Map.DIM
	var flat_total := 0
	var nonempty_total := 0
	var surf_type := {}
	var surf_rot := {}
	var surf_has_walls := 0
	var surf_lid_only := 0

	for x in DIM:
		for y in DIM:
			var n := map.get_num_blocks(x, y)
			for z in n:
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				nonempty_total += 1
				if b.is_flat():
					flat_total += 1
			var sy := map.get_surface_y(x, y)
			if sy <= 0:
				continue
			var sb := map.get_block(x, y, sy - 1)
			if sb == null:
				continue
			var bt := sb.block_type()
			surf_type[bt] = surf_type.get(bt, 0) + 1
			var rot := sb.rotation()
			surf_rot[rot] = surf_rot.get(rot, 0) + 1
			var has_walls: bool = sb.left > 0 or sb.right > 0 or sb.top > 0 or sb.bottom > 0
			if has_walls:
				surf_has_walls += 1
			elif sb.lid > 0:
				surf_lid_only += 1

	print("=== %s ===" % city)
	print("nonempty blocks=%d  flat blocks=%d (%.1f%%)" % [nonempty_total, flat_total, 100.0 * flat_total / maxi(1, nonempty_total)])
	print("surface block_type histogram: ", surf_type)
	print("surface rotation histogram:   ", surf_rot)
	print("surface cells with side walls=%d  lid-only(road/ground)=%d" % [surf_has_walls, surf_lid_only])

	# Dump a 24x24 text grid around the spawn so we can read the road layout.
	var sp := SpawnFinder.find_drive_spawn(map)
	print("spawn=", sp, "  surface_y=", map.get_surface_y(sp.x, sp.y))
	print("--- region around spawn (T=block_type, r=rotation, h=surface_y, *=has walls, f=flat-surf) ---")
	var x0: int = clampi(sp.x - 12, 0, DIM - 24)
	var y0: int = clampi(sp.y - 12, 0, DIM - 24)
	for y in range(y0, y0 + 24):
		var line := ""
		for x in range(x0, x0 + 24):
			var sy := map.get_surface_y(x, y)
			if sy <= 0:
				line += " .. "
				continue
			var sb := map.get_block(x, y, sy - 1)
			var bt := sb.block_type()
			var mark := "*" if (sb.left > 0 or sb.right > 0 or sb.top > 0 or sb.bottom > 0) else ("f" if sb.is_flat() else " ")
			line += "%d%d%s " % [bt, sb.rotation(), mark]
		print(line)
	quit(0)
