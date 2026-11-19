extends SceneTree
## Find GAPS in the road map: short runs (1..MAX_GAP cells) of non-road cells that
## sit in a straight line between two road cells — e.g. bridge sections whose tiles
## aren't in RoadGraph.ROAD_TILES, which leave traffic with nowhere to go. Prints a
## tally of the tiles found in the gaps plus a per-column dump of sample cells.
##   godot --headless --path . --script res://tests/diag_road_gaps.gd -- [CITY] [--elevated]
const MAX_GAP := 3
const MIN_Z := 2   # with --elevated: both road ends must be at least this stack level (bridges)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var elevated_only := args.has("--elevated")
	args.erase("--elevated")
	var city: String = args[0] if args.size() > 0 else "NYC"
	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	var g := RoadGraph.build(map)
	var dim := GTA1Map.DIM
	var gap_cells := {}   # Vector2i -> true
	for x in dim:
		for y in dim:
			if not g.is_road(Vector2i(x, y)):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				# Walk forward over non-road cells; a road cell within MAX_GAP closes a gap.
				var run: Array[Vector2i] = []
				var c := Vector2i(x, y) + d
				while run.size() <= MAX_GAP and c.x < dim and c.y < dim and not g.is_road(c):
					run.append(c)
					c += d
				if run.size() >= 1 and run.size() <= MAX_GAP and c.x < dim and c.y < dim \
						and g.is_road(c) and (not elevated_only or (g.surface_z[x * dim + y] >= MIN_Z \
						and g.surface_z[c.x * dim + c.y] >= MIN_Z)):
					for r in run:
						gap_cells[r] = true

	# Tally the gap cells by their top solid block's (lid, block_type, slope).
	var tally := {}
	for cell in gap_cells:
		var key := _top_desc(map, cell)
		tally[key] = tally.get(key, 0) + 1
	var keys := tally.keys()
	keys.sort_custom(func(a, b): return tally[a] > tally[b])
	print("[%s] gap cells: %d" % [city, gap_cells.size()])
	for k in keys:
		print("  %4d x  %s" % [tally[k], k])

	# Group gap cells into connected patches and dump one column per patch.
	var seen := {}
	var patches: Array = []
	for cell in gap_cells:
		if seen.has(cell):
			continue
		var patch: Array[Vector2i] = []
		var stack: Array[Vector2i] = [cell]
		seen[cell] = true
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			patch.append(p)
			for d in RoadGraph.DIRS:
				var q: Vector2i = p + d
				if gap_cells.has(q) and not seen.has(q):
					seen[q] = true
					stack.append(q)
		patches.append(patch)
	patches.sort_custom(func(a, b): return a.size() > b.size())
	print("patches: %d (largest first)" % patches.size())
	for patch in patches.slice(0, 25):
		var c: Vector2i = patch[0]
		print("  patch size %d at %v — column:" % [patch.size(), c])
		for z in range(map.get_num_blocks(c.x, c.y) - 1, -1, -1):
			var b := map.get_block(c.x, c.y, z)
			if b == null or b.is_empty():
				continue
			print("      z=%d lid=%d type=%d slope=%d flat=%s rot=%d" % [z, b.lid,
				b.block_type(), b.slope_type(), b.is_flat(), b.rotation()])
	quit(0)


func _top_desc(map: GTA1Map, c: Vector2i) -> String:
	for z in range(map.get_num_blocks(c.x, c.y) - 1, -1, -1):
		var b := map.get_block(c.x, c.y, z)
		if b == null or b.is_empty() or b.is_flat():
			continue
		return "lid=%d type=%d slope=%d" % [b.lid, b.block_type(), b.slope_type()]
	return "(no solid block)"
