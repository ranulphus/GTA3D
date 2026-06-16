class_name Pedestrian
extends CharacterBody3D

## The on-foot player: a CharacterBody3D wearing the male_casual model. Walks/runs
## with gravity over the city's collision, climbing kerbs and ramps, and faces the
## way it's moving. The controller (drive_world) feeds it a world-space wish
## direction + run flag each physics frame via move(); the body owns the physics.
##
## The model is rigged but ships no animation clips, so for now it slides (like the
## cars do) — a walk cycle can be added later by handing the FBX an AnimationPlayer.

const MODEL_PATH := "res://assets/characters/male_casual.fbx"
const TEXTURE_PATH := "res://assets/characters/man_tex.png"

## Human scale on the 1-unit grid (a car is ~0.5 wide): about half a cell tall.
const HEIGHT := 0.58
const RADIUS := 0.13
const WALK_SPEED := 1.7        # units/s
const RUN_SPEED := 3.9
const ACCEL := 16.0            # how fast it reaches walk/run speed
const TURN_RATE := 16.0        # rad/s the model swings to face travel
## Yaw (deg) so the model's front lines up with its travel direction. Tuned visually.
const MODEL_YAW_DEG := 180.0

var _model: Node3D
var _face_yaw := 0.0
var _gravity := 9.8


func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position = Vector3(0, HEIGHT * 0.5, 0)   # capsule base at the body origin (feet)
	add_child(cs)
	floor_max_angle = deg_to_rad(60.0)          # walk up the steeper ramps
	floor_snap_length = 0.35                     # stick to stairs/kerbs going down
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	_build_model()


func _build_model() -> void:
	var res := load(MODEL_PATH)
	if res == null:
		push_error("Pedestrian: cannot load %s" % MODEL_PATH)
		return
	_model = (res as PackedScene).instantiate()
	add_child(_model)
	var mi := _first_mesh(_model)
	if mi == null:
		return
	# Scale by the model's native height so it stands HEIGHT tall, and drop it so its
	# feet sit on the body origin (the capsule base).
	var aabb: AABB = mi.mesh.get_aabb()
	var s := HEIGHT / maxf(aabb.size.y, 0.01)
	_model.scale = Vector3(s, s, s)
	_model.position.y = -aabb.position.y * s
	_model.rotation.y = deg_to_rad(MODEL_YAW_DEG)
	var tex := load(TEXTURE_PATH) as Texture2D
	if tex != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 1.0
		mat.metallic = 0.0
		mi.material_override = mat


## Advance one physics step toward `wish_dir` (a world-space horizontal direction,
## length 0..1). Called by the controller while the player is on foot.
func move(delta: float, wish_dir: Vector3, running: bool) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var flat := Vector3(wish_dir.x, 0.0, wish_dir.z).limit_length(1.0)
	var desired := flat * (RUN_SPEED if running else WALK_SPEED)
	velocity.x = move_toward(velocity.x, desired.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, desired.z, ACCEL * delta)
	move_and_slide()

	# Face the way we're actually travelling (smoothed).
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > 0.2 and _model != null:
		var target := atan2(hv.x, hv.z)
		_face_yaw = lerp_angle(_face_yaw, target, clampf(TURN_RATE * delta, 0.0, 1.0))
		_model.rotation.y = _face_yaw + deg_to_rad(MODEL_YAW_DEG)


## Current horizontal speed as a fraction of run speed (for camera / HUD).
func speed_ratio() -> float:
	return clampf(Vector3(velocity.x, 0.0, velocity.z).length() / RUN_SPEED, 0.0, 1.0)


## Show/hide and enable/disable the body — used to park the player while they drive.
func set_active(on: bool) -> void:
	visible = on
	velocity = Vector3.ZERO
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not on


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null
