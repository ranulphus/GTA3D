extends SceneTree
## Build the road graph and draw it over the city, top-down, to confirm the derived
## network actually follows the streets. CLI args: x y size  (region origin + side).
## Output: _dump/roadgraph.png
const OUT := "res://_dump/"
func _init() -> void: _go()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var ox := (a[0] as String).to_int() if a.size() > 0 else 34
	var oy := (a[1] as String).to_int() if a.size() > 1 else 120
	var sz := (a[2] as String).to_int() if a.size() > 2 else 64
	var region := Rect2i(ox, oy, sz, sz)

	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1000, 1000)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style, region))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)

	var g := RoadGraph.build(map)
	world.add_child(g.build_debug_mesh(region))
	print("nodes=", g.nodes.size())

	var cx := ox + sz / 2.0
	var cz := oy + sz / 2.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = sz + 2
	cam.far = 3000.0
	world.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(cx, 120, cz + 0.01), Vector3(cx, 0, cz), Vector3.UP)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(OUT + "roadgraph.png")
	print("rendered road graph over ", region)
	quit(0)
