class_name TrafficCar
extends AnimatableBody3D

## An ambient traffic car: a kinematic body that follows the RoadGraph centre-line
## network, hugging the right-hand lane and taking a (non-reversing) turn at each
## junction — the way GTA1's ambient cars wandered the streets. It's an
## AnimatableBody3D with sync_to_physics so the player's RigidBody car collides with
## it and can shunt it, while it stays cheap and stable at fleet scale (no per-car
## vehicle physics).
##
## The path logic lives in tick(delta) so it can be stepped deterministically from a
## test; in game _physics_process drives it. Reuses the PSX car .obj meshes.

const SPEED := 3.2            # units/s cruise
const TURN_RATE := 7.0        # rad/s the body swings to face travel
const LANE_OFFSET := 0.22     # right of the centre-line (right-hand drive)
const ARRIVE := 0.10          # distance at which a waypoint counts as reached
const TARGET_WIDTH := 0.5     # match Car: scale the model to ~half a cell wide
const Y_LERP := 8.0           # how fast height eases onto ramps/steps

@export var model_path := "res://assets/vehicles/psx/car2/Car2.obj"
@export var texture_path := ""
## Set false in tests to step tick() by hand instead of from the physics loop.
@export var auto := true

var graph: RoadGraph
var start_cell := Vector2i.ZERO

var _cell: Vector2i
var _prev: Vector2i
var _next: Vector2i
var _yaw := 0.0
## Authoritative position. We never read it back from global_position: this body's
## transform is physics-managed, so once the physics server is live the getter lags
## our writes by a frame and the car would crawl away from the origin.
var _pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Driven kinematically: we set global_position every physics frame. An
	# AnimatableBody3D moved this way still collides with and shoves the player's
	# RigidBody car (moving-platform behaviour). We deliberately leave sync_to_physics
	# off — with it on, the physics-body transform doesn't track our direct writes and
	# the car's visible position drifts away from its logical lane position.
	_build_model()
	_build_collision()
	_cell = start_cell
	_prev = start_cell
	_pick_next()
	_pos = _node_pos(_cell)
	global_position = _pos
	# Face the first leg immediately so it doesn't spin on spawn.
	var f := Vector3(_waypoint().x - _pos.x, 0.0, _waypoint().z - _pos.z)
	if f.length() > 0.01:
		_yaw = atan2(f.x, f.z)
		rotation.y = _yaw


func _physics_process(delta: float) -> void:
	if auto:
		tick(delta)


## Advance one step along the lane. Public so tests can drive it directly.
func tick(delta: float) -> void:
	if graph == null or not graph.nodes.has(_cell):
		return
	var wp := _waypoint()
	var flat := Vector3(wp.x - _pos.x, 0.0, wp.z - _pos.z)
	var dist := flat.length()

	if dist < ARRIVE:
		_prev = _cell
		_cell = _next
		_pick_next()
		wp = _waypoint()
		flat = Vector3(wp.x - _pos.x, 0.0, wp.z - _pos.z)
		dist = flat.length()

	if dist > 0.001:
		var dir := flat / dist
		_pos += dir * minf(SPEED * delta, dist)
		var target_yaw := atan2(dir.x, dir.z)
		_yaw = lerp_angle(_yaw, target_yaw, clampf(TURN_RATE * delta, 0.0, 1.0))
		rotation.y = _yaw
	_pos.y = lerpf(_pos.y, wp.y, clampf(Y_LERP * delta, 0.0, 1.0))
	global_position = _pos


## World point this car is steering for: the next node, nudged into the right lane.
func _waypoint() -> Vector3:
	var a := _node_pos(_cell)
	var b := _node_pos(_next)
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if dir.length() < 0.001:
		return b
	dir = dir.normalized()
	var right := Vector3(dir.z, 0.0, -dir.x)   # right-hand side of travel
	return b + right * LANE_OFFSET


func _node_pos(cell: Vector2i) -> Vector3:
	return (graph.nodes[cell] as Dictionary).pos


## Choose the next cell: any link except the one we came from (no instant U-turn);
## at a dead end, turning back is allowed.
func _pick_next() -> void:
	var links: Array = (graph.nodes[_cell] as Dictionary).links
	var opts: Array = links.filter(func(c: Vector2i) -> bool: return c != _prev)
	if opts.is_empty():
		opts = links
	if opts.is_empty():
		_next = _cell
		return
	_next = opts[_rng.randi() % opts.size()]


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


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null
