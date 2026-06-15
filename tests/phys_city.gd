extends SceneTree
## Physics validation of the trimesh city collision (now headless physics is known
## to run — see phys_probe.gd):
##   A) ball dropped on a normal road rests on it,
##   B) ball dropped UNDER an overpass deck rests on the under-road (drive-under),
##   C) the real Car driven at full throttle stays on the road (no tunnelling),
##   D) raycast floors at several cells.
##   godot --headless --path . --script res://tests/phys_city.gd
func _init() -> void:
	_go()


func _go() -> void:
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var root := get_root()
	root.add_child(MapBuilder.build_collision(map))
	for _i in 10:
		await physics_frame
	var space := root.world_3d.direct_space_state

	_ray(space, "road (130,132)", 130.5, 132.5)
	_ray(space, "overpass roof (8,150)", 8.5, 150.5)

	# A) ball on a normal road (floor Y=2).
	var a := _drop(root, Vector3(130.5, 4.0, 132.5), 150)
	await _settle(150)
	print("A road ball y=%.2f  (expect ~2.2)" % a.position.y)

	# B) ball started under the deck at (8,150): floor Y=2, deck underside Y=3.
	var b := _drop(root, Vector3(8.5, 2.7, 150.5), 150)
	await _settle(150)
	print("B under-deck ball y=%.2f  (expect ~2.2 -> supported under bridge)" % b.position.y)

	# C) real Car, full throttle across the road for 4s.
	var car := Car.new()
	car.use_input = false
	root.add_child(car)
	car.global_position = Vector3(130.5, 2.5, 132.5)
	await physics_frame
	car.control_throttle = 1.0
	var min_y := 99.0
	for _i in 240:
		await physics_frame
		min_y = minf(min_y, car.global_position.y)
	var contacts := 0
	for ch in car.get_children():
		if ch is VehicleWheel3D and ch.is_in_contact():
			contacts += 1
	print("C car y=%.2f  min_y=%.2f  wheels=%d/4  moved=%.1f  (no tunnel if min_y>0)"
		% [car.global_position.y, min_y, contacts, car.global_position.distance_to(Vector3(130.5, 2.5, 132.5))])
	quit(0)


func _ray(space, label: String, x: float, z: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, -10, z))
	var hit: Dictionary = space.intersect_ray(q)
	print("ray %s -> %s" % [label, ("y=%.2f" % hit.position.y) if not hit.is_empty() else "MISS"])


func _drop(root, pos: Vector3, _frames: int) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.continuous_cd = true
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new(); sph.radius = 0.2; cs.shape = sph
	ball.add_child(cs)
	root.add_child(ball)
	ball.position = pos
	return ball


func _settle(n: int) -> void:
	for _i in n:
		await physics_frame
