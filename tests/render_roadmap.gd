extends SceneTree
## Load the real Drive scene and screenshot the road-map arrow overlay over a road
## area, top-down and angled, to confirm arrows sit on the roads. Output: _dump/roadmap*.png
const OUT := "res://_dump/"
func _init() -> void: _go()
func _go() -> void:
	var root := get_root(); root.size = Vector2i(1100, 1100)
	var world := (load("res://scenes/Drive.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await create_timer(4.0).timeout
	var overlay: Node3D = world.get_node_or_null("RoadMapOverlay")
	print("overlay present: ", overlay != null)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 48
	cam.far = 4000.0
	world.add_child(cam)
	cam.current = true
	var cx := 110.0
	var cz := 132.0
	cam.look_at_from_position(Vector3(cx, 120, cz + 0.01), Vector3(cx, 0, cz), Vector3.UP)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(OUT + "roadmap_top.png")

	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60
	cam.look_at_from_position(Vector3(cx - 14, 12, cz + 14), Vector3(cx, 1, cz), Vector3.UP)
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(OUT + "roadmap_angle.png")
	print("rendered road map")
	quit(0)
