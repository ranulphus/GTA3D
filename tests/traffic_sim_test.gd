extends SceneTree
## Spawn a small traffic fleet, step it deterministically, and check the cars move
## along the road network without leaving it. Then render top-down so the cars are
## visibly on the streets. Output: _dump/traffic.png
const OUT := "res://_dump/"
const DIM := 256
func _init() -> void: _go()
func _go() -> void:
	var near := Vector2i(66, 164)
	var region := Rect2i(48, 148, 40, 40)
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)
	var root := get_root(); root.size = Vector2i(1000, 1000)
	var world := Node3D.new(); root.add_child(world)
	world.add_child(MapBuilder.build(map, style, region))
	Scenery.add_sun(world)
	var we := WorldEnvironment.new(); we.environment = Scenery.make_environment(); world.add_child(we)

	var g := RoadGraph.build(map)
	world.add_child(g.build_debug_mesh(region))

	var tm := TrafficManager.new(); world.add_child(tm)
	tm.populate(g, 8, near, 16, false)   # auto=false: we step it by hand
	for i in 2: await process_frame      # let each car's _ready run (enters tree)
	print("spawned ", tm.cars.size(), " cars")

	# Record start cells, step the sim, verify movement + staying on road.
	var start := []
	for c in tm.cars: start.append(c.global_position)
	var step := 1.0 / 60.0
	var off_road := 0
	for i in 1200:
		tm.tick(step)
		if i % 200 == 199:
			for c in tm.cars:
				var cx := int(floor(c.global_position.x))
				var cy := int(floor(c.global_position.z))
				if cx < 0 or cy < 0 or cx >= DIM or cy >= DIM or g.surface_z[cx * DIM + cy] < 0:
					off_road += 1
	var moved := 0
	for i in tm.cars.size():
		if tm.cars[i].global_position.distance_to(start[i]) > 1.0:
			moved += 1
	print("moved>1u: ", moved, "/", tm.cars.size(), "   off-road samples: ", off_road)

	var cx := region.position.x + region.size.x / 2.0
	var cz := region.position.y + region.size.y / 2.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = region.size.x + 2
	cam.far = 3000.0
	world.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(cx, 120, cz + 0.01), Vector3(cx, 0, cz), Vector3.UP)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(OUT + "traffic.png")

	# Angled close-up on the fleet so the car meshes are visible.
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 55
	var look := Vector3(near.x + 0.5, 2.0, near.y + 0.5)
	cam.look_at_from_position(look + Vector3(-6, 6, -6), look, Vector3.UP)
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(OUT + "traffic_close.png")
	print("rendered traffic")
	quit(0)
