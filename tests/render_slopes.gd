extends SceneTree

## Find the densest cluster of slope blocks (a hill) in a city and frame it at a
## low angle, to judge the slope/ramp geometry.
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     --script res://tests/render_slopes.gd -- SANB

const OUT := "res://_dump/"


func _init() -> void:
	_go()


func _go() -> void:
	var city := "SANB"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		city = extra[0]

	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)

	var root := get_root()
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(MapBuilder.build(map, style))
	Scenery.add_sun(world)
	Scenery.add_ground(world, GTA1Map.DIM / 2.0, 0.9)
	var we := WorldEnvironment.new()
	we.environment = Scenery.make_environment()
	world.add_child(we)

	# Scan coarse windows for the most slope blocks.
	var best := Vector2i(128, 128)
	var best_score := -1
	var best_h := 1
	for cx in range(6, 250, 3):
		for cy in range(6, 250, 3):
			var s := 0
			var maxh := 1
			for dx in range(-5, 6):
				for dy in range(-5, 6):
					var x := cx + dx
					var y := cy + dy
					var n := map.get_num_blocks(x, y)
					maxh = maxi(maxh, n)
					for z in n:
						var b := map.get_block(x, y, z)
						if b != null and b.slope_type() != 0:
							s += 1
			if s > best_score:
				best_score = s
				best = Vector2i(cx, cy)
				best_h = maxh
	print("densest slope window at %s: %d slope blocks, max stack %d" % [best, best_score, best_h])

	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 2000.0
	world.add_child(cam)
	cam.current = true
	var cx2 := best.x + 0.5
	var cz := best.y + 0.5
	cam.fov = 60.0
	# Right down among the blocks to see ramp wedges vs. blocky steps.
	cam.look_at_from_position(Vector3(cx2 - 7.0, 3.2, cz - 7.0), Vector3(cx2, 0.8, cz), Vector3.UP)

	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "slopes.png")
	print("saved ", OUT, "slopes.png")
	quit(0)
