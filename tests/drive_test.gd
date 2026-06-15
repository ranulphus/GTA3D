extends SceneTree

## Headless validation of the milestone: load a real GTA1 city, give it trimesh
## collision, spawn the Car on a street, apply throttle, and confirm it actually
## drives. Renders a chase-cam screenshot before and after, and prints how far
## the car moved.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/drive_test.gd -- NYC

const OUT := "res://_dump/"


func _init() -> void:
	_go()


func _go() -> void:
	var city_name := "NYC"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		city_name = extra[0]

	var map := GTA1Map.load_file("res://data/%s.CMP" % city_name)
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)

	var root := get_root()
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)

	var city := MapBuilder.build(map, style)
	world.add_child(city)
	world.add_child(MapBuilder.build_collision(map))   # purpose-built trimesh collision

	_setup_env(world)
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 2000.0
	world.add_child(cam)
	cam.current = true

	# The car drives toward -Z (hood-first) and a RigidBody ignores look_at, so we
	# leave it at its default orientation and just measure horizontal distance
	# travelled (direction-agnostic). See drive_world_check.gd for the real scene.
	var spawn := SpawnFinder.find_drive_spawn(map)
	var surface_y := float(map.get_num_blocks(spawn.x, spawn.y))
	print("spawn cell %s, surface_y=%.1f" % [spawn, surface_y])

	var car := Car.new()
	car.use_input = false
	world.add_child(car)
	car.global_position = Vector3(spawn.x + 0.5, surface_y + 0.4, spawn.y + 0.5)

	# Let it settle onto the road.
	for i in 70:
		await physics_frame
		_chase(cam, car)
	var p0 := car.global_position
	var contacts := 0
	for ch in car.get_children():
		if ch is VehicleWheel3D:
			if ch.is_in_contact():
				contacts += 1
	print("wheels in contact after settle: %d/4  (rest y=%.2f)" % [contacts, p0.y])
	_save(root, OUT + "drive_before.png")

	# Floor it.
	car.control_throttle = 1.0
	for i in 220:
		await physics_frame
		_chase(cam, car)
		if i % 60 == 0:
			print("  t=%d  speed=%.2f  vel_dir=%v  pos=%v" % [i, car.linear_velocity.length(), car.linear_velocity.normalized(), car.global_position])
	var p1 := car.global_position

	var moved := Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
	print("car start = %v" % p0)
	print("car end   = %v" % p1)
	print("HORIZONTAL DISTANCE DRIVEN = %.2f units (%.1f speed final)" % [moved, car.linear_velocity.length()])
	print("RESULT: %s" % ("DROVE OK" if moved > 2.0 else "DID NOT MOVE ENOUGH"))
	_save(root, OUT + "drive_after.png")

	quit(0)


func _setup_env(world: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.light_energy = 1.1
	world.add_child(light)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.62, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 0.9
	we.environment = env
	world.add_child(we)


func _chase(cam: Camera3D, car: Car) -> void:
	var basis := car.global_transform.basis
	var back := basis * Vector3(0, 3.0, 7.0)    # behind (+Z local) and above
	cam.look_at_from_position(car.global_position + back, car.global_position + Vector3(0, 0.8, 0), Vector3.UP)


func _save(root: Window, path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
