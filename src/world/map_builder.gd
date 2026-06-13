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


static func _emit_block(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, b: GTA1Block, x: int, y: int, z: int, fx: float, fy: float, fz: float) -> void:
	if b.slope_type() == 0:
		_emit_cube(verts, normals, uvs, indices, atlas, style, map, b, x, y, z, fx, fy, fz)
	else:
		_emit_slope(verts, normals, uvs, indices, atlas, style, b, fx, fy, fz, b.slope_type())


## Slope/ramp blocks: emit the exact per-face geometry for this slope type (1-44)
## from SlopeData. Faces whose quad collapses to a line are skipped.
static func _emit_slope(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		b: GTA1Block, fx: float, fy: float, fz: float, st: int) -> void:
	var sf: Array = SlopeData.faces[st]
	var origin := Vector3(fx, fy, fz)
	var flip_lr := b.flip_left_right()
	var flip_tb := b.flip_top_bottom()
	# face order: LID, NORTH(+Z), SOUTH(-Z), WEST(-X), EAST(+X)
	var bytes := [b.lid, b.bottom, b.top, b.left, b.right]
	# UV transform per face: lid gets rotation; N/S walls get top-bottom flip;
	# W/E walls get left-right flip.
	var face_uv: Array = [
		_uv(b.rotation(), flip_lr, flip_tb),
		_uv(0, flip_tb, false), _uv(0, flip_tb, false),
		_uv(0, flip_lr, false), _uv(0, flip_lr, false),
	]
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
		_face(verts, normals, uvs, indices, atlas, slot, nrm.normalized(), a, bb, c, d, face_uv[fi])


## Full cube (slope type 0): emit only the faces whose neighbour is empty.
static func _emit_cube(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, b: GTA1Block, x: int, y: int, z: int, fx: float, fy: float, fz: float) -> void:
	var x0 := fx
	var x1 := fx + BLOCK
	var y0 := fy
	var y1 := fy + BLOCK
	var z0 := fz
	var z1 := fz + BLOCK
	var flip_lr := b.flip_left_right()
	var flip_tb := b.flip_top_bottom()

	# Lid / top (+Y) — the rotation/flip mainly drives road markings & arrows.
	if b.lid > 0 and not _solid(map, x, y, z + 1):
		_face(verts, normals, uvs, indices, atlas, style.num_side + b.lid, Vector3.UP,
			Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1),
			_uv(b.rotation(), flip_lr, flip_tb))
	# Left (-X)
	if b.left > 0 and not _solid(map, x - 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.left, Vector3.LEFT,
			Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1),
			_uv(0, flip_lr, false))
	# Right (+X)
	if b.right > 0 and not _solid(map, x + 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.right, Vector3.RIGHT,
			Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0),
			_uv(0, flip_lr, false))
	# Top wall / north (-Z)
	if b.top > 0 and not _solid(map, x, y - 1, z):
		_face(verts, normals, uvs, indices, atlas, b.top, Vector3.FORWARD,
			Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0),
			_uv(0, flip_tb, false))
	# Bottom wall / south (+Z)
	if b.bottom > 0 and not _solid(map, x, y + 1, z):
		_face(verts, normals, uvs, indices, atlas, b.bottom, Vector3.BACK,
			Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1),
			_uv(0, flip_tb, false))


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
