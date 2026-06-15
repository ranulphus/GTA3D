extends SceneTree

## Measure braking on an open flat floor: settle the car, set it cruising forward,
## then hold the brake and report time + distance to stop. Used to confirm braking
## got ~2x faster (compare against an old build / the BRAKE_PER_PT sweep).
##
##   godot --headless --path . --script res://tests/brake_test.gd

func _init() -> void:
	_go()


func _go() -> void:
	var root := get_root()
	var world := Node3D.new()
	root.add_child(world)

	# Big flat collision floor at y=0.
	var floor_body := StaticBody3D.new()
	var fshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(2000, 1, 2000)
	fshape.shape = fbox
	fshape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fshape)
	world.add_child(floor_body)

	var car := Car.new()
	car.use_input = false
	car.speed_score = 6.0
	car.accel_score = 7.0
	car.brake_score = 6.0
	car.handling_score = 7.0
	world.add_child(car)
	car.global_position = Vector3(0, 0.5, 0)
	for i in 90:
		await physics_frame

	# Cruise forward (the car's hood is -Z).
	var v_cruise := 15.0
	var fwd := -car.global_transform.basis.z
	car.linear_velocity = fwd * v_cruise
	await physics_frame
	var v0 := car.linear_velocity.length()
	var p0 := car.global_position

	# Brake: reverse held while moving forward = brake.
	car.control_throttle = -1.0
	var frames := 0
	for i in 600:
		await physics_frame
		frames += 1
		if car.linear_velocity.length() < 0.5:
			break
	var p1 := car.global_position
	var dist := Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
	print("brake_force=%.1f  from %.1f m/s -> stop in %.2f s over %.2f units"
		% [car._brake_force, v0, frames / 60.0, dist])
	quit(0)
