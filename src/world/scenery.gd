class_name Scenery
extends RefCounted

## Shared sky / sun / ground setup so the city sits in a real world with a
## horizon instead of a flat grey void.

static func make_environment() -> Environment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.47, 0.74)
	sky_mat.sky_horizon_color = Color(0.62, 0.72, 0.82)
	sky_mat.ground_horizon_color = Color(0.62, 0.72, 0.82)
	sky_mat.ground_bottom_color = Color(0.45, 0.50, 0.54)
	sky_mat.sky_energy_multiplier = 0.8
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Neutral, modest fill ambient (NOT sky-sourced) so the tile colours stay true
	# instead of washing out blue. The directional sun is the key light.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.63, 0.66)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.72, 0.82)
	env.fog_density = 0.0016       # fade distant geometry into the horizon haze
	env.fog_sky_affect = 0.0
	return env


static func add_sun(parent: Node) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -50, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	parent.add_child(light)
	return light


## A large flat sea/ground plane that fills the horizon under the city.
static func add_ground(parent: Node, center_xz: float, y: float) -> void:
	var ground := MeshInstance3D.new()
	ground.name = "SeaPlane"
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.40, 0.49)
	mat.roughness = 0.85
	ground.material_override = mat
	ground.position = Vector3(center_xz, y, center_xz)
	parent.add_child(ground)

	# Collision floor at sea level. The city collision is the rendered mesh, which
	# (like the original game) has no wall along open water edges — so a car driven
	# off a quay would otherwise drop into the void. An infinite WorldBoundaryShape3D
	# at sea level catches it on the water, and acts as a global "never fall through"
	# net. It sits well below every road (Y>=2), so it never interferes with driving.
	var sea_body := StaticBody3D.new()
	sea_body.name = "SeaCollision"
	var wb := WorldBoundaryShape3D.new()
	wb.plane = Plane(Vector3.UP, y)
	var cs := CollisionShape3D.new()
	cs.shape = wb
	sea_body.add_child(cs)
	parent.add_child(sea_body)
