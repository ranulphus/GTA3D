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
const CAM_DIST := 4.2
const CAM_HEIGHT := 1.9
const CAM_LOOK_AHEAD := 4.0
const CAM_LOOK_HEIGHT := 0.6

@export var city := "NYC"
@export_range(0.0, 1.0) var camera_smooth := 0.12

var car: Car
var _cam: Camera3D
var _spawn_pos := Vector3.ZERO
var _spawn_basis := Basis.IDENTITY
var _hud: Label
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
	add_child(MapBuilder.build_heightfield_collision(map))

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

	car = Car.new()
	add_child(car)
	_spawn_pos = Vector3(sx, floor_y + 0.15, sz)
	# Face the car down the road's long axis (Basis.looking_at points -Z, the
	# vehicle's forward, along the given direction).
	_spawn_basis = Basis.looking_at(Vector3(spawn_dir.x, 0, spawn_dir.y))
	car.global_transform = Transform3D(_spawn_basis, _spawn_pos)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 2000.0
	add_child(_cam)
	_cam.current = true
	_place_camera(1.0)

	_add_hud()


func _add_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	add_child(layer)
	_update_hud()


func _update_hud() -> void:
	if _hud == null:
		return
	if _fly:
		_hud.text = "FLY  ·  WASD/arrows move  ·  Q/E down/up  ·  Shift boost  ·  mouse look  ·  [F] drive"
	else:
		_hud.text = "DRIVE  ·  arrows / WASD  ·  [F] free-fly camera"


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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		_set_fly(not _fly)
	elif _fly and event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)


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
