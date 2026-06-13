class_name MapBuilder
extends RefCounted

## Extrudes a GTA1Map's block grid into a single textured ArrayMesh.
##
## The city is a 256x256 grid of stacked cubes. We map:
##   map x   -> world X
##   map y   -> world Z   (so the top-down grid lies on the XZ plane)
##   stack z -> world Y   (up)
##
## For each non-empty block we emit the visible faces only (a face is skipped if
## the neighbouring cell is solid), textured from the tile atlas:
##   lid byte   -> top (+Y) face, indexes the LID tile set
##   left/right -> -X / +X walls, index the SIDE tile set
##   top/bottom -> -Z / +Z walls, index the SIDE tile set
##
## v1 limitations (see ROADMAP): slope/ramp blocks are drawn as full cubes;
## block rotation / face flips are not yet applied to UVs. Calibrated visually.

const BLOCK := 1.0


static func build(map: GTA1Map, style: GTA1Style, region := Rect2i(0, 0, GTA1Map.DIM, GTA1Map.DIM)) -> MeshInstance3D:
	var atlas := TileAtlas.build(style)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var x0 := maxi(region.position.x, 0)
	var y0 := maxi(region.position.y, 0)
	var x1 := mini(region.position.x + region.size.x, GTA1Map.DIM)
	var y1 := mini(region.position.y + region.size.y, GTA1Map.DIM)

	for x in range(x0, x1):
		for y in range(y0, y1):
			var count := map.get_num_blocks(x, y)
			for z in count:
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty():
					continue
				_emit_block(verts, normals, uvs, indices, atlas, style, map, b, x, y, z,
					float(x), float(z), float(y))
			# Close height steps: GTA1 ground blocks have no side textures, so a
			# step to a lower neighbour leaves a gap. Fill it with the surface tile.
			_emit_skirt(verts, normals, uvs, indices, atlas, style, map, x, y)

	var mesh := ArrayMesh.new()
	if verts.is_empty():
		push_warning("MapBuilder: no geometry produced for region %s" % region)
	else:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas.texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	if not verts.is_empty():
		mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "City"
	return mi


## Solid collision for the city: a HeightMapShape3D sampling the drivable surface
## height per cell. Unlike a trimesh of the thin lids, this is solid below the
## surface, so the car can't tunnel/bounce through it. Buildings become tall
## heightfield columns (steep walls the car bumps into).
static func build_heightfield_collision(map: GTA1Map) -> StaticBody3D:
	var hf := HeightMapShape3D.new()
	hf.map_width = GTA1Map.DIM
	hf.map_depth = GTA1Map.DIM
	var data := PackedFloat32Array()
	data.resize(GTA1Map.DIM * GTA1Map.DIM)
	for j in GTA1Map.DIM:
		for i in GTA1Map.DIM:
			data[j * GTA1Map.DIM + i] = float(map.get_surface_y(i, j))
	hf.map_data = data

	var body := StaticBody3D.new()
	body.name = "CityCollision"
	var cs := CollisionShape3D.new()
	cs.shape = hf
	body.add_child(cs)
	# Heightfield grid point (i,j) sits at world (i+0.5, h, j+0.5) — the cell
	# centre — when the body is centred at (DIM/2, 0, DIM/2).
	body.position = Vector3(GTA1Map.DIM / 2.0, 0.0, GTA1Map.DIM / 2.0)
	return body


static func _emit_block(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, b: GTA1Block, x: int, y: int, z: int, fx: float, fy: float, fz: float) -> void:
	if b.is_flat():
		_emit_flat(verts, normals, uvs, indices, atlas, style, b, fx, fy, fz)
	elif b.slope_type() == 0:
		_emit_cube(verts, normals, uvs, indices, atlas, style, map, b, x, y, z, fx, fy, fz)
	else:
		_emit_slope(verts, normals, uvs, indices, atlas, style, b, fx, fy, fz, b.slope_type())


## Flat blocks are zero-thickness decals/panels, not cubes: road markings, painted
## details, fences, railings. GTA1 stores ~9% of blocks this way, mostly floating
## a level above the road as overlay lids. Drawing them as full cubes produced
## floating boxes and fence "crates". Instead we emit a single thin quad per face:
## the lid as a flat decal laid on the surface below (block base, not top), and
## each side byte as one upright panel at its boundary plane. CULL_DISABLED makes
## the panels visible from both sides. A small epsilon keeps them off neighbouring
## planes to avoid z-fighting.
const FLAT_EPS := 0.03
static func _emit_flat(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		b: GTA1Block, fx: float, fy: float, fz: float) -> void:
	var x0 := fx
	var x1 := fx + BLOCK
	var y0 := fy
	var y1 := fy + BLOCK
	var z0 := fz
	var z1 := fz + BLOCK

	if b.lid > 0:
		var yl := y0 + FLAT_EPS  # lay the decal on the surface below, not floating on top
		_face(verts, normals, uvs, indices, atlas, style.num_side + b.lid, Vector3.UP,
			Vector3(x0, yl, z1), Vector3(x1, yl, z1), Vector3(x1, yl, z0), Vector3(x0, yl, z0),
			_uv(b.rotation(), false, false))
	if b.left > 0:
		var xl := x0 + FLAT_EPS
		_face(verts, normals, uvs, indices, atlas, b.left, Vector3.LEFT,
			Vector3(xl, y0, z1), Vector3(xl, y0, z0), Vector3(xl, y1, z0), Vector3(xl, y1, z1))
	if b.right > 0:
		var xr := x1 - FLAT_EPS
		_face(verts, normals, uvs, indices, atlas, b.right, Vector3.RIGHT,
			Vector3(xr, y0, z0), Vector3(xr, y0, z1), Vector3(xr, y1, z1), Vector3(xr, y1, z0))
	if b.top > 0:
		var zt := z0 + FLAT_EPS
		_face(verts, normals, uvs, indices, atlas, b.top, Vector3.FORWARD,
			Vector3(x1, y0, zt), Vector3(x0, y0, zt), Vector3(x0, y1, zt), Vector3(x1, y1, zt))
	if b.bottom > 0:
		var zb := z1 - FLAT_EPS
		_face(verts, normals, uvs, indices, atlas, b.bottom, Vector3.BACK,
			Vector3(x0, y0, zb), Vector3(x1, y0, zb), Vector3(x1, y1, zb), Vector3(x0, y1, zb))


## Slope/ramp blocks: emit the exact per-face geometry for this slope type (1-44)
## from SlopeData. Faces whose quad collapses to a line are skipped.
static func _emit_slope(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		b: GTA1Block, fx: float, fy: float, fz: float, st: int) -> void:
	var sf: Array = SlopeData.faces[st]
	var origin := Vector3(fx, fy, fz)
	# face order: LID, NORTH(+Z), SOUTH(-Z), WEST(-X), EAST(+X). Only the lid is
	# rotated; walls use the tile as-is (flips disabled — see _emit_cube).
	var bytes := [b.lid, b.bottom, b.top, b.left, b.right]
	var lid_uv: Array = _uv(b.rotation(), false, false)
	for fi in 5:
		var byte: int = bytes[fi]
		if byte <= 0:
			continue
		var quad: PackedVector3Array = sf[fi]
		var a := origin + quad[0]
		var bb := origin + quad[1]
		var c := origin + quad[2]
		var d := origin + quad[3]
		var nrm := (bb - a).cross(c - a)
		if nrm.length() < 0.0001:
			continue  # degenerate (collapsed) face
		var slot := (style.num_side + byte) if fi == 0 else byte
		var luv: Array = lid_uv if fi == 0 else BASE_UV
		_face(verts, normals, uvs, indices, atlas, slot, nrm.normalized(), a, bb, c, d, luv)


## Vertical "skirt" walls that close the gaps where a cell's drivable surface
## steps down to a lower neighbour (or the map edge / water). Textured with the
## cell's own surface (lid) tile so it blends with the ground above it.
static func _emit_skirt(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, x: int, y: int) -> void:
	var sy := map.get_surface_y(x, y)
	if sy <= 0:
		return
	var sb := map.get_block(x, y, sy - 1)
	if sb == null or sb.lid <= 0:
		return
	# Only "lid-only" ground blocks (roads, pavement, grass) need skirts: they
	# carry no side textures, so a step down to a lower neighbour leaves an open
	# gap. Blocks that DO have side textures (buildings, fences, walls) already
	# get real walls from _emit_cube — skirting them would draw a second wall
	# (textured with the roof/lid tile) flush over the first and z-fight it.
	if sb.left != 0 or sb.right != 0 or sb.top != 0 or sb.bottom != 0:
		return
	var slot := style.num_side + sb.lid
	var x0 := float(x)
	var x1 := x0 + BLOCK
	var z0 := float(y)
	var z1 := z0 + BLOCK
	var hi := float(sy)

	var n_xm := map.get_surface_y(x - 1, y) if x > 0 else 0
	var n_xp := map.get_surface_y(x + 1, y) if x < GTA1Map.DIM - 1 else 0
	var n_zm := map.get_surface_y(x, y - 1) if y > 0 else 0
	var n_zp := map.get_surface_y(x, y + 1) if y < GTA1Map.DIM - 1 else 0

	if n_xm < sy:
		var lo := float(n_xm)
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.LEFT,
			Vector3(x0, lo, z1), Vector3(x0, lo, z0), Vector3(x0, hi, z0), Vector3(x0, hi, z1))
	if n_xp < sy:
		var lo := float(n_xp)
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.RIGHT,
			Vector3(x1, lo, z0), Vector3(x1, lo, z1), Vector3(x1, hi, z1), Vector3(x1, hi, z0))
	if n_zm < sy:
		var lo := float(n_zm)
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.FORWARD,
			Vector3(x1, lo, z0), Vector3(x0, lo, z0), Vector3(x0, hi, z0), Vector3(x1, hi, z0))
	if n_zp < sy:
		var lo := float(n_zp)
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.BACK,
			Vector3(x0, lo, z1), Vector3(x1, lo, z1), Vector3(x1, hi, z1), Vector3(x0, hi, z1))


## Full cube (slope type 0): emit only the faces whose neighbour is empty.
static func _emit_cube(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, b: GTA1Block, x: int, y: int, z: int, fx: float, fy: float, fz: float) -> void:
	var x0 := fx
	var x1 := fx + BLOCK
	var y0 := fy
	var y1 := fy + BLOCK
	var z0 := fz
	var z1 := fz + BLOCK

	# Lid / top (+Y) — only the lid is rotated (0/90/180/270), per OpenGTA. Flips
	# are NOT applied to the lid; mirroring it warps road markings/arrows. The
	# vertex order (z1->z1->z0->z0) matches OpenGTA's SLOPE_RAW_DATA[0][0] so the
	# tile's V axis runs +Z (south); the earlier z0-first order mirrored every
	# road lid north-south, which scrambled kerbs/junctions once rotated.
	if b.lid > 0 and not _solid(map, x, y, z + 1):
		_face(verts, normals, uvs, indices, atlas, style.num_side + b.lid, Vector3.UP,
			Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0),
			_uv(b.rotation(), false, false))
	# Left (-X)
	if b.left > 0 and not _solid(map, x - 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.left, Vector3.LEFT,
			Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	# Right (+X)
	if b.right > 0 and not _solid(map, x + 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.right, Vector3.RIGHT,
			Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0))
	# Top wall / north (-Z)
	if b.top > 0 and not _solid(map, x, y - 1, z):
		_face(verts, normals, uvs, indices, atlas, b.top, Vector3.FORWARD,
			Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0))
	# Bottom wall / south (+Z)
	if b.bottom > 0 and not _solid(map, x, y + 1, z):
		_face(verts, normals, uvs, indices, atlas, b.bottom, Vector3.BACK,
			Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1))


## Local UV corners matching the a->b->c->d vertex winding (OpenGTA lidTex order).
const BASE_UV: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]


## Per-face UVs after applying GTA1's block rotation (0-3, cyclically shifts which
## tile corner maps to each vertex — rotates the texture 0/90/180/270) and the
## left-right / top-bottom mirror flips.
static func _uv(rot: int, flip_lr: bool, flip_tb: bool) -> Array:
	var out: Array = [
		BASE_UV[rot % 4], BASE_UV[(rot + 1) % 4], BASE_UV[(rot + 2) % 4], BASE_UV[(rot + 3) % 4]
	]
	if flip_lr or flip_tb:
		for i in 4:
			var u: float = out[i].x
			var v: float = out[i].y
			if flip_lr:
				u = 1.0 - u
			if flip_tb:
				v = 1.0 - v
			out[i] = Vector2(u, v)
	return out


## Emit one textured quad (two triangles). Corner order a->b->c->d is CCW around
## the outward normal; `luv` are the per-corner tile UVs (0..1) mapped into the slot.
static func _face(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, atlas: TileAtlas, slot: int, n: Vector3,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, luv: Array = BASE_UV) -> void:
	var r := atlas.uv_rect(slot)
	var base := verts.size()
	verts.push_back(a); verts.push_back(b); verts.push_back(c); verts.push_back(d)
	for i in 4:
		normals.push_back(n)
	for i in 4:
		var lv: Vector2 = luv[i]
		uvs.push_back(Vector2(r.position.x + lv.x * r.size.x, r.position.y + lv.y * r.size.y))
	indices.push_back(base); indices.push_back(base + 1); indices.push_back(base + 2)
	indices.push_back(base); indices.push_back(base + 2); indices.push_back(base + 3)


static func _solid(map: GTA1Map, x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or x >= GTA1Map.DIM or y >= GTA1Map.DIM:
		return false
	if z < 0:
		return true   # below ground counts as solid (don't draw downward faces)
	if z >= map.get_num_blocks(x, y):
		return false
	var b := map.get_block(x, y, z)
	return b != null and not b.is_empty()
