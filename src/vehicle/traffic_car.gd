class_name TrafficCar
extends AnimatableBody3D

## An ambient traffic car: a kinematic body that drives the RoadGraph, the way GTA1's
## ambient cars wandered the streets — it keeps going STRAIGHT down a road and only
## turns at a genuine junction or dead end. (Turning at random instead traps cars
## orbiting tiny loops on wide multi-cell roads.) It's an AnimatableBody3D so the
## player's RigidBody car collides with and can shunt it, while staying cheap and
## stable at fleet scale.
##
## Two transform quirks of a physics-managed body, both worked around here:
##  * we keep our own authoritative _pos (the global_position getter lags our writes
##    by a frame once physics is live, so the car would crawl off from the origin);
##  * we face travel by rotating the MODEL child, not the body (setting the body's
##    rotation doesn't stick — it reads back as 0).
##
## The path logic lives in tick(delta) so a test can step it deterministically.

const SPEED := 3.2            # units/s cruise
const TURN_RATE := 9.0        # rad/s the model swings to face travel
const LANE_OFFSET := 0.26     # right of the cell centre-line (right-hand drive)
const ARRIVE := 0.12          # distance at which the target cell counts as reached
const STRAIGHT_BIAS := 0.9    # chance of going straight on at a junction (high, so cars
                              # commit to a street instead of weaving across wide roads)
const TARGET_WIDTH := 0.5     # match Car: scale the model to ~half a cell wide
const Y_LERP := 8.0           # how fast height eases onto ramps/steps

@export var model_path := "res://assets/vehicles/psx/car2/Car2.obj"
@export var texture_path := ""
## Set false in tests to step tick() by hand instead of from the physics loop.
@export var auto := true

var graph: RoadGraph
var start_cell := Vector2i.ZERO

var _cell: Vector2i           # cell we're driving away from
var _heading := Vector2i(1, 0)
var _target: Vector2i         # cell we're driving toward (_cell + _heading)
var _yaw := 0.0
var _pos := Vector3.ZERO       # authoritative position (see class note)
var _model: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build_model()
	_build_collision()
	if graph == null or not graph.nodes.has(start_cell):
		return
	_cell = start_cell
	_heading = _initial_heading()
	_target = _cell + _heading
	_pos = _node_pos(_cell)
	global_position = _pos
	var dir := _world_dir()
	_yaw = atan2(dir.x, dir.z)
	if _model != null:
		_model.rotation.y = _yaw


func _physics_process(delta: float) -> void:
	if auto:
		tick(delta)


## Advance one step along the road. Public so tests can drive it directly.
func tick(delta: float) -> void:
	if graph == null or not graph.nodes.has(_cell):
		return
	var wp := _waypoint()
	var flat := Vector3(wp.x - _pos.x, 0.0, wp.z - _pos.z)
	var dist := flat.length()

	if dist < ARRIVE:
		_advance()
		wp = _waypoint()
		flat = Vector3(wp.x - _pos.x, 0.0, wp.z - _pos.z)
		dist = flat.length()

	if dist > 0.001:
		var dir := flat / dist
		_pos += dir * minf(SPEED * delta, dist)
		var target_yaw := atan2(dir.x, dir.z)
		_yaw = lerp_angle(_yaw, target_yaw, clampf(TURN_RATE * delta, 0.0, 1.0))
		if _model != null:
			_model.rotation.y = _yaw
	_pos.y = lerpf(_pos.y, wp.y, clampf(Y_LERP * delta, 0.0, 1.0))
	global_position = _pos


## Reached _target: step onto it and choose where to head next.
func _advance() -> void:
	_cell = _target
	_heading = _choose_heading()
	_target = _cell + _heading


## Prefer to keep the current heading; otherwise pick among the turns available at
## this cell (never reversing unless it's a dead end).
func _choose_heading() -> Vector2i:
	var links: Array = (graph.nodes[_cell] as Dictionary).links
	var avail: Array[Vector2i] = []
	for nb: Vector2i in links:
		var d := nb - _cell
		if d == -_heading:
			continue                       # don't U-turn
		avail.append(d)
	if avail.is_empty():
		return -_heading                   # dead end: turn back
	if avail.has(_heading) and _rng.randf() < STRAIGHT_BIAS:
		return _heading
	return avail[_rng.randi() % avail.size()]


func _initial_heading() -> Vector2i:
	var links: Array = (graph.nodes[_cell] as Dictionary).links
	if links.is_empty():
		return Vector2i(1, 0)
	var nb: Vector2i = links[_rng.randi() % links.size()]
	return nb - _cell


## World point this car steers for: the target cell centre, nudged into the right lane.
func _waypoint() -> Vector3:
	var t: Vector3 = _node_pos(_target) if graph.nodes.has(_target) else _node_pos(_cell)
	var dir := _world_dir()
	var right := Vector3(dir.z, 0.0, -dir.x)   # right-hand side of travel
	return t + right * LANE_OFFSET


func _world_dir() -> Vector3:
	var d := Vector3(_heading.x, 0.0, _heading.y)
	return d.normalized() if d.length() > 0.001 else Vector3(0, 0, 1)


func _node_pos(cell: Vector2i) -> Vector3:
	return (graph.nodes[cell] as Dictionary).pos


func _build_collision() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.4, 1.0)
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, 0.2, 0)
	add_child(cs)


func _build_model() -> void:
	var res := load(model_path)
	var body: MeshInstance3D = null
	if res is Mesh:
		body = MeshInstance3D.new()
		body.mesh = res
	elif res is PackedScene:
		var src := (res as PackedScene).instantiate()
		body = _first_mesh(src)
		if body != null and body.get_parent() != null:
			body.owner = null
			body.get_parent().remove_child(body)
	if body == null or body.mesh == null:
		push_error("TrafficCar: no usable mesh in %s" % model_path)
		return
	var native: AABB = body.mesh.get_aabb()
	var horiz := minf(native.size.x, native.size.z)
	var s := clampf(TARGET_WIDTH / maxf(horiz, 0.01), 0.1, 4.0)
	body.scale = Vector3(s, s, s)
	body.position = Vector3(0, -native.position.y * s, 0)   # wheels on the body origin
	if texture_path != "":
		var tex := load(texture_path) as Texture2D
		if tex != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.roughness = 1.0
			body.material_override = mat
	add_child(body)
	_model = body


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null
