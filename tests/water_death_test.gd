extends SceneTree

## Verify the "float, then sink, then water death" sequence in drive_world: drop the
## car into a river cell and confirm it bobs (FLOATING), goes under (SINKING) and is
## then respawned dry on the road (DRY), back where it started.
##   godot --headless --path . --script res://tests/water_death_test.gd

func _init() -> void: _go()

func _go() -> void:
	var scene: Node = load("res://scenes/Drive.tscn").instantiate()
	get_root().add_child(scene)
	# Let _ready build the city/water and spawn + settle the car.
	for i in 220:
		await physics_frame
	if scene.car == null:
		print("RESULT: FAIL — no car spawned"); quit(1); return
	var spawn: Vector3 = scene._spawn_pos
	print("water tile = %d   spawn = %v" % [scene._water_tile, spawn])

	# Drop the car into a known river cell (79,118 is water), just at the surface.
	scene.car.linear_velocity = Vector3.ZERO
	scene.car.angular_velocity = Vector3.ZERO
	scene.car.global_position = Vector3(79.5, WaterBuilder.WATER_LEVEL - 0.05, 118.5)

	var saw_float := false
	var saw_sink := false
	var sink_start_t := -1.0
	var death_t := -1.0
	var float_y := 0.0
	var min_y := 1000.0
	for i in 720:                       # ~12s — covers the ~10s float+sink+respawn
		await physics_frame
		var st: int = scene._water_state
		var y: float = scene.car.global_position.y
		min_y = minf(min_y, y)
		if st == 1:                     # FLOATING
			saw_float = true
			float_y = y
		elif st == 2:                   # SINKING
			if not saw_sink:
				sink_start_t = i / 60.0
			saw_sink = true
		elif saw_sink and death_t < 0.0:  # back to DRY after sinking = respawn
			death_t = i / 60.0
		if i % 60 == 0:
			print("  t=%.1fs state=%s y=%.2f mask=%d" % [i / 60.0, _name(st), y, scene.car.collision_mask])
	print("sink began ~%.1fs, respawned ~%.1fs  (sink lasted ~%.1fs)"
		% [sink_start_t, death_t, death_t - sink_start_t])

	var p: Vector3 = scene.car.global_position
	var back_at_spawn := Vector2(p.x, p.z).distance_to(Vector2(spawn.x, spawn.z)) < 1.0
	var dry: bool = scene._water_state == 0
	print("\nfloated=%s (y~%.2f)  sank=%s (min y=%.2f)  respawned_dry=%s at %v"
		% [saw_float, float_y, saw_sink, min_y, dry and back_at_spawn, p])
	var ok: bool = saw_float and saw_sink and dry and back_at_spawn and int(scene.car.collision_mask) == 1
	print("RESULT: %s" % ("PASS — float -> sink -> water death -> respawn" if ok else "FAIL"))
	quit(0 if ok else 1)


func _name(s: int) -> String:
	return ["DRY", "FLOATING", "SINKING"][s] if s >= 0 and s < 3 else str(s)
