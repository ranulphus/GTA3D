extends SceneTree
## Load the real Drive scene and confirm the ambient traffic fleet spawns and
## self-drives (auto via _physics_process), without breaking the existing scene.
## Output: _dump/traffic_ingame.png
const OUT := "res://_dump/"
func _init() -> void: _go()
func _go() -> void:
	var root := get_root(); root.size = Vector2i(1280, 720)
	var world := (load("res://scenes/Drive.tscn") as PackedScene).instantiate()
	root.add_child(world)               # triggers drive_world._ready()
	await create_timer(4.0).timeout     # mesh build + collision bake + spawns

	var tm: TrafficManager = world.get("_traffic")
	if tm == null or tm.cars.is_empty():
		print("ERROR: no traffic spawned"); quit(1); return
	print("traffic cars: ", tm.cars.size())
	var p0 := []
	for c in tm.cars: p0.append(c.global_position)
	await create_timer(3.0).timeout
	var moved := 0
	var on_road := 0
	var g: RoadGraph = tm.graph
	for i in tm.cars.size():
		var c: TrafficCar = tm.cars[i]
		if c.global_position.distance_to(p0[i]) > 0.8:
			moved += 1
		var cx := int(floor(c.global_position.x))
		var cy := int(floor(c.global_position.z))
		if cx >= 0 and cy >= 0 and cx < 256 and cy < 256 and g.surface_z[cx * 256 + cy] >= 0:
			on_road += 1
	print("moved: ", moved, "/", tm.cars.size(), "   on-road: ", on_road, "/", tm.cars.size())
	# Detail the off-road cars: where are they vs their current node?
	var shown := 0
	for c: TrafficCar in tm.cars:
		var cx := int(floor(c.global_position.x))
		var cy := int(floor(c.global_position.z))
		var onr := cx >= 0 and cy >= 0 and cx < 256 and cy < 256 and g.surface_z[cx * 256 + cy] >= 0
		if not onr and shown < 8:
			var ndist := c.global_position.distance_to((g.nodes[c._cell] as Dictionary).pos) if g.nodes.has(c._cell) else -1.0
			print("   OFF pos=%v cell=%s node_dist=%.2f y=%.2f" % [c.global_position, c._cell, ndist, c.global_position.y])
			shown += 1
	print("RESULT: ", "TRAFFIC OK" if moved > tm.cars.size() / 2 and on_road > tm.cars.size() * 3 / 4 else "PROBLEM")
	root.get_texture().get_image().save_png(OUT + "traffic_ingame.png")
	print("saved ", OUT, "traffic_ingame.png")
	quit(0)
