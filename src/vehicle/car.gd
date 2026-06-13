class_name Car
extends VehicleBody3D

## A drivable vehicle built from a Kenney Car Kit (CC0) GLB. The model ships a
## `body` mesh and four named wheel meshes; we mount each wheel mesh on a
## VehicleWheel3D so suspension + steering work, and add a box collider for the
## body. Front wheels steer; all wheels provide traction (simple, grippy v1).
##
## Control: by default reads the arrow keys (ui_* actions). For headless tests
## set `use_input = false` and drive via control_throttle / control_steer.

const ENGINE_FORCE := 800.0
const MAX_STEER := 0.55
const BRAKE_FORCE := 12.0
const STEER_SPEED := 3.0

@export var model_path := "res://assets/vehicles/sedan.glb"

var use_input := true
var control_throttle := 0.0   # -1 (reverse) .. 1 (forward)
var control_steer := 0.0      # -1 (right) .. 1 (left)
var control_brake := 0.0      # 0 .. 1

var _steer := 0.0


func _ready() -> void:
	mass = 600.0
	can_sleep = false       # a sleeping RigidBody ignores engine_force
	continuous_cd = true    # don't tunnel through the city's thin lid collision
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.2, 0)   # low CoM so it doesn't tip
	_build()


func _build() -> void:
	var src := (load(model_path) as PackedScene).instantiate()

	var body := src.get_node_or_null("body") as MeshInstance3D
	var body_aabb := AABB(Vector3(-0.75, 0, -1.25), Vector3(1.5, 1.3, 2.55))
	if body != null:
		body_aabb = body.transform * body.mesh.get_aabb()
		body.owner = null   # detach from the source scene before reparenting
		src.remove_child(body)
		add_child(body)

	# [is_front_steering]
	var wheel_spec := {
		"wheel-front-left": true,
		"wheel-front-right": true,
		"wheel-back-left": false,
		"wheel-back-right": false,
	}
	for wname: String in wheel_spec:
		var wnode := src.get_node_or_null(wname) as Node3D
		if wnode == null:
			continue
		var wheel := VehicleWheel3D.new()
		wheel.position = wnode.position
		wheel.use_as_steering = wheel_spec[wname]
		wheel.use_as_traction = true
		wheel.wheel_radius = _wheel_radius(wnode)
		wheel.suspension_travel = 0.3
		wheel.suspension_stiffness = 30.0
		wheel.wheel_friction_slip = 10.5
		wheel.damping_compression = 0.6
		wheel.damping_relaxation = 0.9
		wheel.wheel_rest_length = 0.15
		add_child(wheel)
		wnode.owner = null   # detach from the source scene before reparenting
		src.remove_child(wnode)
		wheel.add_child(wnode)
		wnode.position = Vector3.ZERO

	# Collider covers only the upper body so the WHEELS are the lowest contact
	# (otherwise the chassis rests on the road and the wheels can't grip).
	var top := body_aabb.position.y + body_aabb.size.y
	var box_bottom := body_aabb.position.y + body_aabb.size.y * 0.35
	var box := BoxShape3D.new()
	box.size = Vector3(body_aabb.size.x * 0.9, top - box_bottom, body_aabb.size.z * 0.95)
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = Vector3(body_aabb.get_center().x, (top + box_bottom) * 0.5, body_aabb.get_center().z)
	add_child(col)

	src.queue_free()


func _wheel_radius(wnode: Node3D) -> float:
	for child in wnode.get_children():
		if child is MeshInstance3D and child.mesh != null:
			return maxf(child.mesh.get_aabb().size.y * 0.5, 0.3)
	if wnode is MeshInstance3D and wnode.mesh != null:
		return maxf(wnode.mesh.get_aabb().size.y * 0.5, 0.3)
	return 0.35


func _physics_process(delta: float) -> void:
	var throttle := control_throttle
	var steer := control_steer
	var brk := control_brake
	if use_input:
		throttle = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
		steer = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")

	_steer = move_toward(_steer, steer * MAX_STEER, STEER_SPEED * delta)
	steering = _steer
	engine_force = throttle * ENGINE_FORCE
	brake = brk * BRAKE_FORCE
