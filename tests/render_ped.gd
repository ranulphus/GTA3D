extends SceneTree
## Render the pedestrian on a city street to check scale/orientation/texture, then
## walk it forward a second to confirm it moves and stays grounded.
const OUT := "res://_dump/"
func _init(): _go()
func _go():
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1100, 760)
	var world := Node3D.new(); root.add_child(world)
	var city := MapBuilder.build(map, style); world.add_child(city)
	world.add_child(MapBuilder.build_collision(city.mesh))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var spawn := SpawnFinder.find_drive_spawn(map)
	var sy := float(map.get_surface_y(spawn.x, spawn.y))
	var ped := Pedestrian.new(); world.add_child(ped)
	ped.global_position = Vector3(spawn.x + 0.5, sy + 0.3, spawn.y + 0.5)
	var cam := Camera3D.new(); cam.fov = 55; cam.far = 2000.0; world.add_child(cam); cam.current = true
	for i in 30:
		await physics_frame
	var p0 := ped.global_position
	print("spawn cell %s  ped rest y=%.2f" % [spawn, p0.y])
	# chase view (behind +Z)
	cam.look_at_from_position(p0 + Vector3(0, 0.6, 2.0), p0 + Vector3(0, 0.3, 0), Vector3.UP)
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(OUT + "ped_back.png")
	# front view (-Z)
	cam.look_at_from_position(p0 + Vector3(0, 0.5, -1.6), p0 + Vector3(0, 0.3, 0), Vector3.UP)
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(OUT + "ped_front.png")
	# walk forward (-Z) for ~1.2s
	for i in 72:
		ped.move(1.0/60.0, Vector3(0, 0, -1), false)
		await physics_frame
	var p1 := ped.global_position
	print("walked %.2f units, end y=%.2f, on_floor=%s" % [Vector2(p0.x,p0.z).distance_to(Vector2(p1.x,p1.z)), p1.y, ped.is_on_floor()])
	cam.look_at_from_position(p1 + Vector3(0, 0.6, 2.0), p1 + Vector3(0, 0.3, 0), Vector3.UP)
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(OUT + "ped_walked.png")
	quit(0)
