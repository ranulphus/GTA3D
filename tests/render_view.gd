extends SceneTree

## Render the city from an explicit camera position toward an explicit target, to
## read wall banners / road signs. Args: camx camy camz  tgtx tgty tgtz  [out]
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/render_view.gd -- 142.5 3 22 139.5 2.5 22 hospital

const OUT := "res://_dump/"

func _init() -> void: _go()

func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var f := func(i, d): return (a[i] as String).to_float() if a.size() > i else d
	var cam_pos := Vector3(f.call(0, 0.0), f.call(1, 5.0), f.call(2, 0.0))
	var tgt := Vector3(f.call(3, 0.0), f.call(4, 2.0), f.call(5, 0.0))
	var name: String = a[6] if a.size() > 6 else "view"

	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1280, 820)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var cam := Camera3D.new(); cam.fov = 55; cam.far = 3000.0; world.add_child(cam); cam.current = true
	cam.look_at_from_position(cam_pos, tgt, Vector3.UP)
	for i in 8: await process_frame
	var path := OUT + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("rendered ", name, " cam=", cam_pos, " -> ", tgt)
	quit(0)
