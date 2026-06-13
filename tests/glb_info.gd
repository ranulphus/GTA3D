extends SceneTree

## Inspect + render a vehicle GLB: prints the node tree and combined AABB
## (so we know real-world size for physics scaling), and saves a preview PNG.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/glb_info.gd -- sedan

const OUT := "res://_dump/"


func _init() -> void:
	_go()


func _go() -> void:
	var name := "sedan"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		name = extra[0]

	var ps := load("res://assets/vehicles/%s.glb" % name) as PackedScene
	if ps == null:
		push_error("could not load %s.glb" % name); quit(1); return
	var car := ps.instantiate()

	var root := get_root()
	root.size = Vector2i(800, 600)
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(car)

	var aabb := _combined_aabb(car, Transform3D.IDENTITY)
	print("%s.glb tree:" % name)
	_print_tree(car, 1)
	print("AABB size = ", aabb.size, "  center = ", aabb.get_center())

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -40, 0)
	world.add_child(light)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.45, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.8
	we.environment = env
	world.add_child(we)

	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var r := maxf(aabb.size.length(), 1.0)
	cam.look_at_from_position(aabb.get_center() + Vector3(r, r * 0.8, r), aabb.get_center(), Vector3.UP)

	for i in 5:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OUT + "vehicle_%s.png" % name)
	print("saved ", OUT, "vehicle_%s.png" % name)
	quit(0)


func _combined_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	if node is MeshInstance3D and node.mesh != null:
		var a: AABB = (node as MeshInstance3D).mesh.get_aabb()
		a = (node as Node3D).transform * a
		result = a
		has = true
	for child in node.get_children():
		var ca := _combined_aabb(child, xform)
		if ca.size != Vector3.ZERO:
			result = result.merge(ca) if has else ca
			has = true
	return result


func _print_tree(node: Node, depth: int) -> void:
	print("  ".repeat(depth), node.name, " <", node.get_class(), ">")
	for child in node.get_children():
		_print_tree(child, depth + 1)
