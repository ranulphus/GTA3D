extends SceneTree
## Close low view around a cell. CLI: cx cy [eye_dx eye_dy eye_h]
const OUT := "res://_dump/"
func _init() -> void: _go()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var cx := int(a[0]); var cy := int(a[1])
	var dx := float(a[2]) if a.size()>2 else -6.0
	var dy := float(a[3]) if a.size()>3 else -6.0
	var eh := float(a[4]) if a.size()>4 else 4.5
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1200, 700)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style))
	Scenery.add_sun(world); Scenery.add_ground(world, GTA1Map.DIM/2.0, 0.9)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var cam := Camera3D.new(); cam.fov = 55; cam.far = 400.0; world.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(cx+dx, eh, cy+dy), Vector3(cx+1.0, 2.5, cy+1.0), Vector3.UP)
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(OUT + "close.png")
	print("rendered close ", cx, ",", cy)
	quit(0)
