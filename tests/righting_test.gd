extends SceneTree

## Headless validation of the self-righting fix: a car that is knocked onto its
## side / nose / tail / roof must rotate back onto all four wheels instead of
## getting stuck tilted. For each case we drop the car slightly airborne at a
## forced tilt, run physics for ~2.5s, and report the final tilt angle and how
## many wheels end up on the ground. It must finish near-upright (tilt < ~12 deg)
## with 4 wheels down. A flat-ground control confirms normal driving is unchanged.
##
##   godot --headless --path . --script res://tests/righting_test.gd -- NYC

func _init() -> void:
	_go()


func _go() -> void:
	var city_name := "NYC"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		city_name = extra[0]

	var map := GTA1Map.load_file("res://data/%s.CMP" % city_name)
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)

	var root := get_root()
	var world := Node3D.new()
	root.add_child(world)
	var city := MapBuilder.build(map, style)
	world.add_child(city)
	world.add_child(MapBuilder.build_collision(city.mesh))

	var spawn := SpawnFinder.find_drive_spawn(map)
	var surface_y := float(map.get_num_blocks(spawn.x, spawn.y))
	var base := Vector3(spawn.x + 0.5, surface_y + 0.4, spawn.y + 0.5)
	print("spawn cell %s surface_y=%.1f" % [spawn, surface_y])

	var car := Car.new()
	car.use_input = false
	world.add_child(car)
	car.global_position = base
	for i in 90:
		await physics_frame
	print("settled: tilt=%.1f deg  wheels=%d/4  y=%.2f\n" % [_tilt(car), _grounded(car), car.global_position.y])

	# tilt cases: (label, euler-degrees applied as the starting orientation)
	var cases := [
		["side wheelie (roll 80)",  Vector3(0, 0, 80)],
		["roll onto roof  (150)",   Vector3(0, 0, 150)],
		["back wheelie (pitch 70)",  Vector3(70, 0, 0)],
		["front wheelie (pitch -70)", Vector3(-70, 0, 0)],
		["diagonal flip",            Vector3(60, 30, 70)],
	]
	var all_ok := true
	for c in cases:
		var ok := await _try_case(car, base, c[0], c[1])
		all_ok = all_ok and ok

	# Control: upright on flat ground must stay put (no phantom righting wobble).
	_reset(car, base, Vector3.ZERO)
	for i in 80:
		await physics_frame
	var flat_tilt := _tilt(car)
	var flat_ok := flat_tilt < 6.0
	all_ok = all_ok and flat_ok
	print("CONTROL flat-ground: tilt=%.1f deg  wheels=%d/4  -> %s" % [flat_tilt, _grounded(car), "OK" if flat_ok else "WOBBLE"])

	print("\nRESULT: %s" % ("ALL CARS RIGHT THEMSELVES" if all_ok else "SOME CASES FAILED"))
	quit(0 if all_ok else 1)


func _try_case(car: Car, base: Vector3, label: String, euler_deg: Vector3) -> bool:
	_reset(car, base + Vector3(0, 0.6, 0), euler_deg)
	# give it a small shove so it isn't a perfectly balanced edge case
	car.angular_velocity = Vector3(0.5, 0, 0.5)
	var start_tilt := _tilt(car)
	for i in 150:                 # ~2.5s at 60Hz
		await physics_frame
	var end_tilt := _tilt(car)
	var grounded := _grounded(car)
	var ok := end_tilt < 12.0 and grounded >= 4
	print("%-26s start=%5.1f deg -> end=%5.1f deg  wheels=%d/4  %s"
		% [label, start_tilt, end_tilt, grounded, "OK" if ok else "STUCK"])
	return ok


func _reset(car: Car, pos: Vector3, euler_deg: Vector3) -> void:
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	var b := Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	car.global_transform = Transform3D(b, pos)


## Angle (deg) between the car's up vector and world up — 0 = perfectly upright.
func _tilt(car: Car) -> float:
	return rad_to_deg(car.global_transform.basis.y.angle_to(Vector3.UP))


func _grounded(car: Car) -> int:
	var n := 0
	for ch in car.get_children():
		if ch is VehicleWheel3D and ch.is_in_contact():
			n += 1
	return n
