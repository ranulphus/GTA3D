extends SceneTree

## Dump every non-empty block in a cell range with its faces + flags, to see
## exactly what a banner/sign is made of. Args: city x0 x1 y0 y1
##   godot --headless --path . --script res://tests/dump_cells.gd -- NYC 138 141 18 28

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var city := a[0] if a.size() > 0 else "NYC"
	var x0 := (a[1] as String).to_int() if a.size() > 1 else 138
	var x1 := (a[2] as String).to_int() if a.size() > 2 else 141
	var y0 := (a[3] as String).to_int() if a.size() > 3 else 18
	var y1 := (a[4] as String).to_int() if a.size() > 4 else 28
	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in map.get_num_blocks(x, y):
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				print("(%3d,%3d,%d) flat=%s slope=%d rot=%d fLR=%s fTB=%s | L=%d R=%d T=%d B=%d lid=%d"
					% [x, y, z, b.is_flat(), b.slope_type(), b.rotation(),
						b.flip_left_right(), b.flip_top_bottom(),
						b.left, b.right, b.top, b.bottom, b.lid])
	quit(0)
