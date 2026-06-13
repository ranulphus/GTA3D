extends SceneTree

## Loads a real GTA1 city, extrudes it to a textured 3D mesh, and renders an
## aerial + a low/street-level screenshot. Offscreen software rendering.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/render_city.gd
##
## Optional first CLI arg after `--`: city base name (default NYC).

const OUT := "res://_dump/"


func _init() -> void:
	_go()


func _go() -> void:
	var city := "NYC"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		city = extra[0]

	var t0 := Time.get_ticks_msec()
	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	if map == null:
		push_error("no map"); quit(1); return
	var style_path := "res://data/STYLE%03d.G24" % map.style_number
	var style := GTA1Style.load_file(style_path)
	if style == null:
		push_error("no style at %s" % style_path); quit(1); return
	print("%s: style=%d (%s)  blocks=%d objects=%d" % [city, map.style_number, style_path, map.blocks.size(), map.objects.size()])

	var root := get_root()
	root.size = Vector2i(1280, 720)

	var world := Node3D.new()
	root.add_child(world)

	var city_mesh := MapBuilder.build(map, style)
	world.add_child(city_mesh)
	var tris := 0
	if city_mesh.mesh.get_surface_count() > 0:
		tris = city_mesh.mesh.surface_get_array_index_len(0) / 3
	print("built mesh in %d ms, ~%d triangles" % [Time.get_ticks_msec() - t0, tris])

	Scenery.add_sun(world)
	Scenery.add_ground(world, GTA1Map.DIM / 2.0, 0.9)
	var we := WorldEnvironment.new()
	we.environment = Scenery.make_environment()
	world.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 60
	cam.far = 3000.0
	world.add_child(cam)
	cam.current = true

	var c := GTA1Map.DIM / 2.0  # 128

	# Aerial overview of the whole city.
	cam.look_at_from_position(Vector3(c, 260, c + 230), Vector3(c, 0, c), Vector3.UP)
	await _frames()
	_save(root, OUT + "city_aerial.png")

	# Closer 3/4 view to show building height & textures.
	cam.look_at_from_position(Vector3(c, 40, c + 70), Vector3(c, 4, c), Vector3.UP)
	await _frames()
	_save(root, OUT + "city_closeup.png")

	# Ground / street level — camera down among the blocks looking along a road.
	cam.look_at_from_position(Vector3(c, 2.5, c + 45), Vector3(c, 2.2, c - 30), Vector3.UP)
	await _frames()
	_save(root, OUT + "city_street.png")

	# Street level at the actual drive spawn (matches what the player sees).
	var sp := SpawnFinder.find_drive_spawn(map)
	var sx := sp.x + 0.5
	var sz := sp.y + 0.5
	cam.look_at_from_position(Vector3(sx, 3.0, sz - 6.0), Vector3(sx, 2.0, sz + 10.0), Vector3.UP)
	await _frames()
	_save(root, OUT + "city_spawnview.png")

	# Near top-down over the road, to judge lid rotation (markings/arrows align).
	cam.look_at_from_position(Vector3(sx + 0.01, 24.0, sz), Vector3(sx, 1.0, sz), Vector3.UP)
	await _frames()
	_save(root, OUT + "city_topdown.png")

	quit(0)


func _frames() -> void:
	for i in 5:
		await process_frame


func _save(root: Window, path: String) -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	print("saved ", path, " -> ", error_string(err), " ", img.get_size())
