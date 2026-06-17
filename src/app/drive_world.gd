extends Node3D

## Playable scene: loads a GTA1 city and extrudes it, then drops the player in ON
## FOOT next to a parked car. WASD + mouse-look to walk (Shift to run); [Enter] by a
## car gets in and hands control to the chase-cam driving; [Enter] again gets out.
## [F] is a free-fly debug camera; [C] cycles car models while driving.

const SEA_LEVEL := 0.85
const FLY_SPEED := 22.0
const FLY_BOOST := 3.5
const MOUSE_SENS := 0.004

# On-foot third-person camera: mouse orbits it around the walker. Distances are
# small (a person is ~0.6 tall), and an occlusion ray pulls it in past walls.
const PED_CAM_DIST := 1.1
const PED_PIVOT_H := 0.5          # aim point ~ the walker's head/shoulders
const PED_CAM_SMOOTH := 0.35
const PED_PITCH_MIN := -0.25      # rad; how far the camera can look up/down
const PED_PITCH_MAX := 1.30
# How close the walker must be to a car to get in.
const ENTER_RANGE := 1.4

# Driving into the river is fatal, but not instantly: the car bobs on the surface
# for a beat, then sinks slowly under for several seconds before it is lost and
# respawns — "briefly float, then sink, then water death", ~10s end to end. Times
# in seconds; buoyancy/drag are accelerations (×mass = N).
const FLOAT_TIME := 1.5          # bobbing on the surface before it goes under
const SINK_TIME := 9.0           # slow descent before the car is written off (~10s total)
const FLOAT_LINE_DROP := 0.12    # how far below the water surface the car floats
const FLOAT_SPRING := 15.0       # pull back to the float line (bob stiffness)
const FLOAT_DAMP := 6.0          # vertical bob damping
const SINK_SPEED := 0.2          # terminal sink speed (m/s) — a slow, heavy settle
const SINK_VY_GAIN := 3.0        # how quickly the descent eases to that sink speed
const WATER_DRAG := 2.2          # horizontal drag so a car in water doesn't keep sliding
const SINK_DEATH_Y := WaterBuilder.WATER_LEVEL - 30.0  # far backstop; the timer normally ends it

enum WaterState { DRY, FLOATING, SINKING }

# Chase camera framing (tuned for the ~1-unit-wide car): how far behind and above
# the car the camera sits, and where ahead/up it aims. The camera zooms with
# speed: pulled in tight when stationary, easing out to the FAR framing at the
# car's top speed (so fast driving shows more of the road ahead).
const CAM_DIST_NEAR := 1.8
const CAM_DIST_FAR := 3.3
const CAM_HEIGHT_NEAR := 1.0
const CAM_HEIGHT_FAR := 1.5
const CAM_LOOK_AHEAD_NEAR := 1.4
const CAM_LOOK_AHEAD_FAR := 3.2
const CAM_LOOK_HEIGHT := 0.4
const CAM_ZOOM_SMOOTH := 0.06   # how fast the zoom follows speed (kept slow to avoid pumping)

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
var _zoom := 0.0   # smoothed 0..1 speed-based camera zoom (0 = near, 1 = far)
var _spawn_pos := Vector3.ZERO
var _spawn_basis := Basis.IDENTITY
var _hud: Label
var _coords: Label
var _fly := false
var _yaw := 0.0
var _pitch := 0.0

var _ped: Pedestrian
var _on_foot := true   # the player starts as a pedestrian; false = sitting in the car
var _ped_spawn := Vector3.ZERO
var _pause: PauseMenu
var _traffic: TrafficManager
var _road_overlay: Node3D

var _map: GTA1Map
var _water_tile := -1
var _gravity := 9.8
var _water_state := WaterState.DRY
var _water_timer := 0.0
var _saved_mask := 1
var _water_cam_pos := Vector3.ZERO   # held camera spot while the car drowns


func _ready() -> void:
	_add_drive_actions()

	var map := GTA1Map.load_file("res://data/%s.CMP" % city)
	if map == null:
		push_error("Place %s.CMP in res://data/ (see data/README.md)" % city)
		return
	_map = map
	_water_tile = WaterBuilder.detect_water_tile(map)
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var style := GTA1Style.load_file("res://data/STYLE%03d.G24" % map.style_number)

	var city_mesh := MapBuilder.build(map, style)
	add_child(city_mesh)
	# Collision is the rendered mesh itself, so the car collides with exactly what it
	# sees (drives under untextured overpass decks, blocks on textured walls).
	add_child(MapBuilder.build_collision(city_mesh.mesh))
	# Animated water over the rivers/harbour (a thin skin on the riverbed tile; the
	# car's collision is unchanged). Detected by the water lid tile, so subways — which
	# also dip to z=0 — are left dry.
	add_child(WaterBuilder.build(map))

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
	_spawn_car(_car_index, Transform3D(_spawn_basis, _spawn_pos))   # parked; we start on foot

	# Spawn the player on foot beside the parked car, facing down the road.
	var perp := Vector3(spawn_dir.y, 0.0, -spawn_dir.x)
	perp = Vector3(1, 0, 0) if perp.length() < 0.1 else perp.normalized()
	_ped_spawn = Vector3(sx, floor_y + 0.1, sz) + perp * 0.8
	_ped = Pedestrian.new()
	add_child(_ped)
	_ped.global_position = _ped_spawn
	_yaw = atan2(-float(spawn_dir.x), -float(spawn_dir.y))

	# Road map. Traffic is being reworked (hybrid), so for now we don't spawn cars —
	# instead we draw the derived road network in-world as direction arrows (toggle [G])
	# so the map and its connectivity can be checked before driving is built on it.
	var road := RoadGraph.build(map)
	_road_overlay = road.build_arrow_overlay()
	add_child(_road_overlay)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 2000.0
	add_child(_cam)
	_cam.current = true
	_place_ped_camera(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_add_hud()

	# [Esc] pause menu (runs while the tree is paused). On resume it asks us to put
	# the mouse back the way the current mode wants it.
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.resumed.connect(_restore_mouse)


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
	elif _on_foot and _ped != null:
		p = _ped.global_position
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
	if _fly:
		_hud.text = "FLY  ·  WASD/arrows move  ·  Q/E down/up  ·  Shift boost  ·  [G] road map  ·  [F] back"
	elif _on_foot:
		_hud.text = "ON FOOT  ·  WASD move  ·  Shift run  ·  mouse look  ·  [Enter] get in car  ·  [F] fly  ·  [Esc] menu"
	else:
		var car_hint := "  ·  [C] next car" if CAR_MODELS.size() > 1 else ""
		_hud.text = "DRIVE  ·  arrows / WASD  ·  [Enter] get out  ·  [F] fly" + car_hint + "  ·  [Esc] menu"


func _physics_process(delta: float) -> void:
	if _fly:
		return   # the free-fly camera is driven in _process
	if _on_foot:
		_update_on_foot(delta)
	else:
		_update_in_car(delta)


# --- on foot ---

func _update_on_foot(delta: float) -> void:
	if _ped == null:
		return
	# WASD relative to where the camera is looking; Shift to run.
	var fwd_in := Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var side_in := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var wish := forward * fwd_in + right * side_in
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	_ped.move(delta, wish, running)
	# Safety net: if the walker somehow drops out of the world, put it back.
	if _ped.global_position.y < -3.0:
		_ped.velocity = Vector3.ZERO
		_ped.global_position = _ped_spawn
	if _cam != null:
		_place_ped_camera(PED_CAM_SMOOTH)


# --- in car ---

func _update_in_car(delta: float) -> void:
	if car == null:
		return
	# Safety net: if the car ever ends up below the world, put it back on the
	# spawn (by which point collision is fully baked, so it stays).
	if car.global_position.y < -3.0:
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.global_transform = Transform3D(_spawn_basis, _spawn_pos)
	_update_water(delta)
	if _cam != null:
		if _water_state == WaterState.DRY:
			_place_camera(camera_smooth)
		else:
			# Death cam: hold the camera up on the bank and watch the car go under,
			# rather than chasing it down through the riverbed.
			_cam.global_position = _cam.global_position.lerp(_water_cam_pos, 0.2)
			_cam.look_at(car.global_position, Vector3.UP)


# --- driving into the river: float, sink, then water death ---

## Run the water state machine each physics frame: catch the car when it drops into
## a river cell, hold it bobbing on the surface, then let it sink and write it off.
func _update_water(delta: float) -> void:
	match _water_state:
		WaterState.DRY:
			if _car_in_water():
				_enter_water()
		WaterState.FLOATING:
			_water_timer += delta
			# full buoyancy + a spring/damper holds the car bobbing at the waterline
			_apply_water_forces(_gravity, WaterBuilder.WATER_LEVEL - FLOAT_LINE_DROP, true)
			if _water_timer >= FLOAT_TIME:
				_water_state = WaterState.SINKING
				_water_timer = 0.0
				car.collision_mask = 0   # let the chassis slip under the riverbed
		WaterState.SINKING:
			_water_timer += delta
			# less-than-weight buoyancy: it eases under instead of dropping like a stone
			_apply_water_forces(_gravity, 0.0, false)
			if _water_timer >= SINK_TIME or car.global_position.y < SINK_DEATH_Y:
				_water_death()


## True when the car has actually dropped into the river: over a water cell AND down
## near the water surface (so a car crossing a bridge ABOVE the water is left alone).
func _car_in_water() -> bool:
	var p := car.global_position
	if p.y > WaterBuilder.WATER_LEVEL + 0.1:
		return false
	var cx := clampi(int(floor(p.x)), 0, GTA1Map.DIM - 1)
	var cy := clampi(int(floor(p.z)), 0, GTA1Map.DIM - 1)
	return WaterBuilder.is_water(_map, cx, cy, _water_tile)


func _enter_water() -> void:
	_water_state = WaterState.FLOATING
	_water_timer = 0.0
	_saved_mask = car.collision_mask
	# Lift the held death-cam a touch above wherever the chase cam was, for a clear
	# downward view of the car sinking.
	if _cam != null:
		_water_cam_pos = _cam.global_position + Vector3(0.0, 1.2, 0.0)
	# Hand control to the water: the dunk plays out to its end, no driving back out.
	car.use_input = false
	car.control_throttle = 0.0
	car.control_steer = 0.0
	car.control_brake = 0.0
	car.engine_force = 0.0
	car.brake = 0.0


## Buoyancy + drag. `floating` true: cancel gravity and spring/damp toward the
## waterline so it bobs. `floating` false: cancel gravity and ease the vertical
## speed down to a slow constant SINK_SPEED, so it eases under over several seconds
## instead of accelerating like a stone.
func _apply_water_forces(g: float, target_y: float, floating: bool) -> void:
	var vy := car.linear_velocity.y
	var fy := car.mass * g   # both phases first cancel gravity
	if floating:
		fy += car.mass * (FLOAT_SPRING * (target_y - car.global_position.y) - FLOAT_DAMP * vy)
	else:
		fy += car.mass * (-SINK_SPEED - vy) * SINK_VY_GAIN
	car.apply_central_force(Vector3(0.0, fy, 0.0))
	# bleed horizontal speed (water resistance) so it settles where it went in
	var hv := Vector3(car.linear_velocity.x, 0.0, car.linear_velocity.z)
	car.apply_central_force(-hv * car.mass * WATER_DRAG)


## The car is lost: reset it dry on the spawn (collision restored) and clear state.
func _water_death() -> void:
	car.collision_mask = _saved_mask
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.global_transform = Transform3D(_spawn_basis, _spawn_pos)
	car.use_input = not _fly
	_water_state = WaterState.DRY
	_water_timer = 0.0


func _place_camera(weight: float) -> void:
	# Use only the car's heading (flattened to the ground), so a tilted/bouncing
	# car never throws the camera underground or upside down. The car drives along
	# -basis.z (Godot vehicle-forward), so the chase cam sits behind that.
	var fwd := -car.global_transform.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	flat = Vector3(0, 0, 1) if flat.length() < 0.05 else flat.normalized()

	# Zoom with speed: ease the zoom factor toward the car's speed ratio (0 near,
	# 1 far) so it doesn't pump on every throttle blip.
	_zoom = lerpf(_zoom, car.speed_ratio(), CAM_ZOOM_SMOOTH)
	var dist := lerpf(CAM_DIST_NEAR, CAM_DIST_FAR, _zoom)
	var height := lerpf(CAM_HEIGHT_NEAR, CAM_HEIGHT_FAR, _zoom)
	var look_ahead := lerpf(CAM_LOOK_AHEAD_NEAR, CAM_LOOK_AHEAD_FAR, _zoom)

	# Pull the camera in if a building is between it and the car, so it never sees
	# through / sits inside walls. Ray from the car (at camera height) back to the
	# wanted spot; if it hits, place the camera just short of that wall.
	var pivot := car.global_position + Vector3(0, height, 0)
	var want := pivot - flat * dist
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(pivot, want)
		q.exclude = [car.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var d: float = clampf(pivot.distance_to(hit.position) - 0.25, 0.5, dist)
			want = pivot - flat * d

	_cam.global_position = _cam.global_position.lerp(want, weight) if weight < 1.0 else want
	_cam.look_at(car.global_position + flat * look_ahead + Vector3(0, CAM_LOOK_HEIGHT, 0), Vector3.UP)


## Mouse-look third-person camera: orbit the walker at (_yaw, _pitch), pulling in
## past any wall between the camera and the walker so it never clips inside geometry.
func _place_ped_camera(weight: float) -> void:
	var pivot := _ped.global_position + Vector3(0, PED_PIVOT_H, 0)
	var back := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var dist := PED_CAM_DIST
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(pivot, pivot + back * dist)
		q.exclude = [_ped.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			dist = clampf(pivot.distance_to(hit.position) - 0.12, 0.4, dist)
	var want := pivot + back * dist
	_cam.global_position = _cam.global_position.lerp(want, weight) if weight < 1.0 else want
	_cam.look_at(pivot, Vector3.UP)


# --- getting in and out of the car ---

## Enter the parked car if the walker is close enough; otherwise do nothing.
func _try_enter_car() -> void:
	if car == null or _ped == null:
		return
	if _ped.global_position.distance_to(car.global_position) > ENTER_RANGE:
		return
	_on_foot = false
	_ped.set_active(false)             # park the walker out of the way
	car.use_input = not _fly
	_zoom = 0.0
	_place_camera(1.0)                 # snap the chase cam onto the car
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_hud()


## Step out of the car: drop the walker beside the driver's door and take control.
func _exit_car() -> void:
	if car == null or _ped == null:
		return
	_on_foot = true
	car.use_input = false
	car.control_throttle = 0.0
	car.control_steer = 0.0
	# Driver side = the car's left (-X of its basis); nudge up so it settles down.
	var door := car.global_position - car.global_transform.basis.x * 0.7 + Vector3(0, 0.1, 0)
	_ped.set_active(true)
	_ped.global_position = door
	# Look down the car's heading so you carry on facing the way you drove.
	var f := -car.global_transform.basis.z
	_yaw = atan2(-f.x, -f.z)
	_pitch = 0.3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()


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
		elif event.physical_keycode == KEY_G:
			if _road_overlay != null:
				_road_overlay.visible = not _road_overlay.visible
		elif event.physical_keycode == KEY_C:
			_cycle_car()
		elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			if not _fly:
				if _on_foot:
					_try_enter_car()
				else:
					_exit_car()
	elif event is InputEventMouseMotion and (_fly or _on_foot):
		_yaw -= event.relative.x * MOUSE_SENS
		var lo := -1.4 if _fly else PED_PITCH_MIN
		var hi := 1.4 if _fly else PED_PITCH_MAX
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, lo, hi)


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
	car.use_input = (not _fly) and (not _on_foot)
	add_child(car)
	car.global_transform = xform
	# A fresh car is dry, even if the old one was mid-dunk when swapped.
	_water_state = WaterState.DRY
	_water_timer = 0.0


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
		car.use_input = (not on) and (not _on_foot)
		car.control_throttle = 0.0
		car.control_steer = 0.0
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_yaw = _cam.rotation.y
		_pitch = _cam.rotation.x
	else:
		# Back to the previous mode: on foot keeps mouse-look captured, the car frees it.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _on_foot else Input.MOUSE_MODE_VISIBLE
	_update_hud()


## Put the mouse back the way the current mode wants it (used after the pause menu
## closes): captured for mouse-look on foot or in fly, free while driving.
func _restore_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (_on_foot or _fly) else Input.MOUSE_MODE_VISIBLE


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
