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


## Solid collision for the city as a ConcavePolygonShape3D (trimesh).
##
## A heightfield stores ONE height per cell, so at an overpass it can only pick the
## deck OR the road below it — the car was forced over every bridge and could never
## drive under. A trimesh has no such limit: a cell can carry both the under-road
## surface and the deck above it, so the car drives under bridges / building
## overhangs as well as over them.
##
## We emit GEOMETRY, not the visual faces: per solid cube, its top (lid) as a
## drivable floor unless a full cube directly above buries it, plus the side walls
## that face open space so the car bumps buildings, kerbs and the sea edge. Road
## cubes carry no side TEXTURES but are still solid, so walls are decided by
## geometry (is the neighbour a full cube/ramp?) not by the texture bytes. Ramps
## contribute their sloped lid so the car can climb between levels. Flat decals
## (paint, fences) and downward/interior faces are skipped.
static func build_collision(map: GTA1Map) -> StaticBody3D:
	var dim := GTA1Map.DIM
	var h := GTA1Map.COLUMN_HEIGHT
	# Occupancy grid: 0 = empty/flat (no side fill), 1 = ramp, 2 = full cube. Built
	# once so the emit pass culls lids/walls with O(1) array reads instead of
	# re-fetching neighbour blocks (halves the build time on a full city).
	var occ := PackedByteArray()
	occ.resize(dim * dim * h)
	for x in dim:
		for y in dim:
			var ci := (x * dim + y) * h
			var n := map.get_num_blocks(x, y)
			for z in n:
				var b := map.get_block(x, y, z)
				if b == null or b.is_empty() or b.is_flat():
					continue
				occ[ci + z] = 1 if b.slope_type() != 0 else 2

	var faces := PackedVector3Array()
	for x in dim:
		var xrow := x * dim
		for y in dim:
			var ci := (xrow + y) * h
			var n := map.get_num_blocks(x, y)
			for z in n:
				var v := occ[ci + z]
				if v == 0:
					continue
				if v == 1:
					_collide_slope(faces, map.get_block(x, y, z), x, y, z)
					continue
				var x0 := float(x)
				var x1 := x0 + BLOCK
				var y0 := float(z)
				var y1 := y0 + BLOCK
				var z0 := float(y)
				var z1 := z0 + BLOCK
				# Lid (drivable top) unless a full cube directly above buries it.
				if z + 1 >= h or occ[ci + z + 1] != 2:
					_cquad(faces, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0))
				# Side wall wherever the neighbour at this level is open (occ 0): a
				# cube or ramp neighbour (occ 1/2) already meets the edge, so skip it.
				if x == 0 or occ[((x - 1) * dim + y) * h + z] == 0:
					_cquad(faces, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1))
				if x == dim - 1 or occ[((x + 1) * dim + y) * h + z] == 0:
					_cquad(faces, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0))
				if y == 0 or occ[(xrow + y - 1) * h + z] == 0:
					_cquad(faces, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0))
				if y == dim - 1 or occ[(xrow + y + 1) * h + z] == 0:
					_cquad(faces, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1))

	var body := StaticBody3D.new()
	body.name = "CityCollision"
	if faces.is_empty():
		push_warning("MapBuilder: no collision geometry produced")
		return body
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	# Collide from BOTH sides. A ConcavePolygonShape3D is one-sided by default, so a
	# floor triangle wound normal-down would let a car fall straight through its back
	# face (the old "trimesh tunnels" reputation). Our lids/ramps mix windings (the
	# slope reflection flips some), so two-sided is the only robust choice for a thin
	# city shell — and it makes every wall block from inside and out.
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


## Collision for a ramp: just its sloped lid, the surface the car drives on to
## climb between levels. Its sides are left open (the lid deflects the car); a wall
## there risks blocking the ramp/deck join.
static func _collide_slope(faces: PackedVector3Array, b: GTA1Block, x: int, y: int, z: int) -> void:
	var sf: PackedVector3Array = SlopeData.faces[b.slope_type()][0]
	var o := Vector3(float(x), float(z), float(y))
	_cquad(faces, o + sf[0], o + sf[1], o + sf[2], o + sf[3])


static func _ctri(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	faces.push_back(a)
	faces.push_back(b)
	faces.push_back(c)


## Two triangles for the collision quad a->b->c->d. Winding doesn't matter here
## because the shape uses backface_collision (it collides from both sides).
static func _cquad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_ctri(faces, a, b, c)
	_ctri(faces, a, c, d)


static func _emit_block(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, b: GTA1Block, x: int, y: int, z: int, fx: float, fy: float, fz: float) -> void:
	if b.is_flat():
		var below := map.get_block(x, y, z - 1) if z > 0 else null
		_emit_flat(verts, normals, uvs, indices, atlas, style, b, fx, fy, fz, below)
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
		b: GTA1Block, fx: float, fy: float, fz: float, below: GTA1Block = null) -> void:
	var x0 := fx
	var x1 := fx + BLOCK
	var y0 := fy
	var y1 := fy + BLOCK
	var z0 := fz
	var z1 := fz + BLOCK

	if b.lid > 0:
		var slot := style.num_side + b.lid
		if below != null and below.slope_type() != 0:
			# The decal marks a sloped road one level down (z-1); lay it on the slope
			# so the markings follow the ramp instead of floating flat at its top edge
			# (which read as the road having "fallen" a unit below the marking).
			var sf: PackedVector3Array = SlopeData.faces[below.slope_type()][0]
			var o := Vector3(fx, fy - BLOCK + FLAT_EPS, fz)
			var nrm := (sf[1] - sf[0]).cross(sf[2] - sf[0]).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			var rot := b.rotation()
			_face(verts, normals, uvs, indices, atlas, slot, nrm,
				o + sf[0], o + sf[1], o + sf[2], o + sf[3],
				_uv(rot, rot % 2 == 1, rot % 2 == 0))
		else:
			var yl := y0 + FLAT_EPS  # lay the decal on the surface below, not floating on top
			_face(verts, normals, uvs, indices, atlas, slot, Vector3.UP,
				Vector3(x0, yl, z1), Vector3(x1, yl, z1), Vector3(x1, yl, z0), Vector3(x0, yl, z0),
				_uv(b.rotation(), false, false))

	# A flat block's side bytes are a thin fence/railing/wall sitting ON a cell
	# boundary, not spanning the cell. Per OpenGTA, only the top (-Z) and left (-X)
	# bytes are drawn, each as a single double-sided panel at the cell's z=0 / x=0
	# edge (the +Z/+X faces just back the same panel). Drawing both edges doubled
	# the fence a cell apart; centring it left it hovering half a cell out over the
	# water. The edge IS the boundary. (Fall back to bottom/right for the tile if a
	# block only carries those, but keep the panel on the z0/x0 boundary.)
	var zt: int = b.top if b.top > 0 else b.bottom   # fence on the -Z (north) edge
	if zt > 0:
		_face(verts, normals, uvs, indices, atlas, zt, Vector3.FORWARD,
			Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0))
	var xl: int = b.left if b.left > 0 else b.right   # fence on the -X (west) edge
	if xl > 0:
		_face(verts, normals, uvs, indices, atlas, xl, Vector3.LEFT,
			Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1))


## Slope/ramp blocks: emit the exact per-face geometry for this slope type (1-44)
## from SlopeData. Faces whose quad collapses to a line are skipped.
static func _emit_slope(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		b: GTA1Block, fx: float, fy: float, fz: float, st: int) -> void:
	var sf: Array = SlopeData.faces[st]
	var origin := Vector3(fx, fy, fz)
	# face order: LID, NORTH(+Z), SOUTH(-Z), WEST(-X), EAST(+X). Only the lid is
	# rotated; walls use the tile as-is (flips disabled — see _emit_cube).
	# The SlopeData Z-reflection mirrors the lid in world-Z. In TILE space that's a
	# V-flip when the tile is unrotated/180 (rot 0,2) but a U-flip when it's turned
	# 90/270 (rot 1,3), because the rotation swaps which tile axis world-Z follows.
	# Apply the matching flip so ramp road markings line up with the flat road.
	var bytes := [b.lid, b.bottom, b.top, b.left, b.right]
	var rot := b.rotation()
	var lid_uv: Array = _uv(rot, rot % 2 == 1, rot % 2 == 0)
	for fi in 5:
		var byte: int = bytes[fi]
		if byte <= 0:
			continue
		# Diagonal slopes 41-44 each have one side replaced by the diagonal lid, so
		# OpenGTA omits that square side face; drawing it leaves a spurious vertical
		# quad standing across the diagonal (very visible on exposed bridge edges).
		# fi 1=bottom,2=top,3=left,4=right.
		if (fi == 1 and st == 41) or (fi == 2 and st == 42) \
				or (fi == 3 and st == 44) or (fi == 4 and st == 43):
			continue
		var quad: PackedVector3Array = sf[fi]
		var a := origin + quad[0]
		var bb := origin + quad[1]
		var c := origin + quad[2]
		var d := origin + quad[3]
		var nrm := (bb - a).cross(c - a)
		if nrm.length() < 0.0001:
			continue  # degenerate (collapsed) face
		nrm = nrm.normalized()
		# The Z-reflection in SlopeData flips the winding (and thus the raw normal),
		# so orient each normal to face away from the cell centre — independent of
		# winding, and correct for lids (up) and walls (outward) alike.
		var face_centre := (a + bb + c + d) * 0.25
		if nrm.dot(face_centre - (origin + Vector3(0.5, 0.5, 0.5))) < 0.0:
			nrm = -nrm
		var slot := (style.num_side + byte) if fi == 0 else byte
		var luv: Array = lid_uv if fi == 0 else BASE_UV
		_face(verts, normals, uvs, indices, atlas, slot, nrm, a, bb, c, d, luv)


## Vertical "skirt" walls that close the 1-unit gap where one flat ground cell
## steps down to a flat neighbour one level lower (a kerb, a sunken plaza edge).
## Textured with the cell's own surface (lid) tile so it blends with the ground.
##
## Deliberately narrow: only flat cube ground (slope_type 0, no side textures)
## skirts, only against a flat neighbour exactly one unit lower. Ramps already
## bridge heights with their own geometry, and tall drops (bridge decks over
## water/road) used to get filled with metre-tall ROAD-textured walls that read
## as vertical "fences" — so neither is skirted now.
static func _emit_skirt(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, x: int, y: int) -> void:
	var sy := map.get_surface_y(x, y)
	if sy <= 0:
		return
	var sb := map.get_block(x, y, sy - 1)
	if sb == null or sb.lid <= 0:
		return
	# Skip walled blocks (buildings/fences already have real walls) and ramps
	# (their slope geometry already connects the heights).
	if sb.left != 0 or sb.right != 0 or sb.top != 0 or sb.bottom != 0:
		return
	if sb.slope_type() != 0:
		return
	# Skip cells that carry a block (a girder walkway / bridge deck) ABOVE their
	# solid surface: that's an elevated overpass, and skirting its edge walls off
	# the road running underneath it.
	for z in range(sy, map.get_num_blocks(x, y)):
		var above := map.get_block(x, y, z)
		if above != null and not above.is_empty():
			return
	var slot := style.num_side + sb.lid
	var x0 := float(x)
	var x1 := x0 + BLOCK
	var z0 := float(y)
	var z1 := z0 + BLOCK
	var hi := float(sy)
	var lo := float(sy - 1)

	if _flat_step_down(map, x - 1, y, sy):
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.LEFT,
			Vector3(x0, lo, z1), Vector3(x0, lo, z0), Vector3(x0, hi, z0), Vector3(x0, hi, z1))
	if _flat_step_down(map, x + 1, y, sy):
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.RIGHT,
			Vector3(x1, lo, z0), Vector3(x1, lo, z1), Vector3(x1, hi, z1), Vector3(x1, hi, z0))
	if _flat_step_down(map, x, y - 1, sy):
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.FORWARD,
			Vector3(x1, lo, z0), Vector3(x0, lo, z0), Vector3(x0, hi, z0), Vector3(x1, hi, z0))
	if _flat_step_down(map, x, y + 1, sy):
		_face(verts, normals, uvs, indices, atlas, slot, Vector3.BACK,
			Vector3(x0, lo, z1), Vector3(x1, lo, z1), Vector3(x1, hi, z1), Vector3(x0, hi, z1))


## True if neighbour (nx,ny) is flat ground exactly one unit below sy — the only
## case worth closing with a skirt. A ramp neighbour returns false (the slope
## geometry already meets the gap), and so does any drop of two or more units.
static func _flat_step_down(map: GTA1Map, nx: int, ny: int, sy: int) -> bool:
	if nx < 0 or ny < 0 or nx >= GTA1Map.DIM or ny >= GTA1Map.DIM:
		return false
	var nsy := map.get_surface_y(nx, ny)
	if nsy != sy - 1:
		return false
	if nsy > 0:
		var nb := map.get_block(nx, ny, nsy - 1)
		if nb != null and nb.slope_type() != 0:
			return false
	return true


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
	# Always drawn (never culled by a block above): a road running UNDER an
	# overpass deck has its lid covered from above, but with no side textures the
	# road cube would otherwise be invisible and you'd see straight through it to
	# the sea. Only ~300 lids are ever covered, so this is essentially free.
	if b.lid > 0:
		_face(verts, normals, uvs, indices, atlas, style.num_side + b.lid, Vector3.UP,
			Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0),
			_uv(b.rotation(), false, false))
	# Left (-X)
	if b.left > 0 and not _occludes(map, x - 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.left, Vector3.LEFT,
			Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	# Right (+X)
	if b.right > 0 and not _occludes(map, x + 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.right, Vector3.RIGHT,
			Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0))
	# Top wall / north (-Z)
	if b.top > 0 and not _occludes(map, x, y - 1, z):
		_face(verts, normals, uvs, indices, atlas, b.top, Vector3.FORWARD,
			Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0))
	# Bottom wall / south (+Z)
	if b.bottom > 0 and not _occludes(map, x, y + 1, z):
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


## Does the block at (x,y,z) FULLY hide the shared face of its neighbour? Only a
## solid full cube does. A flat decal is paper-thin and a slope only partly fills
## its cell, so both leave the face behind them exposed — culling against them was
## punching thousands of holes in walls and roofs. Below ground occludes (no
## downward faces are wanted); out of bounds does not.
static func _occludes(map: GTA1Map, x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or x >= GTA1Map.DIM or y >= GTA1Map.DIM:
		return false
	if z < 0:
		return true
	if z >= map.get_num_blocks(x, y):
		return false
	var b := map.get_block(x, y, z)
	return b != null and not b.is_empty() and not b.is_flat() and b.slope_type() == 0
