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
## Block rotation is applied to lid UVs and GTA1's flip_left_right bit mirrors the
## E/W (left/right) wall + flat-panel tiles, so banners stored as a flipped half-
## tile (e.g. "General HOSPITAL", the DOCKS signs) read the right way round.
## Calibrated visually; see _emit_cube for why N/S faces are left unflipped.

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
			# Bedrock floor: close street-level holes (no block at z=0 or z=1) so the
			# car can't drive into a gap and fall through the world below the road.
			_emit_bedrock(verts, normals, uvs, indices, atlas, style, map, x, y)

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


## Street level (stack z of the common road) and the filler tile for the bedrock.
## BEDROCK_LID is the pavement/sidewalk tile (e.g. the one under (77,63)); the gaps
## sit mostly in building footprints, so pavement blends better than road.
const STREET_Z := 1
const BEDROCK_LID := 8


## Bedrock floor: some GTA1 columns have nothing at street level — the lowest block
## sits at z>=2 (often inside building footprints), leaving a hole the car can drive
## into and fall through. Lay a single floor quad at street level (the z=1 surface,
## Y=2) so the ground reads as continuous and gives the car something to rest on.
## Skipped where a real block already occupies street level (z=1), or sits BELOW it
## (z=0 — a river/canal/low ground we must not cover): only true voids are filled.
static func _emit_bedrock(verts, normals, uvs, indices, atlas: TileAtlas, style: GTA1Style,
		map: GTA1Map, x: int, y: int) -> void:
	var b0 := map.get_block(x, y, 0)
	if b0 != null and not b0.is_empty():
		return
	var b1 := map.get_block(x, y, STREET_Z)
	if b1 != null and not b1.is_empty():
		return
	var x0 := float(x)
	var x1 := x0 + BLOCK
	var z0 := float(y)
	var z1 := z0 + BLOCK
	var yl := float(STREET_Z) + BLOCK   # the z=1 lid surface, world Y = 2
	_face(verts, normals, uvs, indices, atlas, style.num_side + BEDROCK_LID, Vector3.UP,
		Vector3(x0, yl, z1), Vector3(x1, yl, z1), Vector3(x1, yl, z0), Vector3(x0, yl, z0))


## Solid collision for the city: a ConcavePolygonShape3D taken straight from the
## rendered city mesh, so the car collides with EXACTLY what it sees.
##
## Why not a heightfield, and why not a hand-built geometry trimesh:
##   * A heightfield stores ONE height per cell, so at an overpass it can only pick
##     the deck OR the road below it — the car was forced over every bridge.
##   * A trimesh built from raw block GEOMETRY walls every solid cube. But GTA1
##     overpass decks are full cubes with a lid and NO side textures (btype road/
##     pavement): you are meant to pass under them. Geometry walls block that, even
##     though nothing is drawn there.
## The render mesh already encodes the right rule — GTA1's "collide with what's
## textured": it draws walls only where a side tile exists (buildings, fences,
## kerb skirts) and always draws lids (roads, ramps, deck tops, the road under a
## deck). So the deck is a thin drivable lid with no walls — the car drives under
## it — while buildings keep their walls. Deriving collision from that mesh makes
## the two match by construction, and reuses geometry we already built (no second
## pass over 256x256x6 cells).
##
## backface_collision = true: a ConcavePolygonShape3D is one-sided by default, so a
## lid wound normal-down would let the car fall straight through its back face (the
## old "trimesh tunnels" reputation). The mesh mixes windings (the slope reflection
## flips some, CULL_DISABLED draws both), so two-sided is the only robust choice.
static func build_collision(mesh: ArrayMesh) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CityCollision"
	if mesh == null or mesh.get_surface_count() == 0:
		push_warning("MapBuilder: no mesh to build collision from")
		return body
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


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
			# The flat sits over a ramp (the slope one level down). Follow the slope's
			# shape but raised one unit (its own cell), so a girder/deck stays one above
			# the ramp road just as it does on the flat sections, not painted onto it.
			var sf: PackedVector3Array = SlopeData.faces[below.slope_type()][0]
			var o := Vector3(fx, fy + FLAT_EPS, fz)
			var nrm := (sf[1] - sf[0]).cross(sf[2] - sf[0]).normalized()
			var rot := b.rotation()
			var luv := _uv(rot, rot % 2 == 1, rot % 2 == 0)
			if nrm.y < 0.0:
				# Reverse winding (and UVs) together with the normal so the front
				# face matches it — same GPU-consistency fix as in _emit_slope.
				nrm = -nrm
				_face(verts, normals, uvs, indices, atlas, slot, nrm,
					o + sf[0], o + sf[3], o + sf[2], o + sf[1], [luv[0], luv[3], luv[2], luv[1]])
			else:
				_face(verts, normals, uvs, indices, atlas, slot, nrm,
					o + sf[0], o + sf[1], o + sf[2], o + sf[3], luv)
		else:
			# Draw the lid at the cell TOP (z+1), like a normal block's lid: GTA1
			# stores raised structures (El tracks, bridge decks, girder gratings) as
			# flat blocks one level above the road, with the structure as the lid, and
			# their lid is the RAISED rail surface — it belongs at the cell TOP (z+1),
			# level with the adjacent platform cube, so the car drives underneath. The
			# old base-draw printed those structures onto the road and dropped decks a unit
			# low. Lane markings live in the road tile, not separate flats, so they
				# don't float; a decal over a ramp is the exception (slope case above).
			var yl := y1 - FLAT_EPS
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
			Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0),
			FLIP_U_UV if b.flip_top_bottom() else BASE_UV)
	var xl: int = b.left if b.left > 0 else b.right   # fence on the -X (west) edge
	if xl > 0:
		_face(verts, normals, uvs, indices, atlas, xl, Vector3.LEFT,
			Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), BASE_UV if b.flip_left_right() else FLIP_U_UV)


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
		var slot := (style.num_side + byte) if fi == 0 else byte
		var luv: Array = lid_uv if fi == 0 else BASE_UV
		if nrm.dot(face_centre - (origin + Vector3(0.5, 0.5, 0.5))) < 0.0:
			# Outward normal disagrees with the winding. Flipping the normal alone
			# leaves the geometric front face wrong, which CULL_DISABLED two-sided
			# lighting resolves differently per GPU (slopes bright on some, dark on
			# others). Reverse the winding (and per-vertex UVs) to match the normal.
			nrm = -nrm
			_face(verts, normals, uvs, indices, atlas, slot, nrm,
				a, d, c, bb, [luv[0], luv[3], luv[2], luv[1]])
		else:
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
	# GTA1's two face-flip bits each mirror one wall pair horizontally. The E/W
	# (left/right) faces are wound with their U axis reversed, so a non-flipped tile
	# already needs FLIP_U_UV to read right and flip_left_right toggles back to
	# BASE_UV (this un-reverses banners like "General HOSPITAL"). The N/S (top/bottom)
	# faces are wound the other way (U already correct): a non-flipped tile reads
	# straight from BASE_UV and flip_top_bottom mirrors it — which is how a sign's
	# back-facing copy (a "← DOCKS" gantry facing the other way) is stored, so without
	# it those come out reversed / halves-swapped. (Block rotation stays lid-only.)
	var lr_uv: Array = BASE_UV if b.flip_left_right() else FLIP_U_UV
	var tb_uv: Array = FLIP_U_UV if b.flip_top_bottom() else BASE_UV
	# Left (-X)
	if b.left > 0 and not _occludes(map, x - 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.left, Vector3.LEFT,
			Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), lr_uv)
	# Right (+X)
	if b.right > 0 and not _occludes(map, x + 1, y, z):
		_face(verts, normals, uvs, indices, atlas, b.right, Vector3.RIGHT,
			Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), lr_uv)
	# Top wall / north (-Z)
	if b.top > 0 and not _occludes(map, x, y - 1, z):
		_face(verts, normals, uvs, indices, atlas, b.top, Vector3.FORWARD,
			Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), tb_uv)
	# Bottom wall / south (+Z)
	if b.bottom > 0 and not _occludes(map, x, y + 1, z):
		_face(verts, normals, uvs, indices, atlas, b.bottom, Vector3.BACK,
			Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), tb_uv)


## Local UV corners matching the a->b->c->d vertex winding (OpenGTA lidTex order).
const BASE_UV: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
## BASE_UV mirrored horizontally (u -> 1-u, v kept). Every wall quad maps u to its
## horizontal axis and v to vertical, so this is the GTA1 face flip: a left/right
## wall flips when flip_left_right is set, a top/bottom wall when flip_top_bottom
## is set. Without it, tiles the data marks as flipped (banners, road signs) render
## mirrored — text comes out reversed / "halves swapped".
const FLIP_U_UV: Array[Vector2] = [Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)]


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
