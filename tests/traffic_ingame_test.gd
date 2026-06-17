extends SceneTree
## Load the real Drive scene and confirm the ambient traffic fleet spawns, stays on
## the road, AND actually travels the streets rather than orbiting a tiny loop. The
## path-SPAN check is the important one: a car circling a small box passes a naive
## "did it move / is it on a road tile" test but has a tiny bounding box.
## Output: _dump/traffic_ingame.png
const OUT := "res://_dump/"
const DIM := 256
func _init() -> void: _go()
func _go() -> void:
	var root := get_root(); root.size = Vector2i(1280, 720)
	var world := (load("res://scenes/Drive.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await create_timer(4.0).timeout

	var tm: TrafficManager = world.get("_traffic")
	if tm == null or tm.cars.is_empty():
		print("ERROR: no traffic spawned"); quit(1); return
	print("traffic cars: ", tm.cars.size())
	var g: RoadGraph = tm.graph
	var mins := []
	var maxs := []
	for c in tm.cars:
		mins.append(Vector2(c.global_position.x, c.global_position.z))
		maxs.append(Vector2(c.global_position.x, c.global_position.z))
	for t in 6:
		await create_timer(1.0).timeout
		for i in tm.cars.size():
			var p := Vector2(tm.cars[i].global_position.x, tm.cars[i].global_position.z)
			mins[i] = Vector2(minf(mins[i].x, p.x), minf(mins[i].y, p.y))
			maxs[i] = Vector2(maxf(maxs[i].x, p.x), maxf(maxs[i].y, p.y))

	var on_road := 0
	var spans := []
	for i in tm.cars.size():
		var c: TrafficCar = tm.cars[i]
		var cx := int(floor(c.global_position.x))
		var cy := int(floor(c.global_position.z))
		if cx >= 0 and cy >= 0 and cx < DIM and cy < DIM and g.surface_z[cx * DIM + cy] >= 0:
			on_road += 1
		var s: Vector2 = maxs[i] - mins[i]
		spans.append(maxf(s.x, s.y))
	spans.sort()
	var median: float = spans[spans.size() / 2]
	var travelled := 0
	for s in spans:
		if s > 6.0: travelled += 1
	print("on-road: %d/%d   travelled>6u: %d/%d   median span: %.1f" % [
		on_road, tm.cars.size(), travelled, tm.cars.size(), median])
	var ok := on_road >= tm.cars.size() * 9 / 10 and median > 6.0 and travelled > tm.cars.size() / 2
	print("RESULT: ", "TRAFFIC OK" if ok else "PROBLEM")
	root.get_texture().get_image().save_png(OUT + "traffic_ingame.png")
	print("saved ", OUT, "traffic_ingame.png")
	quit(0)
