extends SceneTree
## End-to-end: the real Drive scene should start ON FOOT beside a parked car; the
## walker can move; getting in transfers control to the car; getting out drops the
## walker back beside it.
func _init(): _go()
func _go():
	var scene: Node = load("res://scenes/Drive.tscn").instantiate()
	get_root().add_child(scene)
	for i in 220: await physics_frame
	var ok := true
	# 1) start on foot, car parked nearby
	var ped = scene._ped
	if ped == null: print("FAIL: no pedestrian"); quit(1); return
	var d0: float = ped.global_position.distance_to(scene.car.global_position)
	print("start: on_foot=%s  ped y=%.2f  car.use_input=%s  ped-car dist=%.2f" % [scene._on_foot, ped.global_position.y, scene.car.use_input, d0])
	ok = ok and scene._on_foot and not scene.car.use_input and d0 <= scene.ENTER_RANGE

	# 2) walk forward a bit (camera-relative path via _update_on_foot uses Input; call move directly)
	var p_before: Vector3 = ped.global_position
	for i in 60:
		var away = (ped.global_position - scene.car.global_position); away.y = 0; ped.move(1.0/60.0, away.normalized(), false)
		await physics_frame
	var walked: float = Vector2(p_before.x,p_before.z).distance_to(Vector2(ped.global_position.x, ped.global_position.z))
	print("walked %.2f units, on_floor=%s" % [walked, ped.is_on_floor()])
	ok = ok and walked > 0.1 and ped.is_on_floor()

	# 3) get in the car
	scene._ped.global_position = scene.car.global_position + Vector3(0.6,0.1,0)  # stand next to it
	await physics_frame
	scene._try_enter_car()
	await physics_frame
	print("entered: on_foot=%s  car.use_input=%s  ped.visible=%s" % [scene._on_foot, scene.car.use_input, ped.visible])
	ok = ok and not scene._on_foot and scene.car.use_input and not ped.visible

	# 4) get out
	scene._exit_car()
	for i in 30: await physics_frame
	var d1: float = ped.global_position.distance_to(scene.car.global_position)
	print("exited: on_foot=%s  car.use_input=%s  ped.visible=%s  ped-car dist=%.2f  ped y=%.2f" % [scene._on_foot, scene.car.use_input, ped.visible, d1, ped.global_position.y])
	ok = ok and scene._on_foot and not scene.car.use_input and ped.visible and d1 < 1.2

	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
