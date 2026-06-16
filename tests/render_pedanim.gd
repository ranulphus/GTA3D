extends SceneTree
const OUT := "res://_dump/"
func _init(): _go()
func _go():
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(900, 760)
	var world := Node3D.new(); root.add_child(world)
	var city := MapBuilder.build(map, style); world.add_child(city)
	world.add_child(MapBuilder.build_collision(city.mesh))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var spawn := SpawnFinder.find_drive_spawn(map)
	var sy := float(map.get_surface_y(spawn.x, spawn.y))
	var ped := Pedestrian.new(); world.add_child(ped)
	ped.global_position = Vector3(spawn.x + 0.5, sy + 0.3, spawn.y + 0.5)
	var cam := Camera3D.new(); cam.fov = 45; cam.far = 2000.0; world.add_child(cam); cam.current = true
	for i in 40: await physics_frame
	var base := ped.global_position
	# walk in place-ish: feed a wish dir but pin position each frame so we can frame the legs from the side
	var shots := [["idle", 0, Vector3.ZERO], ["walk_a", 18, Vector3(0,0,-1)], ["walk_b", 40, Vector3(0,0,-1)]]
	for s in shots:
		# reset to base and run N frames of the given motion
		ped.global_position = base; ped.velocity = Vector3.ZERO
		for i in int(s[1]):
			ped.move(1.0/60.0, s[2], false)
			await physics_frame
		var p := ped.global_position
		# side-on view of the walker
		cam.look_at_from_position(p + Vector3(2.2, 0.5, 0), p + Vector3(0, 0.3, 0), Vector3.UP)
		for i in 3: await process_frame
		root.get_texture().get_image().save_png(OUT + "anim_" + str(s[0]) + ".png")
		# report model-vs-body offset to detect root-motion drift
		var mi = ped.get_node(".")
		print(s[0], ": ped moved to ", p, " clip=", ped._cur_clip)
	quit(0)
