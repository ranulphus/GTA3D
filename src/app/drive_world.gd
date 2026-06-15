extends Node3D

## Playable scene: loads a GTA1 city, extrudes it, spawns a drivable car on a
## street, and follows it with a chase camera. This is the interactive entry
## point — open the project and press Play, then drive with the arrow keys / WASD.

const SEA_LEVEL := 0.85
const FLY_SPEED := 22.0
const FLY_BOOST := 3.5
const MOUSE_SENS := 0.004

# Chase camera framing (tuned for the ~1-unit-wide car): how far behind and above
# the car the camera sits, and where ahead/up it aims.
const CAM_DIST := 3.3
const CAM_HEIGHT := 1.5
const CAM_LOOK_AHEAD := 3.2
const CAM_LOOK_HEIGHT := 0.4

# Cycleable PSX-style cars (ggbot, CC0). [C] switches between them at runtime. The
# bodies model their own wheels, so the physics wheels stay invisible. PSX_YAW
# turns a body so its hood faces -Z (drive-forward); tuned to the pack's models.
# Each entry is a body mesh + a texture: colour/style variants reuse one mesh with
# a different skin. Car 06 (burnt-out) is reserved for explosions; Car 07 is
# excluded (not period appropriate).
const PSX_YAW := 180.0
const _C1 := "res://assets/vehicles/psx/car1/Car.obj"
const _C2 := "res://assets/vehicles/psx/car2/Car2.obj"
const _C3 := "res://assets/vehicles/psx/car3/Car3.obj"
const _C4 := "res://assets/vehicles/psx/car4/Car4.obj"
const _C8 := "res://assets/vehicles/psx/car8/Car8.obj"
# Per-model handling profiles, rated out of 10: [Speed, Acceleration, Braking,
# Handling]. Colour/style variants of a model share its profile.
const P1 := {"spd": 5.0, "acc": 5.0, "brk": 5.0, "hnd": 5.0}   # Car 01 wagon
const P2 := {"spd": 6.0, "acc": 6.0, "brk": 6.0, "hnd": 6.0}   # Car 02
const P3 := {"spd": 6.0, "acc": 7.0, "brk": 6.0, "hnd": 7.0}   # Car 03 (nippy)
const P4 := {"spd": 5.0, "acc": 5.0, "brk": 5.0, "hnd": 5.0}   # Car 04
const P5 := {"spd": 7.0, "acc": 7.0, "brk": 7.0, "hnd": 7.0}   # Car 05 taxi/police
const P8 := {"spd": 4.0, "acc": 4.0, "brk": 4.0, "hnd": 4.0}   # Car 08 van
const CAR_MODELS := [
	# Car 01 — wagon (4 colours)
	{"obj": _C1, "tex": "res://assets/vehicles/psx/car1/car.png", "prof": P1},
	{"obj": _C1, "tex": "res://assets/vehicles/psx/car1/car_blue.png", "prof": P1},
	{"obj": _C1, "tex": "res://assets/vehicles/psx/car1/car_gray.png", "prof": P1},
	{"obj": _C1, "tex": "res://assets/vehicles/psx/car1/car_red.png", "prof": P1},
	# Car 02 (3 colours)
	{"obj": _C2, "tex": "res://assets/vehicles/psx/car2/car2.png", "prof": P2},
	{"obj": _C2, "tex": "res://assets/vehicles/psx/car2/car2_black.png", "prof": P2},
	{"obj": _C2, "tex": "res://assets/vehicles/psx/car2/car2_red.png", "prof": P2},
	# Car 03 (3 colours)
	{"obj": _C3, "tex": "res://assets/vehicles/psx/car3/car3.png", "prof": P3},
	{"obj": _C3, "tex": "res://assets/vehicles/psx/car3/car3_red.png", "prof": P3},
	{"obj": _C3, "tex": "res://assets/vehicles/psx/car3/car3_yellow.png", "prof": P3},
	# Car 04 (4 colours)
	{"obj": _C4, "tex": "res://assets/vehicles/psx/car4/car4.png", "prof": P4},
	{"obj": _C4, "tex": "res://assets/vehicles/psx/car4/car4_grey.png", "prof": P4},
	{"obj": _C4, "tex": "res://assets/vehicles/psx/car4/car4_lightgrey.png", "prof": P4},
	{"obj": _C4, "tex": "res://assets/vehicles/psx/car4/car4_lightorange.png", "prof": P4},
	# Car 05 — taxi + police (2 styles, each its own body with a light bar)
	{"obj": "res://assets/vehicles/psx/car5/Car5_Taxi.obj", "tex": "res://assets/vehicles/psx/car5/car5_taxi.png", "prof": P5},
	{"obj": "res://assets/vehicles/psx/car5/Car5_Police.obj", "tex": "res://assets/vehicles/psx/car5/car5_police.png", "prof": P5},
	# Car 08 — van (4 colours)
	{"obj": _C8, "tex": "res://assets/vehicles/psx/car8/Car8.png", "prof": P8},
	{"obj": _C8, "tex": "res://assets/vehicles/psx/car8/Car8_grey.png", "prof": P8},
	{"obj": _C8, "tex": "res://assets/vehicles/psx/car8/Car8_mail.png", "prof": P8},
	{"obj": _C8, "tex": "res://assets/vehicles/psx/car8/Car8_purple.png", "prof": P8},
]

@export var city := "NYC"
@export_range(0.0, 1.0) var camera_smooth := 0.12

var car: Car
var _car_index := 0
var _cam: Camera3D
var _spawn_pos := Vector3.ZERO
var _spawn_basis := Basis.IDENTITY
var _hud: Label
var _coords: Label
var _fly := false
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	_add_drive_actions()

	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	if map == null:
		push_error("Place %s.CMP in res://data/ (see data/README.md)" % city)
		return
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)

	var city_mesh := MapBuilder.build(map, style)
	add_child(city_mesh)
	# Collision is the rendered mesh itself, so the car collides with exactly what it
	# sees (drives under untextured overpass decks, blocks on textured walls).
	add_child(MapBuilder.build_collision(city_mesh.mesh))

	var center := GTA1Map.DIM / 2.0
	var we := WorldEnvironment.new()
	we.environment = Scenery.make_environment()
	add_child(we)
	Scenery.add_sun(self)
	Scenery.add_ground(self, center, SEA_LEVEL)

	var spawn := SpawnFinder.find_drive_spawn_full(map)
	var spawn_cell: Vector2i = spawn["pos"]
	var spawn_dir: Vector2i = spawn["dir"]
	var surface_y := float(map.get_surface_y(spawn_cell.x, spawn_cell.y))
	var sx := spawn_cell.x + 0.5
	var sz := spawn_cell.y + 0.5

	# The city's concave collision shape takes a few frames to bake into the
	# physics server. Wait until a downward ray actually hits the road, and use
	# the exact hit height, so the car spawns right on the road.
	var floor_y := await _wait_for_floor(sx, sz)
	if floor_y == -INF:
		floor_y = surface_y

	_spawn_pos = Vector3(sx, floor_y + 0.15, sz)
	# Face the car down the road's long axis (Basis.looking_at points -Z, the
	# vehicle's forward, along the given direction).
	_spawn_basis = Basis.looking_at(Vector3(spawn_dir.x, 0, spawn_dir.y))
	_spawn_car(_car_index, Transform3D(_spawn_basis, _spawn_pos))

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 2000.0
	add_child(_cam)
	_cam.current = true
	_place_camera(1.0)

	_add_hud()


func _add_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = _make_label(Vector2(14, 10))
	layer.add_child(_hud)
	# Live map-cell readout, so a spot can be reported by its (X, Y) coordinates.
	_coords = _make_label(Vector2(14, 36))
	layer.add_child(_coords)
	add_child(layer)
	_update_hud()


func _make_label(pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	return lbl


## Show the current map cell (matches the X/Y used everywhere in the data). Uses
## the camera in fly mode, otherwise the car.
func _update_coords() -> void:
	if _coords == null:
		return
	var p: Vector3
	if _fly and _cam != null:
		p = _cam.global_position
	elif car != null:
		p = car.global_position
	else:
		return
	var cx := clampi(int(floor(p.x)), 0, GTA1Map.DIM - 1)
	var cy := clampi(int(floor(p.z)), 0, GTA1Map.DIM - 1)
	_coords.text = "cell  X %d   Y %d   ·   height %.1f" % [cx, cy, p.y]


func _update_hud() -> void:
	if _hud == null:
		return
	var car_hint := "  ·  [C] next car" if CAR_MODELS.size() > 1 else ""
	if _fly:
		_hud.text = "FLY  ·  WASD/arrows move  ·  Q/E down/up  ·  Shift boost  ·  mouse look  ·  [F] drive" + car_hint
	else:
		_hud.text = "DRIVE  ·  arrows / WASD  ·  [F] free-fly camera" + car_hint


func _physics_process(_delta: float) -> void:
	if car == null:
		return
	# Safety net: if the car ever ends up below the world, put it back on the
	# spawn (by which point collision is fully baked, so it stays).
	if car.global_position.y < -3.0:
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.global_transform = Transform3D(_spawn_basis, _spawn_pos)
	if _cam != null and not _fly:
		_place_camera(camera_smooth)


func _place_camera(weight: float) -> void:
	# Use only the car's heading (flattened to the ground), so a tilted/bouncing
	# car never throws the camera underground or upside down. The car drives along
	# -basis.z (Godot vehicle-forward), so the chase cam sits behind that.
	var fwd := -car.global_transform.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	flat = Vector3(0, 0, 1) if flat.length() < 0.05 else flat.normalized()

	var target := car.global_position - flat * CAM_DIST + Vector3(0, CAM_HEIGHT, 0)
	_cam.global_position = _cam.global_position.lerp(target, weight) if weight < 1.0 else target
	_cam.look_at(car.global_position + flat * CAM_LOOK_AHEAD + Vector3(0, CAM_LOOK_HEIGHT, 0), Vector3.UP)


# --- free-fly camera ---

func _process(delta: float) -> void:
	_update_coords()
	if not _fly or _cam == null:
		return
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	var b := _cam.global_transform.basis
	var dir := Vector3.ZERO
	dir -= b.z * Input.get_action_strength("ui_up")
	dir += b.z * Input.get_action_strength("ui_down")
	dir -= b.x * Input.get_action_strength("ui_left")
	dir += b.x * Input.get_action_strength("ui_right")
	if Input.is_physical_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		dir -= Vector3.UP
	if dir.length() > 0.0:
		var speed := FLY_SPEED * (FLY_BOOST if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		_cam.global_position += dir.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			_set_fly(not _fly)
		elif event.physical_keycode == KEY_C:
			_cycle_car()
	elif _fly and event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)


## (Re)build the car using model `idx`, placed at `xform`. Frees any existing car.
func _spawn_car(idx: int, xform: Transform3D) -> void:
	if car != null:
		car.queue_free()
	var spec: Dictionary = CAR_MODELS[idx]
	car = Car.new()
	car.model_path = spec["obj"]
	car.texture_path = spec["tex"]
	car.model_yaw_deg = PSX_YAW
	var prof: Dictionary = spec["prof"]
	car.speed_score = prof["spd"]
	car.accel_score = prof["acc"]
	car.brake_score = prof["brk"]
	car.handling_score = prof["hnd"]
	car.use_input = not _fly
	add_child(car)
	car.global_transform = xform


## Swap to the next car model, keeping the current spot — upright, nudged up a touch
## so it drops onto the road rather than inheriting a tumbling pose.
func _cycle_car() -> void:
	if CAR_MODELS.size() <= 1 or car == null:
		return
	var pos := car.global_position
	var fwd := -car.global_transform.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	flat = Vector3(0, 0, 1) if flat.length() < 0.05 else flat.normalized()
	_car_index = (_car_index + 1) % CAR_MODELS.size()
	_spawn_car(_car_index, Transform3D(Basis.looking_at(flat), pos + Vector3(0, 0.4, 0)))
	_update_hud()


func _set_fly(on: bool) -> void:
	_fly = on
	if car != null:
		car.use_input = not on
		car.control_throttle = 0.0
		car.control_steer = 0.0
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_yaw = _cam.rotation.y
		_pitch = _cam.rotation.x
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_hud()


## Wait (up to ~2s) until the city collision is queryable at (x,z); returns the
## floor height there, or -INF if none was found in time.
func _wait_for_floor(x: float, z: float) -> float:
	for _i in 120:
		await get_tree().physics_frame
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -40, z))
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit.position.y
	return -INF


## Add WASD as aliases for the default ui_* arrow actions, so both work.
func _add_drive_actions() -> void:
	var binds := {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D}
	for action: String in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = binds[action]
		InputMap.action_add_event(action, ev)
