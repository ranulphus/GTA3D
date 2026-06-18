extends SceneTree
## Plain textured top-down of a small region (no overlay), framed to match a tile-ID
## grid dump, so the road can be spotted by eye and its tile read off. Spans world
## X/Z [108,132]x[128,152] at 1024px => 24 cells => ~42px/cell.
const OUT := "res://_dump/"
func _init() -> void: _go()
func _go() -> void:
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1008, 1008)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style, Rect2i(104, 124, 32, 32)))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 24
	cam.far = 4000.0
	world.add_child(cam); cam.current = true
	# Centre of [108,132]x[128,152] = (120,140). +Z is image-down, +X image-right.
	cam.look_at_from_position(Vector3(120, 120, 140), Vector3(120, 0, 140), Vector3(0, 0, -1))
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(OUT + "tiles_top.png")
	print("rendered tiles; view spans X[108..132] right, Z[128..152] up")
	quit(0)
