extends Node3D

## Placeholder entry point. For now it just reports whether GTA1 data is present
## and, if a .CMP is found, parses it and prints a summary. The 3D extrusion and
## car come in later phases (see docs/ROADMAP.md).

const DATA_DIR := "res://data/"


func _ready() -> void:
	print("GTA3D — street-level recreation of the original GTA")
	var cmp := _find_first(DATA_DIR, ".cmp")
	if cmp.is_empty():
		print("No .CMP map found under %s — see data/README.md to add your GTA1 files." % DATA_DIR)
		return
	print("Loading map: ", cmp)
	var map := GTA1Map.load_file(cmp)
	if map == null:
		return
	_summarize(map)


func _summarize(map: GTA1Map) -> void:
	print("  style number : ", map.style_number)
	print("  blocks       : ", map.blocks.size())
	print("  objects      : ", map.objects.size())
	# Count non-empty cells as a sanity check on the column decode.
	var filled := 0
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			if map.get_num_blocks(x, y) > 0:
				filled += 1
	print("  filled cells : %d / %d" % [filled, GTA1Map.DIM * GTA1Map.DIM])


func _find_first(dir: String, ext: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	for f in d.get_files():
		if f.to_lower().ends_with(ext):
			return dir + f
	return ""
