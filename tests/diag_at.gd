extends SceneTree
## Dump a region around a cell: per cell show surface slope_type/rotation and the
## actual top-of-lid height (or '..' if empty). CLI: cx cy [half]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var cx := int(a[0]) if a.size() > 0 else 90
	var cy := int(a[1]) if a.size() > 1 else 106
	var h := int(a[2]) if a.size() > 2 else 11
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	print("=== around X=%d Y=%d  (cell = slopeType,rotation @ lidTopHeight) ===" % [cx, cy])
	# header of X columns
	var head := "  Y\\X "
	for x in range(cx - h, cx + h + 1): head += "%5d" % x
	print(head)
	for y in range(cy - h, cy + h + 1):
		var line := "%5d " % y
		for x in range(cx - h, cx + h + 1):
			var n := map.get_surface_y(x, y)
			if n <= 0:
				line += "  .. "
				continue
			var b := map.get_block(x, y, n - 1)
			if b == null:
				line += "  .. "
				continue
			var st := b.slope_type()
			if st == 0:
				line += " %3.1f" % _toph(map, x, y)   # flat: just height
			else:
				line += "%2d^%d" % [st, b.rotation()]   # slope: type^rot
		print(line)
	# explicit height profile along the bridge through the center row and column
	print("--- lid-height along row Y=%d:" % cy)
	var r := ""
	for x in range(cx - h, cx + h + 1): r += "%.2f " % _toph(map, x, cy)
	print(r)
	print("--- lid-height along col X=%d:" % cx)
	var c := ""
	for y in range(cy - h, cy + h + 1): c += "%.2f " % _toph(map, cx, y)
	print(c)
	quit(0)

func _toph(map: GTA1Map, x: int, y: int) -> float:
	var n := map.get_surface_y(x, y)
	if n <= 0: return 0.0
	var b := map.get_block(x, y, n - 1)
	if b == null: return 0.0
	var maxy := 0.0
	for v in SlopeData.faces[b.slope_type()][0]: maxy = maxf(maxy, v.y)
	return float(n - 1) + maxy
