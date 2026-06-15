class_name Car
extends VehicleBody3D

## A drivable vehicle built from a low-poly model. Two kinds of source work:
##   * a GLB scene exposing a `body` mesh and named wheel nodes (Kenney Car Kit):
##     each wheel mesh is mounted on a VehicleWheel3D so it steers and spins; or
##   * a single mesh — e.g. an imported .obj PSX-style car: the whole mesh is the
##     body and four physics wheels are synthesised from its bounding box.
## Either way the car is uniformly scaled to ~one map cell wide and yawed so its
## hood faces the drive-forward (-Z) axis.
##
## Control: by default reads the arrow keys (ui_* actions). For headless tests set
## `use_input = false` and drive via control_throttle / control_steer.

## Performance is rated 0..10 per attribute and mapped to physics here. The anchors
## reproduce the measured "stock" car at the scores the brief assigned it:
##   Speed 10  -> ~45 m/s top speed (the old uncapped top speed)
##   Accel 7   -> 800 N engine force (the old value)
##   Braking 6 -> 24 brake force (doubled from the original 12 for snappier stops)
## Handling drives steering rate, lock and grip; even 10 is far tamer than the old
## on-rails 0.55 rad / 10.5 grip, and lower scores slide more.
const TOP_SPEED_PER_PT := 4.5      # m/s per Speed point   (10 -> 45)
const ENGINE_BASE := 100.0         # N
const ENGINE_PER_PT := 100.0       # N per Accel point     (7 -> 800)
const BRAKE_PER_PT := 4.0          # per Braking point     (6 -> 24, ~2x faster stops)
const REVERSE_FRAC := 0.45         # reverse top speed / engine vs forward

# Handling -> steering & grip. The lock is what actually turns the car (the wheels
# do the steering); it needs to be big at low speed for tight street corners, and
# is cut right down at speed (HIGH_SPEED_STEER) so fast driving isn't twitchy.
const STEER_LOCK_BASE := 0.32      # rad of steering lock at handling 0 (~18 deg)
const STEER_LOCK_PER_PT := 0.023   # +per handling point   (10 -> ~0.55 rad, ~31 deg)
const STEER_RATE_BASE := 1.2       # how fast the wheel turns toward the target (rad/s)
const STEER_RATE_PER_PT := 0.1
# Lateral wheel friction. Cornering load grows with speed^2, so a flat grip would
# let only the fast cars slide. We add a speed term (faster car -> proportionally
# more grip) to cancel that, leaving HANDLING as the real knob: lower handling
# slides more, higher grips more. The yaw assist stops any of it becoming a spin.
const GRIP_BASE := 1.0
const GRIP_SPEED_PER := 0.2        # +per Speed point    (normalises the v^2 load)
const GRIP_HANDLING_PER := 0.13    # +per Handling point (the actual grip/skid knob)
const REAR_GRIP_FRAC := 0.95       # rear vs front grip: slight oversteer, not a spin
const HIGH_SPEED_STEER := 0.045    # steering lock multiplier at top speed (less twitchy)
# Steering is kinematic: the wheels alone barely turn this little body, so we ease
# the body's yaw toward the rate the steer asks for. Low-speed turn radius is
# ~1/(lock*YAW_GAIN); the velocity follows (grip easily holds the low load) for a
# tight turn. At speed the lock is cut hard (HIGH_SPEED_STEER) so the asked-for yaw
# only slightly out-runs grip -> a controlled slide, not a spin. YAW_RATE (scaled by
# handling) is how quickly the yaw catches the target.
const YAW_GAIN := 1.6
const YAW_RATE_BASE := 5.0
const YAW_RATE_PER_PT := 0.4
const SLIP_ALIGN := 3.0         # self-aligning pull of the heading back toward the
                                # velocity, so a slide caps into a drift, not a spin
const ANGULAR_DAMP := 1.5      # gentle residual damping (roll/pitch settling)
# Self-righting: every frame we ease the car's roll+pitch toward the normal of
# the surface beneath it, so a tip from a hard turn, a crash or a jump always
# rotates back onto four wheels instead of getting stuck on its side / nose /
# tail. Aiming at the GROUND's normal (not world-up) means a car sitting on a
# ramp matches the ramp and is never fought, while a tipped car on level road is
# pushed fully upright. The correction scales with how far it has leaned, so flat
# driving and small bumps are barely touched.
const RIGHTING_GAIN := 6.0     # righting spin toward the ground normal = sin(lean) * this
const RIGHTING_RATE := 12.0    # how fast that righting spin builds (rad/s^2)

## Performance scores out of 10, set per car model before the node enters the tree.
@export_range(0, 10) var speed_score := 5.0
@export_range(0, 10) var accel_score := 5.0
@export_range(0, 10) var brake_score := 5.0
@export_range(0, 10) var handling_score := 5.0

## Target body width (the narrow horizontal side) in world units. GTA1 streets are
## 1 unit per map cell; a car about half a cell wide leaves room for two lanes.
const TARGET_WIDTH := 0.5

const WHEEL_NAMES := ["wheel-front-left", "wheel-front-right", "wheel-back-left", "wheel-back-right"]

@export var model_path := "res://assets/vehicles/psx/car1/Car.obj"
## Yaw (degrees) turning the model so its hood points down -Z (the drive axis).
## The PSX cars (and the old Kenney sedan) face +Z, hence 180. Per-model.
@export var model_yaw_deg := 180.0
## Optional separate wheel model mounted on the synthesised wheels, for bodies that
## ship WITHOUT wheels. The PSX cars model their wheels into the body, so this is
## empty by default (the physics wheels stay invisible to avoid doubling them).
@export var wheel_model_path := ""
## Optional albedo texture override. One body mesh can be recoloured/re-skinned per
## cycle entry — the PSX cars ship colour and taxi/police variants as alternate
## textures over the same geometry. Empty = use the model's own baked material.
@export var texture_path := ""

var use_input := true
var control_throttle := 0.0   # -1 (reverse) .. 1 (forward)
var control_steer := 0.0      # -1 (right) .. 1 (left)
var control_brake := 0.0      # 0 .. 1

var _steer := 0.0
# Derived performance, computed from the scores in _ready (before the wheels).
var _top_speed := 22.5
var _engine_force := 600.0
var _brake_force := 10.0
var _steer_lock := 0.27
var _steer_rate := 1.0
var _grip := 4.75
var _yaw_rate := 7.0


func _ready() -> void:
	mass = 600.0
	can_sleep = false       # a sleeping RigidBody ignores engine_force
	continuous_cd = true    # don't tunnel through the city's thin lid collision
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_compute_performance()
	angular_damp = ANGULAR_DAMP
	_build()


## Map the 0..10 scores to physics. Called before _build so the wheels pick up the
## grip. See the score->value anchors in the constants above.
func _compute_performance() -> void:
	_top_speed = maxf(6.0, TOP_SPEED_PER_PT * speed_score)
	_engine_force = ENGINE_BASE + ENGINE_PER_PT * accel_score
	_brake_force = BRAKE_PER_PT * brake_score
	_steer_lock = STEER_LOCK_BASE + STEER_LOCK_PER_PT * handling_score
	_steer_rate = STEER_RATE_BASE + STEER_RATE_PER_PT * handling_score
	_grip = GRIP_BASE + GRIP_SPEED_PER * speed_score + GRIP_HANDLING_PER * handling_score
	_yaw_rate = YAW_RATE_BASE + YAW_RATE_PER_PT * handling_score


func _build() -> void:
	var res := load(model_path)
	var src: Node = null
	var body: MeshInstance3D = null
	var named := {}
	if res is Mesh:
		body = MeshInstance3D.new()
		body.mesh = res
	elif res is PackedScene:
		src = (res as PackedScene).instantiate()
		body = src.get_node_or_null("body") as MeshInstance3D
		if body == null:
			body = _first_mesh(src)
		for wname in WHEEL_NAMES:
			var wn := src.get_node_or_null(wname) as Node3D
			if wn != null:
				named[wname] = wn
	if body == null or body.mesh == null:
		push_error("Car: no usable mesh in %s" % model_path)
		return

	var native: AABB = body.transform * body.mesh.get_aabb()
	# Scale by the NARROW horizontal side, so a model whose length runs along either
	# axis still ends up about one cell wide rather than one cell long.
	var horiz := minf(native.size.x, native.size.z)
	var s := clampf(TARGET_WIDTH / maxf(horiz, 0.01), 0.1, 4.0)
	center_of_mass = Vector3(0, -0.2 * s, 0)   # modestly low; ROLL_DAMP does the anti-tip

	if src != null and body.get_parent() != null:
		body.owner = null   # detach from the source scene before reparenting
		body.get_parent().remove_child(body)
	add_child(body)
	body.position = body.position * s
	body.scale = body.scale * s
	body.rotate_y(deg_to_rad(model_yaw_deg))
	if texture_path != "":
		var tex := load(texture_path) as Texture2D
		if tex != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # crisp PSX look
			mat.roughness = 1.0
			mat.metallic = 0.0
			body.material_override = mat

	var aabb: AABB = body.transform * body.mesh.get_aabb()   # car-space, post scale+yaw

	if named.is_empty():
		_synth_wheels(aabb, s)
	else:
		_mount_wheels(src, named, s)

	_add_collider(aabb)
	if src != null:
		src.queue_free()


## Mount the model's own wheel meshes (Kenney) on VehicleWheel3Ds. The pair toward
## -Z (the drive-forward edge after the yaw) steers; all four drive.
func _mount_wheels(src: Node, named: Dictionary, s: float) -> void:
	for wname in named:
		var wnode: Node3D = named[wname]
		var wheel := VehicleWheel3D.new()
		wheel.position = wnode.position * s
		wheel.use_as_steering = wheel.position.z < 0.0
		wheel.use_as_traction = true
		wheel.wheel_radius = _wheel_radius(wnode) * s
		wheel.suspension_travel = 0.3
		wheel.suspension_stiffness = 30.0
		# Rear wheels grip a touch less than the front so hard turns oversteer
		# (the back steps out) instead of pushing straight on.
		wheel.wheel_friction_slip = _grip if wheel.position.z < 0.0 else _grip * REAR_GRIP_FRAC
		wheel.damping_compression = 0.6
		wheel.damping_relaxation = 0.9
		wheel.wheel_rest_length = 0.15 * s
		add_child(wheel)
		wnode.owner = null   # detach from the source scene before reparenting
		src.remove_child(wnode)
		wheel.add_child(wnode)
		wnode.position = Vector3.ZERO
		wnode.scale = wnode.scale * s


## Synthesise four VehicleWheel3D at the corners of the body box. The PSX bodies
## have wheels modelled into the mesh, so by default the physics wheels are
## INVISIBLE (no mounted mesh) and the suspension is stiff/short — the car rests on
## its own modelled wheels with no bob or doubled wheels. The wheel bottoms are
## placed at the body underside so the modelled wheels meet the road and the car
## can't sink onto its chassis. If wheel_model_path is set, a wheel mesh is mounted
## instead (kept for models that ship without wheels). `s` is the car's scale.
func _synth_wheels(aabb: AABB, s: float) -> void:
	var wheel_mesh: Mesh = _load_mesh(wheel_model_path) if wheel_model_path != "" else null
	var minp := aabb.position
	var maxp := aabb.position + aabb.size
	var radius: float
	if wheel_mesh != null:
		radius = maxf(wheel_mesh.get_aabb().size.y * 0.5 * s, 0.08)
	else:
		radius = clampf(aabb.size.y * 0.22, 0.1, 0.3)   # ~ the modelled wheel radius
	var inset := aabb.size.x * 0.06
	var xl := maxp.x - inset
	var xr := minp.x + inset
	var z_front := minp.z + aabb.size.z * 0.20
	var z_rear := minp.z + aabb.size.z * 0.80
	var z_mid := (z_front + z_rear) * 0.5
	# Place the wheel so its bottom sits a hair below the body underside: the car
	# settles with its modelled wheels on the road, not floating or buried.
	var wy := minp.y + radius - 0.03
	for p in [Vector3(xl, wy, z_front), Vector3(xr, wy, z_front),
			Vector3(xl, wy, z_rear), Vector3(xr, wy, z_rear)]:
		var wheel := VehicleWheel3D.new()
		wheel.position = p
		wheel.use_as_steering = p.z < z_mid
		wheel.use_as_traction = true
		wheel.wheel_radius = radius
		# Stiff, short, well-damped: minimal body bob so the static wheels look right.
		wheel.suspension_travel = 0.1
		wheel.suspension_stiffness = 60.0
		# Lateral grip from the handling score; rear grips a little less so the back
		# steps out in hard turns (skid/oversteer) rather than driving on rails.
		wheel.wheel_friction_slip = _grip if p.z < z_mid else _grip * REAR_GRIP_FRAC
		wheel.damping_compression = 0.9
		wheel.damping_relaxation = 1.0
		wheel.wheel_rest_length = 0.04
		add_child(wheel)
		if wheel_mesh != null:
			var mi := MeshInstance3D.new()
			mi.mesh = wheel_mesh
			mi.scale = Vector3(s, s, s)
			# Spin the left-hand wheels 180 about the vertical so the hub faces out
			# (a 180 rotation keeps normals correct, unlike a negative scale).
			if p.x < 0.0:
				mi.rotation.y = PI
			wheel.add_child(mi)


func _load_mesh(path: String) -> Mesh:
	var r := load(path)
	if r is Mesh:
		return r
	if r is PackedScene:
		var m := _first_mesh((r as PackedScene).instantiate())
		return m.mesh if m != null else null
	return null


## Collider covers only the upper body so the WHEELS are the lowest contact
## (otherwise the chassis rests on the road and the wheels can't grip).
func _add_collider(aabb: AABB) -> void:
	var top := aabb.position.y + aabb.size.y
	var box_bottom := aabb.position.y + aabb.size.y * 0.35
	var box := BoxShape3D.new()
	box.size = Vector3(aabb.size.x * 0.9, maxf(top - box_bottom, 0.1), aabb.size.z * 0.95)
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = Vector3(aabb.get_center().x, (top + box_bottom) * 0.5, aabb.get_center().z)
	add_child(col)


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


func _wheel_radius(wnode: Node3D) -> float:
	for child in wnode.get_children():
		if child is MeshInstance3D and child.mesh != null:
			return maxf(child.mesh.get_aabb().size.y * 0.5, 0.3)
	if wnode is MeshInstance3D and wnode.mesh != null:
		return maxf(wnode.mesh.get_aabb().size.y * 0.5, 0.3)
	return 0.35


## Current speed as a fraction (0..1) of this car's top speed — used by the chase
## camera to zoom out with speed.
func speed_ratio() -> float:
	return clampf(linear_velocity.length() / maxf(_top_speed, 1.0), 0.0, 1.0)


## Up-normal of the surface directly beneath the car — the ramp, the road, or
## straight up when airborne. The self-righting torque aims the car's up vector at
## this, so it lands flat on a ramp without being fought yet a tipped car on level
## road is pushed fully upright.
func _ground_normal() -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return Vector3.UP
	var from := global_position + Vector3(0, 0.4, 0)
	var to := global_position - Vector3(0, 4.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.UP
	var n: Vector3 = hit.normal
	if n.y <= 0.05:           # hit an underside / near-vertical face: ignore it
		return Vector3.UP
	return n


func _physics_process(delta: float) -> void:
	var throttle := control_throttle
	var steer := control_steer
	if use_input:
		throttle = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
		steer = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")

	# Forward speed along the car's hood (-Z). The model is yawed so its hood faces
	# -Z; a positive engine_force pushes +Z, so "forward" needs a negative force.
	var fwd := linear_velocity.dot(-global_transform.basis.z)

	if throttle > 0.0:
		# Accelerate forward, but cut the engine once at the speed cap.
		engine_force = 0.0 if fwd >= _top_speed else -throttle * _engine_force
		brake = control_brake * _brake_force
	elif throttle < 0.0 and fwd > 1.0:
		# Moving forward with reverse held = brake (Braking score), don't reverse yet.
		engine_force = 0.0
		brake = -throttle * _brake_force
	elif throttle < 0.0:
		# Stopped/rolling back: reverse, capped slower than forward.
		engine_force = 0.0 if fwd <= -_top_speed * REVERSE_FRAC else -throttle * _engine_force * REVERSE_FRAC
		brake = 0.0
	else:
		engine_force = 0.0
		brake = control_brake * _brake_force

	# Steering: ease toward the target lock (gradual the longer the key is held) and
	# tighten less at speed so fast turns aren't twitchy. _steer_rate / _steer_lock
	# both come from the handling score; even handling 10 is far gentler than before.
	var speed_t := clampf(absf(fwd) / maxf(_top_speed, 1.0), 0.0, 1.0)
	var lock := _steer_lock * lerpf(1.0, HIGH_SPEED_STEER, speed_t)
	_steer = move_toward(_steer, steer * lock, _steer_rate * delta)
	steering = _steer

	# Kinematic yaw: ease the body's turn rate toward what the steer asks for, so the
	# little body actually turns. The velocity follows at low load (tight turn) and
	# slides at speed (skid). Intent flips with travel direction so reverse steers
	# right. A self-aligning term pulls the heading back toward the travel direction
	# when it slides, so a hard turn drifts and recovers instead of spinning round.
	var intended_yaw := _steer * fwd * YAW_GAIN
	var vel_flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var head_flat := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z)
	if vel_flat.length() > 3.0 and head_flat.length() > 0.01:
		var slip := head_flat.normalized().signed_angle_to(vel_flat.normalized(), Vector3.UP)
		intended_yaw += slip * SLIP_ALIGN
	var av := angular_velocity
	av.y = move_toward(av.y, intended_yaw, _yaw_rate * delta)
	# Self-righting / anti-tip. Rotate the car's up vector toward the normal of the
	# surface beneath it, so a tip (hard turn, crash, jump) always settles back onto
	# four wheels. Aiming at the GROUND normal rather than world-up means a car on a
	# ramp matches the ramp and is never fought; on level road the normal IS up, so
	# a tipped car is pushed fully upright. up x ground-normal is the axis that
	# rotates one onto the other, with |.| = sin(lean); we drive roll+pitch (x, z)
	# toward it and leave yaw (y) to the kinematic steering above. The target is ~0
	# when the car sits flush, so normal driving and bumps are barely touched —
	# crucially this no longer depends on wheel-contact count, which stayed at 3-4
	# even at a stuck 35-degree lean because the lifted wheels' rays still reached.
	var up := global_transform.basis.y
	var ground_up := _ground_normal()
	var tilt_axis := up.cross(ground_up)
	if tilt_axis.length() < 1e-3 and up.dot(ground_up) < 0.0:
		tilt_axis = global_transform.basis.z   # exactly inverted: pick a definite axis to flip about
	av.x = move_toward(av.x, tilt_axis.x * RIGHTING_GAIN, RIGHTING_RATE * delta)
	av.z = move_toward(av.z, tilt_axis.z * RIGHTING_GAIN, RIGHTING_RATE * delta)
	angular_velocity = av
