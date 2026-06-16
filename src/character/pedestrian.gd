class_name Pedestrian
extends CharacterBody3D

## The on-foot player: a CharacterBody3D wearing the male_casual model, which the
## player ran through Mixamo for Idle / Walking / Running clips. Walks/runs with
## gravity over the city collision (climbing kerbs and ramps), faces its travel
## direction, and plays the right clip for its speed. The controller (drive_world)
## feeds it a world-space wish direction + run flag each physics frame via move();
## the body owns the physics and animation.
##
## The three Mixamo exports share one skeleton, so we use Walking.fbx as the model
## (mesh + skin + rig) and graft Idle/Running's clips onto its AnimationPlayer.

const MODEL_PATH := "res://assets/characters/player/Walking.fbx"
const IDLE_PATH := "res://assets/characters/player/Idle.fbx"
const RUN_PATH := "res://assets/characters/player/Running.fbx"

## Human scale on the 1-unit grid (a car is ~0.5 wide): about half a cell tall.
const HEIGHT := 0.58
const RADIUS := 0.13
const WALK_SPEED := 0.85       # units/s
const RUN_SPEED := 1.95
const ACCEL := 12.0            # how fast it reaches walk/run speed
const TURN_RATE := 16.0        # rad/s the model swings to face travel
## Yaw (deg) so the model's front lines up with its travel direction. The Mixamo
## rig faces +Z, the opposite of the model's travel basis, so no extra turn (0) puts
## its front along the way it walks.
const MODEL_YAW_DEG := 0.0
## Speed (units/s) above which the run clip plays instead of walk.
const RUN_THRESHOLD := 1.35
## Play the clips at their natural cadence regardless of the (deliberately slow)
## ground speed. Matching playback to the halved speed made the legs crawl in slow
## motion; a touch of foot-slide is the accepted trade for a natural-looking stride.
## Tuned to how the walk/run looked before the ground speed was halved.
const WALK_ANIM_SCALE := 1.1
const RUN_ANIM_SCALE := 1.05

var _model: Node3D
var _anim: AnimationPlayer
var _face_yaw := 0.0
var _gravity := 9.8
var _cur_clip := ""


func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position = Vector3(0, HEIGHT * 0.5, 0)   # capsule base at the body origin (feet)
	add_child(cs)
	floor_max_angle = deg_to_rad(60.0)          # walk up the steeper ramps
	floor_snap_length = 0.35
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
	if mi != null:
		var aabb: AABB = mi.mesh.get_aabb()
		var s := HEIGHT / maxf(aabb.size.y, 0.01)
		_model.scale = Vector3(s, s, s)
		_model.position.y = -aabb.position.y * s   # feet on the body origin
	_model.rotation.y = deg_to_rad(MODEL_YAW_DEG)

	# Graft Idle/Walking/Running (each a separate Mixamo FBX, same skeleton) into one
	# library on the model's own AnimationPlayer, under clean names.
	_anim = _find_anim(_model)
	if _anim != null:
		var lib := AnimationLibrary.new()
		_add_clip(lib, "walk", MODEL_PATH)
		_add_clip(lib, "idle", IDLE_PATH)
		_add_clip(lib, "run", RUN_PATH)
		if _anim.has_animation_library("ped"):
			_anim.remove_animation_library("ped")
		_anim.add_animation_library("ped", lib)
		_play("ped/idle")


## Pull the single Mixamo clip out of `path` and add it to `lib` under `name`, set to
## loop. Duplicated so it's independent of the throwaway source scene.
func _add_clip(lib: AnimationLibrary, name: String, path: String) -> void:
	var scene := load(path)
	if scene == null:
		return
	var inst := (scene as PackedScene).instantiate()
	var ap := _find_anim(inst)
	if ap != null and ap.get_animation_list().size() > 0:
		var src := ap.get_animation(ap.get_animation_list()[0])
		var clip := src.duplicate() as Animation
		clip.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(name, clip)
	inst.queue_free()


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

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > 0.2 and _model != null:
		var target := atan2(hv.x, hv.z)
		_face_yaw = lerp_angle(_face_yaw, target, clampf(TURN_RATE * delta, 0.0, 1.0))
		_model.rotation.y = _face_yaw + deg_to_rad(MODEL_YAW_DEG)
	_update_anim(hv.length())


## Pick idle / walk / run by ground speed, and scale playback so the stride roughly
## tracks how fast we're actually moving.
func _update_anim(speed: float) -> void:
	if _anim == null:
		return
	if speed < 0.15:
		_play("ped/idle")
		_anim.speed_scale = 1.0
	elif speed < RUN_THRESHOLD:
		_play("ped/walk")
		_anim.speed_scale = WALK_ANIM_SCALE
	else:
		_play("ped/run")
		_anim.speed_scale = RUN_ANIM_SCALE


func _play(clip: String) -> void:
	if _cur_clip == clip:
		return
	_cur_clip = clip
	_anim.play(clip, 0.15)   # short cross-blend between states


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


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _find_anim(c)
		if a != null:
			return a
	return null


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null
