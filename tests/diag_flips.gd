extends SceneTree

## Inspect GTA1 per-block flip / rotation flags: how common they are on wall vs
## lid vs flat blocks, and a dump of the flagged blocks near a given cell so we
## can correlate the scrambled banners with the flags that aren't being applied.
##
##   godot --headless --path . --script res://tests/diag_flips.gd -- NYC 142 23

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var city := a[0] if a.size() > 0 else "NYC"
	var cx := (a[1] as String).to_int() if a.size() > 1 else 142
	var cy := (a[2] as String).to_int() if a.size() > 2 else 23
	var map := GTA1Map.load_file("res://data/%s.CMP" % city)

	var stats := {"wall_flip_lr": 0, "wall_flip_tb": 0, "wall_rot": 0,
		"lid_flip_lr": 0, "lid_flip_tb": 0, "lid_rot": 0, "walls": 0, "lids": 0}
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			for z in map.get_num_blocks(x, y):
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				var has_wall := b.left > 0 or b.right > 0 or b.top > 0 or b.bottom > 0
				if has_wall:
					stats.walls += 1
					if b.flip_left_right(): stats.wall_flip_lr += 1
					if b.flip_top_bottom(): stats.wall_flip_tb += 1
					if b.rotation() != 0: stats.wall_rot += 1
				if b.lid > 0:
					stats.lids += 1
					if b.flip_left_right(): stats.lid_flip_lr += 1
					if b.flip_top_bottom(): stats.lid_flip_tb += 1
					if b.rotation() != 0: stats.lid_rot += 1
	print("=== flag usage across %s ===" % city)
	print(stats)

	print("\n=== flagged blocks near (%d,%d) ===" % [cx, cy])
	for x in range(cx - 6, cx + 7):
		for y in range(cy - 6, cy + 7):
			if x < 0 or y < 0 or x >= GTA1Map.DIM or y >= GTA1Map.DIM:
				continue
			for z in map.get_num_blocks(x, y):
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				if b.flip_left_right() or b.flip_top_bottom() or b.rotation() != 0:
					print("(%3d,%3d,%d) flat=%s slope=%d rot=%d flipLR=%s flipTB=%s  L=%d R=%d T=%d B=%d lid=%d"
						% [x, y, z, b.is_flat(), b.slope_type(), b.rotation(),
							b.flip_left_right(), b.flip_top_bottom(),
							b.left, b.right, b.top, b.bottom, b.lid])
	quit(0)
