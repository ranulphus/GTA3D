extends SceneTree

## Validation tool for REAL GTA1 data. Loads the first .CMP map and .G24 style
## found under res://data/, prints sanity stats, and exports visual proofs to
## the output dir: a tile atlas PNG and a top-down lid preview of the city.
##
## This is how we confirm the parsers (and the column/tile/CLUT decode) against
## real bytes once data files are present.
##
## Run with:  godot --headless --path . --script res://tests/dump_real_data.gd
## Output dir override:  --  (defaults to user:// which maps to the project)

const DATA := "res://data/"
const OUT := "res://_dump/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_dump_style()
	_dump_map()
	quit(0)


func _first(ext: String) -> String:
	var d := DirAccess.open(DATA)
	if d == null:
		return ""
	for f in d.get_files():
		if f.to_lower().ends_with(ext):
			return DATA + f
	return ""


func _dump_style() -> void:
	var path := _first(".g24")
	if path.is_empty():
		print("[style] no .G24 under ", DATA)
		return
	print("[style] loading ", path)
	var s := GTA1Style.load_file(path)
	if s == null:
		return
	print("  tiles: side=%d lid=%d aux=%d (total %d)" % [s.num_side, s.num_lid, s.num_aux, s.tile_count()])
	# Build an atlas of the first 256 side tiles (16x16 grid of 64x64).
	var cols := 16
	var rows := 16
	var atlas := Image.create(cols * 64, rows * 64, false, Image.FORMAT_RGBA8)
	for i in mini(cols * rows, s.num_side):
		var tile := s.get_tile_image(GTA1Style.TileKind.SIDE, i)
		atlas.blit_rect(tile, Rect2i(0, 0, 64, 64), Vector2i((i % cols) * 64, (i / cols) * 64))
	atlas.save_png(OUT + "side_atlas.png")
	print("  wrote ", OUT, "side_atlas.png")


func _dump_map() -> void:
	var path := _first(".cmp")
	if path.is_empty():
		print("[map] no .CMP under ", DATA)
		return
	print("[map] loading ", path)
	var m := GTA1Map.load_file(path)
	if m == null:
		return
	var filled := 0
	var max_stack := 0
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			var n := m.get_num_blocks(x, y)
			if n > 0:
				filled += 1
				max_stack = maxi(max_stack, n)
	print("  style=%d blocks=%d objects=%d filled_cells=%d max_stack=%d" % \
		[m.style_number, m.blocks.size(), m.objects.size(), filled, max_stack])
	# Top-down preview: mark cells that have any blocks (proves the column decode).
	var prev := Image.create(GTA1Map.DIM, GTA1Map.DIM, false, Image.FORMAT_RGB8)
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			var n := m.get_num_blocks(x, y)
			var v := clampi(n * 40, 0, 255)
			prev.set_pixel(x, y, Color8(v, v, v))
	prev.save_png(OUT + "map_topdown.png")
	print("  wrote ", OUT, "map_topdown.png")
