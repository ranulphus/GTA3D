class_name WaterBuilder
extends RefCounted

## Builds an animated, wavy water surface over the city's water cells (rivers, canals
## and harbour — including the stretches that flow UNDER bridges). It sits as a thin
## translucent skin just on top of the existing riverbed water tile, so it needs no
## changes to the city mesh or its collision: the car still rests on the riverbed lid.
##
## Water is identified purely by the GTA1 data, NOT by a blanket height line — that
## would flood the subways, which also dip to z=0. The giveaway is the LID TILE: the
## animated water tile is used only for real water (open OR bridged), while sunken
## interiors / subway floors use ordinary concrete lids. We detect that tile per-map
## (so NYC/MIAMI/SANB all work) and lay water on every cell whose ground (z=0) block
## wears it.

## World Y of the water surface. The river is a channel 1 unit deep: the riverbed
## (the z=0 water block's lid) sits at Y=1 and the banks/streets at Y=2. Floating the
## surface at Y=1 left the water a paper-thin film on the bed; raising it to 1.6 fills
## the channel to ~0.6 units deep, so the translucent surface shows the bed 0.6 below
## and a real waterline climbs the channel walls. (Still well clear of the riverbed,
## so the waves can swing both ways without touching it.)
const WATER_LEVEL := 1.6
## Depth of the channel bed below the surface — only used to size the mesh AABB.
const BED_Y := 1.0
## Subcells per map cell. The waves are long (several units), so 2 (a 0.5-unit grid)
## is plenty of vertices for smooth crests without bloating the mesh.
const SUBDIV := 2


## The map's water lid tile: the most common z=0 lid among cells whose low ground is
## open to the sky (the sea / open rivers). Returns -1 if the map has no such cells.
static func detect_water_tile(map: GTA1Map) -> int:
	var hist := {}
	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			var n := map.get_num_blocks(x, y)
			if n == 0:
				continue
			if map.get_surface_y(x, y) > 1:
				continue           # the surface isn't low -> not open water
			var covered := false   # blocks above street level => sunken interior, skip
			for z in range(2, n):
				var bz := map.get_block(x, y, z)
				if bz != null and not bz.is_empty():
					covered = true
					break
			if covered:
				continue
			var b0 := map.get_block(x, y, 0)
			if b0 == null or b0.is_empty() or b0.lid <= 0:
				continue
			hist[b0.lid] = hist.get(b0.lid, 0) + 1
	var best := -1
	var best_n := 0
	for lid: int in hist:
		if hist[lid] > best_n:
			best_n = hist[lid]
			best = lid
	return best


## True if (x,y)'s ground block is water (wears the water lid tile). Picks up bridged
## river cells too, since it looks at z=0, not the visible surface.
static func is_water(map: GTA1Map, x: int, y: int, water_tile: int) -> bool:
	if water_tile < 0:
		return false
	var b0 := map.get_block(x, y, 0)
	return b0 != null and not b0.is_empty() and b0.lid == water_tile


## Build the water surface mesh. Vertices are in world coordinates (the node sits at
## the origin) so the wave shader can drive everything off world XZ and tile seamlessly
## across cells with no welding.
static func build(map: GTA1Map) -> MeshInstance3D:
	var water_tile := detect_water_tile(map)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var step := 1.0 / float(SUBDIV)

	for x in GTA1Map.DIM:
		for y in GTA1Map.DIM:
			if not is_water(map, x, y, water_tile):
				continue
			for sx in SUBDIV:
				for sy in SUBDIV:
					var x0 := float(x) + sx * step
					var x1 := x0 + step
					var z0 := float(y) + sy * step
					var z1 := z0 + step
					var base := verts.size()
					verts.push_back(Vector3(x0, WATER_LEVEL, z1))
					verts.push_back(Vector3(x1, WATER_LEVEL, z1))
					verts.push_back(Vector3(x1, WATER_LEVEL, z0))
					verts.push_back(Vector3(x0, WATER_LEVEL, z0))
					for i in 4:
						normals.push_back(Vector3.UP)
					indices.push_back(base); indices.push_back(base + 1); indices.push_back(base + 2)
					indices.push_back(base); indices.push_back(base + 2); indices.push_back(base + 3)

	var mi := MeshInstance3D.new()
	mi.name = "Water"
	if verts.is_empty():
		return mi
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, make_material())
	mi.mesh = mesh
	# The waves push verts up off WATER_LEVEL; a generous custom AABB stops the
	# surface being frustum-culled when the camera is low to the water.
	mi.custom_aabb = AABB(Vector3(0, BED_Y - 0.5, 0), Vector3(GTA1Map.DIM, WATER_LEVEL - BED_Y + 1.5, GTA1Map.DIM))
	return mi


## The animated water shader: a few summed sine waves displace the surface UP from
## the riverbed (never below it, so no z-fighting with the tile underneath), with the
## lit normal taken from the wave gradient for moving sun glints, and a fresnel-fading
## translucency so you see a little into the water head-on and it turns reflective at
## grazing angles.
static func make_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, diffuse_burley;

uniform vec3 deep_color : source_color = vec3(0.04, 0.15, 0.23);
uniform vec3 shallow_color : source_color = vec3(0.11, 0.36, 0.46);
uniform float wave_amp = 0.08;     // vertical swell of the surface (world units)
uniform float wave_speed = 0.6;
uniform float ripple = 0.35;       // how hard the ripples tilt the lit normal
uniform float water_alpha = 0.72;

// Big rolling swell — drives the geometry height and the broad shading.
float swell(vec2 p, float t) {
	float h = sin(p.x * 0.60 + t * 1.10)
			+ sin(p.y * 0.80 - t * 0.90)
			+ sin((p.x + p.y) * 0.45 + t * 1.30)
			+ sin((p.x - p.y) * 0.95 - t * 0.70) * 0.5;
	return h / 3.5; // -> roughly [-1, 1]
}

// Swell plus finer, faster chop — used only for the per-pixel normal so the light
// shimmers without needing a dense mesh.
float surf(vec2 p, float t) {
	return swell(p, t)
		+ sin(p.x * 2.1 - t * 1.7) * 0.25
		+ sin(p.y * 2.7 + t * 1.9) * 0.22
		+ sin((p.x + p.y) * 3.3 + t * 2.3) * 0.15;
}

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	// surface sits well above the riverbed now, so swing the swell both ways
	VERTEX.y += swell(v_world.xz, t) * wave_amp;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = v_world.xz;
	float e = 0.12;
	float h  = surf(p, t);
	float hx = surf(p + vec2(e, 0.0), t);
	float hz = surf(p + vec2(0.0, e), t);
	// world-space wave normal -> view space for lighting
	vec3 wn = normalize(vec3(-(hx - h) / e * ripple, 1.0, -(hz - h) / e * ripple));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = mix(deep_color, shallow_color, clamp(swell(p, t) * 0.5 + 0.5, 0.0, 1.0));
	METALLIC = 0.0;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0), 3.0);
	ALPHA = clamp(mix(water_alpha, 1.0, fres), 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
