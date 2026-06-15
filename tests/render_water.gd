extends SceneTree

## Render the city WITH the animated water surface, from an explicit camera, to
## eyeball the river waves. Renders two frames a moment apart so the wave motion is
## visible between them. Args: camx camy camz tgtx tgty tgtz [name]
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/render_water.gd -- 80 6 110 80 1 122 river

const OUT := "res://_dump/"

func _init() -> void: _go()

func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var f := func(i, d): return (a[i] as String).to_float() if a.size() > i else d
	var cam_pos := Vector3(f.call(0, 80.0), f.call(1, 6.0), f.call(2, 110.0))
	var tgt := Vector3(f.call(3, 80.0), f.call(4, 1.0), f.call(5, 122.0))
	var name: String = a[6] if a.size() > 6 else "water"

	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	print("water tile = ", WaterBuilder.detect_water_tile(map))
	var root := get_root(); root.size = Vector2i(1280, 800)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style))
	world.add_child(WaterBuilder.build(map))
	Scenery.add_sun(world)
	Scenery.add_ground(world, GTA1Map.DIM / 2.0, 0.85)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var cam := Camera3D.new(); cam.fov = 60; cam.far = 3000.0; world.add_child(cam); cam.current = true
	cam.look_at_from_position(cam_pos, tgt, Vector3.UP)

	for i in 30: await process_frame
	root.get_texture().get_image().save_png(OUT + name + "_a.png")
	for i in 45: await process_frame
	root.get_texture().get_image().save_png(OUT + name + "_b.png")
	print("rendered ", name, " cam=", cam_pos, " -> ", tgt)
	quit(0)
