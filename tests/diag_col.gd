extends SceneTree
## Print the full block stack at given cells: z, slopeType, flat?, blockType, and
## the 5 face tile-ids (lid/left/right/top/bottom). Reveals decks made of flat or
## otherwise-skipped blocks. CLI: x y [x2 y2 ...]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var i := 0
	while i + 1 < a.size():
		var x := int(a[i]); var y := int(a[i+1]); i += 2
		var n := map.get_num_blocks(x, y)
		print("=== (%d,%d)  num_blocks=%d  surface_y=%d ===" % [x, y, n, map.get_surface_y(x, y)])
		for z in n:
			var b := map.get_block(x, y, z)
			if b == null: continue
			var tag := ""
			if b.is_empty(): tag = "EMPTY"
			elif b.is_flat(): tag = "FLAT"
			elif b.slope_type() != 0: tag = "slope%d" % b.slope_type()
			else: tag = "cube"
			print("  z=%d  %-8s btype=%d  lid=%d L=%d R=%d T=%d B=%d  rot=%d" % [z, tag, b.block_type(), b.lid, b.left, b.right, b.top, b.bottom, b.rotation()])
	quit(0)
