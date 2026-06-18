extends SceneTree
## Render labelled swatches of EVERY distinct ground tile in NYC.CMP, sorted by tile
## number, across several sheets so a human can identify all the road tiles.
## Output: _dump/tile_swatches_1.png, _2.png, ...
const OUT := "res://_dump/"
const ALL := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 15, 16, 17, 18, 19, 22, 23, 24, 25, 30,
	31, 37, 38, 39, 43, 47, 48, 51, 54, 58, 60, 61, 62, 63, 69, 70, 71, 74, 75, 76, 78,
	79, 80, 81, 82, 89, 90, 91, 92, 93, 98, 99, 107, 108, 115, 119, 120, 122, 126, 127,
	133, 134, 135, 142, 146, 147, 151]
const PER_PAGE := 32   # 8 cols x 4 rows, fits the 1152x648 render viewport
func _init() -> void: _go()
func _go() -> void:
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root()
	var pages := int(ceil(float(ALL.size()) / PER_PAGE))
	for p in pages:
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(holder)
		var bg := ColorRect.new()
		bg.color = Color(0.12, 0.12, 0.14)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(bg)
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		grid.position = Vector2(12, 12)
		holder.add_child(grid)
		for k in range(p * PER_PAGE, mini((p + 1) * PER_PAGE, ALL.size())):
			var id: int = ALL[k]
			var img := style.get_tile_image_global(style.num_side + id)
			var vb := VBoxContainer.new()
			var tr := TextureRect.new()
			if img != null:
				tr.texture = ImageTexture.create_from_image(img)
			tr.custom_minimum_size = Vector2(118, 118)
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			vb.add_child(tr)
			var lbl := Label.new()
			lbl.text = "tile %d" % id
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			vb.add_child(lbl)
			grid.add_child(vb)
		for i in 6: await process_frame
		root.get_texture().get_image().save_png(OUT + "tile_swatches_%d.png" % (p + 1))
		holder.queue_free()
		await process_frame
	print("rendered ", pages, " swatch sheets")
	quit(0)
