extends SceneTree
## Visualise pedestrian mode: a walker beside a parked car on a street, framed by a
## third-person camera (the on-foot view). No Drive controller (avoids mouse capture).
const OUT := "res://_dump/"
func _init(): _go()
func _go():
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1100, 720)
	var world := Node3D.new(); root.add_child(world)
	var city := MapBuilder.build(map, style); world.add_child(city)
	world.add_child(MapBuilder.build_collision(city.mesh))
	world.add_child(WaterBuilder.build(map))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)
	var spawn := SpawnFinder.find_drive_spawn(map)
	var sy := float(map.get_surface_y(spawn.x, spawn.y))
	var base := Vector3(spawn.x + 0.5, sy, spawn.y + 0.5)
	var carn := Car.new()
	carn.model_path = "res://assets/vehicles/psx/car1/Car.obj"
	carn.texture_path = "res://assets/vehicles/psx/car1/car_red.png"
	carn.model_yaw_deg = 180.0
	carn.use_input = false
	world.add_child(carn); carn.global_position = base + Vector3(0, 0.2, 0)
	var ped := Pedestrian.new()
	world.add_child(ped); ped.global_position = base + Vector3(0.8, 0.2, 0)
	var cam := Camera3D.new(); cam.fov = 70; cam.far = 2000.0
	world.add_child(cam); cam.current = true
	for i in 40: await physics_frame
	var pivot := ped.global_position + Vector3(0, 0.5, 0)
	cam.look_at_from_position(pivot + Vector3(1.4, 1.0, 1.8), pivot, Vector3.UP)
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(OUT + "pedcar.png")
	print("rendered ped=", ped.global_position, " car=", carn.global_position)
	quit(0)
