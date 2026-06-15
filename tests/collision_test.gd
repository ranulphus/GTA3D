extends SceneTree

## Isolate the fall-through: build the city + trimesh collision exactly like the
## game, then (a) raycast down at the spawn and (b) drop a plain RigidBody ball.
## If both hit the floor, collision is fine and the Car is the problem.
##   godot --headless --path . --script res://tests/collision_test.gd


func _init() -> void:
	_go()


func _go() -> void:
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE001.G24")
	var root := get_root()

	var city := MapBuilder.build(map, style)
	root.add_child(city)
	root.add_child(MapBuilder.build_collision(map))

	var spawn := SpawnFinder.find_drive_spawn(map)
	var sx := spawn.x + 0.5
	var sz := spawn.y + 0.5
	var surface_y := float(map.get_num_blocks(spawn.x, spawn.y))
	print("spawn (%d,%d) surface_y=%.1f" % [spawn.x, spawn.y, surface_y])

	await physics_frame
	await physics_frame
	await physics_frame

	var space := root.world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(sx, 30, sz), Vector3(sx, -30, sz))
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		print("RAYCAST: MISS (no collision floor at spawn!)")
	else:
		print("RAYCAST: HIT at y=%.3f" % hit.position.y)

	var ball := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.4
	cs.shape = sph
	ball.add_child(cs)
	root.add_child(ball)
	ball.global_position = Vector3(sx, surface_y + 4.0, sz)
	for i in 150:
		await physics_frame
	print("BALL final y=%.3f (should rest near %.1f; large negative = fell through)" % [ball.global_position.y, surface_y])

	# Now the actual Car in the SAME working harness.
	var car := Car.new()
	car.use_input = false
	root.add_child(car)
	car.global_position = Vector3(sx + 2.0, surface_y + 1.0, sz)
	for i in 150:
		await physics_frame
	print("CAR  final y=%.3f  (fell through if large negative)" % car.global_position.y)
	var contacts := 0
	for ch in car.get_children():
		if ch is VehicleWheel3D and ch.is_in_contact():
			contacts += 1
	print("CAR  wheels in contact = %d/4" % contacts)

	quit(0)
