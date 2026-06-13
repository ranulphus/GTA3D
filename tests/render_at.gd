extends SceneTree
## Render the city around a given cell (CLI args: x z) from a low angled view and
## a near-top-down, to inspect bridges/ramps. Outputs _dump/at_angle.png etc.
const OUT := "res://_dump/"
func _init() -> void: _go()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var cx := (a[0] as String).to_int() if a.size() > 0 else 23
	var cz := (a[1] as String).to_int() if a.size() > 1 else 171
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1200, 760)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style))
	Scenery.add_sun(world)
	Scenery.add_ground(world, GTA1Map.DIM/2.0, 0.9)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var cam := Camera3D.new(); cam.fov = 60; cam.far = 3000.0; world.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(cx - 12, 10, cz + 12), Vector3(cx, 3, cz), Vector3.UP)
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(OUT + "at_angle.png")
	cam.look_at_from_position(Vector3(cx + 0.1, 22, cz), Vector3(cx, 2, cz), Vector3.UP)
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(OUT + "at_top.png")
	print("rendered around (", cx, ",", cz, ")")
	quit(0)
