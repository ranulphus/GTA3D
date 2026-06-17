class_name TrafficDriver
extends Car

## An ambient traffic car with an AI at the wheel. It IS the player's Car — same
## VehicleBody3D physics (engine, brakes, grip, self-righting) — but instead of the
## keyboard it reads the RoadGraph. It plans a short path along the streets, steers
## toward a point a little way ahead (pure pursuit, so it tracks smoothly instead of
## sawing at the wheel), eases off the throttle BEFORE a corner like a real driver,
## and brakes for the car in front. Knocked off the road, it heads back to it.
##
## Two city-driving tweaks over the player's car:
##  * a much tighter steering lock — GTA1 streets are ~1 cell wide, and a road-car
##    turning circle (radius ~1/(lock*YAW_GAIN)) simply can't round a corner that
##    sharp; the AI cars get a near-90-degree lock so they can;
##  * they may use the flush ground beside the road (the wider corridor) to corner.

const CRUISE := 6.0           # target cruising speed (m/s); well below the car's top
const CORNER_SPEED := 3.6     # speed to take a turn at
const CORNER_LOOK := 2        # cells ahead to start watching for a corner (small, or the
                              # dense grid sees a turn everywhere and the cars never cruise)
## Wheel lock (rad). Too tight (>~45 deg) and the front wheels scrub sideways instead
## of rolling and the car can't move; ~37 deg rolls fine and, with the wider corridor
## for the cornering arc, rounds a city corner. The kinematic yaw assist does the rest.
const STEER_LOCK_AI := 0.65
const STEER_FULL := 0.5       # heading error (rad) that calls for full steering lock
const ARRIVE := 0.6           # distance (cells) at which a path cell is "passed"
const PATH_LEN := 6           # cells of route planned ahead
const STRAIGHT_BIAS := 0.9    # chance of carrying straight on through a junction
const SENSE_AHEAD := 1.7      # forward clearance (m) to keep from the car ahead
const RECOVER_RADIUS := 12    # rings to search for road when knocked off it
const STUCK_SPEED := 0.5
const STUCK_TIME := 2.2
const REVERSE_TIME := 0.7
const RESPAWN_TIME := 5.0      # seconds lost (off-road / wedged) before we re-place it

var graph: RoadGraph
var start_cell := Vector2i.ZERO

var _path: Array[Vector2i] = []
var _stuck := 0.0
var _reverse := 0.0
var _lost := 0.0
var _want_turn := 0.0          # last heading error toward the target (for the pivot assist)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	speed_score = 4.0
	accel_score = 5.0
	brake_score = 6.0
	handling_score = 7.0
	super._ready()
	use_input = false
	_steer_lock = STEER_LOCK_AI   # override Car's road-car lock for tight city turns


func _physics_process(delta: float) -> void:
	_drive(delta)
	super._physics_process(delta)   # run the Car physics with the controls we just set
	# The Car's steering is kinematic (yaw rate scales with speed), so a stopped car
	# can't turn — it would wedge facing the wrong way forever. Give AI cars a low-speed
	# pivot so they can reorient toward their target and drive off. Runs after Car so it
	# overrides only the yaw it set, keeping its roll/pitch self-righting.
	var spd := linear_velocity.dot(-global_transform.basis.z)
	if _reverse <= 0.0 and absf(spd) < 1.5 and absf(_want_turn) > 0.25:
		var av := angular_velocity
		av.y = clampf(_want_turn * 3.0, -2.5, 2.5)
		angular_velocity = av


func _drive(delta: float) -> void:
	if graph == null:
		return
	var pos := global_position
	var fwd := -global_transform.basis.z
	var flat_fwd := Vector3(fwd.x, 0.0, fwd.z)
	flat_fwd = flat_fwd.normalized() if flat_fwd.length() > 0.01 else Vector3(0, 0, 1)
	var cell := Vector2i(int(floor(pos.x)), int(floor(pos.z)))
	var speed := linear_velocity.dot(fwd)
	var here := Vector2(pos.x, pos.z)

	# Liveness net: a car that's fallen off the road or stayed wedged for a while (and
	# isn't simply queuing behind another car) is re-placed on the nearest road, so the
	# fleet never silently dies in a ditch.
	if not graph.is_drivable(cell) or _reverse > 0.0:
		_lost += delta
	else:
		_lost = maxf(0.0, _lost - delta * 2.0)
	if _lost > RESPAWN_TIME:
		_respawn()
		return

	var target := Vector2.ZERO
	var target_speed := CRUISE
	if not graph.is_drivable(cell):
		# Knocked off the drivable surface: make for the nearest road cell.
		_path.clear()
		var nn := _nearest_road(cell)
		target = _cell_center(nn) if nn.x >= 0 else here + Vector2(flat_fwd.x, flat_fwd.z)
	else:
		_advance_path(here)
		_extend_path(cell, flat_fwd)
		# Aim a little way ahead so the line is smooth; reach further when close in.
		var ai := 1
		if _path.size() > 2 and here.distance_to(_cell_center(_path[1])) < 1.2:
			ai = 2
		target = _cell_center(_path[mini(ai, _path.size() - 1)])
		target_speed = _corner_speed()

	# Steering: signed heading error toward the target (left is positive, which Car
	# steers with control_steer > 0).
	var to := Vector3(target.x - pos.x, 0.0, target.y - pos.z)
	var ang := 0.0
	if to.length() > 0.05:
		ang = flat_fwd.signed_angle_to(to.normalized(), Vector3.UP)
	control_steer = clampf(ang / STEER_FULL, -1.0, 1.0)
	_want_turn = ang   # remembered for the low-speed pivot assist

	# Hold back for the car in front so traffic queues instead of rear-ending.
	if _clear_ahead() < SENSE_AHEAD:
		target_speed = 0.0

	if speed < target_speed - 0.5:
		control_throttle = 1.0
		control_brake = 0.0
	elif speed > target_speed + 0.5:
		control_throttle = 0.0
		control_brake = 1.0 if target_speed == 0.0 else 0.5
	else:
		control_throttle = 0.2 if target_speed > 0.0 else 0.0
		control_brake = 0.0 if target_speed > 0.0 else 0.8

	# Wedged? Back straight up for a moment, then try the route again.
	if absf(speed) < STUCK_SPEED and target_speed > 0.0:
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck > STUCK_TIME and _reverse <= 0.0:
		_reverse = REVERSE_TIME
		_stuck = 0.0
	if _reverse > 0.0:
		_reverse -= delta
		control_throttle = -1.0
		control_brake = 0.0
		control_steer = 0.0


## Drop path cells we've drawn level with / passed, so _path[0] is the cell ahead.
func _advance_path(here: Vector2) -> void:
	while _path.size() >= 2:
		var d0 := here.distance_to(_cell_center(_path[0]))
		var d1 := here.distance_to(_cell_center(_path[1]))
		if d0 < ARRIVE or d1 <= d0:
			_path.pop_front()
		else:
			break


## Refill the planned route up to PATH_LEN, carrying straight on where possible. The
## path is always road cells (the car may sit on the verge between them), so we anchor
## an empty path to the nearest road cell rather than the car's raw cell.
func _extend_path(cell: Vector2i, flat_fwd: Vector3) -> void:
	if _path.is_empty():
		var rc := _nearest_road(cell)
		if rc.x < 0:
			return
		_path.append(rc)
	if _path.size() == 1:
		var seed := _pick_from(_path[0], flat_fwd)
		if seed != _path[0]:
			_path.append(seed)
	while _path.size() < PATH_LEN and _path.size() >= 2:
		var nxt := _pick_next(_path[-1], _path[-2])
		if nxt == _path[-1]:
			break
		_path.append(nxt)


## Cruise, but ease down to corner speed as a turn in the planned path approaches.
func _corner_speed() -> float:
	var n := _path.size()
	for i in range(mini(CORNER_LOOK, n - 2)):
		var a := _path[i + 1] - _path[i]
		var b := _path[i + 2] - _path[i + 1]
		if a != b:                       # a direction change = a corner i+1 cells ahead
			return lerpf(CORNER_SPEED, CRUISE, clampf(float(i) / 2.0, 0.0, 1.0))
	return CRUISE


## Choose the link best aligned with our current motion (to (re)anchor a route).
func _pick_from(cell: Vector2i, flat_fwd: Vector3) -> Vector2i:
	if not graph.nodes.has(cell):
		return cell
	var links: Array = (graph.nodes[cell] as Dictionary).links
	if links.is_empty():
		return cell
	var best: Vector2i = links[0]
	var best_dot := -2.0
	for nb: Vector2i in links:
		var d := Vector3(nb.x - cell.x, 0.0, nb.y - cell.y).normalized()
		var dot := d.dot(flat_fwd)
		if dot > best_dot:
			best_dot = dot
			best = nb
	return best


## Heading-preserving turn choice: carry straight on if we can, else take a turn,
## never U-turning unless it's a dead end.
func _pick_next(cell: Vector2i, prev: Vector2i) -> Vector2i:
	if not graph.nodes.has(cell):
		return cell
	var links: Array = (graph.nodes[cell] as Dictionary).links
	if links.is_empty():
		return cell
	var heading := cell - prev
	var avail: Array[Vector2i] = []
	for nb: Vector2i in links:
		if links.size() > 1 and nb - cell == -heading:
			continue
		avail.append(nb)
	if avail.is_empty():
		avail = links
	var straight := cell + heading
	if heading != Vector2i.ZERO and avail.has(straight) and _rng.randf() < STRAIGHT_BIAS:
		return straight
	return avail[_rng.randi() % avail.size()]


## Nearest road cell to `cell` within RECOVER_RADIUS (ring search), or (-1,-1).
func _nearest_road(cell: Vector2i) -> Vector2i:
	if graph.is_road(cell):
		return cell
	for r in range(1, RECOVER_RADIUS + 1):
		var best := Vector2i(-1, -1)
		var best_d := 1e9
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if graph.is_road(c):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Distance to the nearest CAR straight ahead, or a large number if none is in range.
## Only cars count — walls are the steering's job; treating them as obstacles would
## freeze traffic against the kerbs of the narrow streets.
func _clear_ahead() -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return 1e9
	var fwd := -global_transform.basis.z
	var from := global_position + Vector3(0, 0.2, 0) + fwd * 0.55
	var to := from + fwd * SENSE_AHEAD
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not (hit.collider is Car):
		return 1e9
	return from.distance_to(hit.position)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5)


## Put the car back on the road — the nearest road cell if there is one close (so a
## car that slid off a bank pops back where it left), else a random one.
func _respawn() -> void:
	var cell := Vector2i(int(floor(global_position.x)), int(floor(global_position.z)))
	var c := _nearest_road(cell)
	if c.x < 0:
		var keys: Array = graph.nodes.keys()
		if keys.is_empty():
			return
		c = keys[_rng.randi() % keys.size()]
	var node: Dictionary = graph.nodes[c]
	var links: Array = node.links
	var dir := Vector3(0, 0, 1)
	if not links.is_empty():
		var nb: Vector2i = links[_rng.randi() % links.size()]
		var d := Vector3(nb.x - c.x, 0.0, nb.y - c.y)
		if d.length() > 0.01:
			dir = d.normalized()
	global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), node.pos + Vector3(0, 0.4, 0))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_path.clear()
	_lost = 0.0
	_stuck = 0.0
	_reverse = 0.0
