extends SceneTree

## Reproduce the actual interactive Drive scene (drive_world.gd) headlessly:
## instance scenes/Drive.tscn exactly as the game/exe does, run physics for a
## few seconds, log the car's Y over time (to catch it falling through the map),
## and screenshot what the chase camera sees.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/drive_world_check.gd

const OUT := "res://_dump/"


func _init() -> void:
	_go()


func _go() -> void:
	var root := get_root()
	root.size = Vector2i(1280, 720)

	var scene := load("res://scenes/Drive.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)   # triggers drive_world._ready()

	# Let the engine run its normal loop for a few real seconds (a timer does not
	# manually step frames, so it won't interfere with the scene's async _ready).
	# The mesh build + collision bake take a couple seconds before the car spawns.
	await create_timer(4.0).timeout
	var car: Node3D = world.get("car")
	if car == null:
		print("ERROR: car not spawned yet"); quit(1); return
	print("after 1.5s: car.y=%.2f pos=%v" % [car.global_position.y, car.global_position])

	# Drive forward and confirm it moves and stays on the ground.
	var car2: Car = car
	car2.use_input = false
	car2.control_throttle = 1.0
	var p0 := car2.global_position
	await create_timer(2.5).timeout
	var p1 := car2.global_position
	var moved := Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
	print("after drive: car.y=%.2f moved=%.1f units" % [p1.y, moved])
	print("RESULT: %s" % ("DROVE OK" if (p1.y > -2.0 and moved > 2.0) else "PROBLEM"))

	var img := root.get_texture().get_image()
	img.save_png(OUT + "drive_world_view.png")
	print("saved ", OUT, "drive_world_view.png")
	quit(0)


func _tree(node: Node, depth: int) -> void:
	var extra := ""
	if node is CollisionShape3D:
		extra = " shape=%s" % ("none" if node.shape == null else node.shape.get_class())
	print("  ".repeat(depth), node.name, " <", node.get_class(), ">", extra)
	for child in node.get_children():
		_tree(child, depth + 1)
