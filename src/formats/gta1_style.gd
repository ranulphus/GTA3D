class_name GTA1Style
extends RefCounted

## Parser for the GTA1 ".G24" 24-bit style/graphics format (STYLE*.G24).
## Ported from OpenGTA's read_g24.cpp + read_gry.cpp (tile de-paging) and DMA's
## cds.doc. Focus here is the city tiles + palettes needed to texture the world;
## sprites / car / object info sizes are read for correct offsets but not yet
## fully decoded (that arrives with the car phase — see docs/ROADMAP.md).
##
## All values little-endian. 8-bit paletted tiles become RGBA via a CLUT.

const VERSION_G24 := 336
const HEADER_SIZE := 64
const TILE_W := 64
const TILE_H := 64
const TILE_BYTES := 4096          # 64*64, one byte (palette index) per pixel
const STRIP_BYTES := 16384        # 256*64: a strip holds 4 tiles side-by-side
const CLUT_PAGE := 65536          # 64 interleaved CLUTs of 256 colors

enum TileKind { SIDE, LID, AUX }

var version := 0
var num_side := 0
var num_lid := 0
var num_aux := 0

# Raw regions kept as-is; decoded lazily per tile.
var _raw_tiles := PackedByteArray()   # side|lid|aux (+aux trailing pad)
var _raw_clut := PackedByteArray()     # paged CLUTs (B,G,R,pad per color)
var _pal_index := PackedInt32Array()   # u16: physical palette -> CLUT number


static func load_file(path: String) -> GTA1Style:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		push_error("GTA1Style: cannot read '%s'" % path)
		return null
	return parse(data)


static func parse(data: PackedByteArray) -> GTA1Style:
	var s := GTA1Style.new()
	var r := ByteReader.new(data)

	s.version = r.u32()
	if s.version != VERSION_G24:
		push_error("GTA1Style: version %d, expected %d (is this a .G24 file?)" % [s.version, VERSION_G24])
		return null

	var side_size := r.u32()
	var lid_size := r.u32()
	var aux_size := r.u32()
	var anim_size := r.u32()
	var clut_size := r.u32()
	var _tileclut_size := r.u32()
	var _spriteclut_size := r.u32()
	var _newcarclut_size := r.u32()
	var _fontclut_size := r.u32()
	var pal_index_size := r.u32()
	var _object_info_size := r.u32()
	var _car_info_size := r.u32()
	var _sprite_info_size := r.u32()
	var _sprite_graphics_size := r.u32()
	var _sprite_number_size := r.u32()

	s.num_side = side_size / TILE_BYTES
	s.num_lid = lid_size / TILE_BYTES
	s.num_aux = aux_size / TILE_BYTES

	# Tiles are padded so the total block count is a multiple of 4.
	var total_blocks := (side_size + lid_size + aux_size) / TILE_BYTES
	var rem := total_blocks % 4
	var aux_trail := 0 if rem == 0 else (4 - rem) * TILE_BYTES
	var tiles_len := side_size + lid_size + aux_size + aux_trail

	# CLUTs are page-aligned to 64 KB.
	var paged_clut := clut_size
	if clut_size % CLUT_PAGE != 0:
		paged_clut += CLUT_PAGE - (clut_size % CLUT_PAGE)

	var tiles_start := HEADER_SIZE
	var clut_start := tiles_start + tiles_len + anim_size
	var pal_index_start := clut_start + paged_clut

	s._raw_tiles = data.slice(tiles_start, tiles_start + tiles_len)
	s._raw_clut = data.slice(clut_start, clut_start + paged_clut)

	var pal_count := pal_index_size / 2
	s._pal_index.resize(pal_count)
	r.seek(pal_index_start)
	for i in pal_count:
		s._pal_index[i] = r.u16()

	return s


func tile_count() -> int:
	return num_side + num_lid + num_aux


## Decode a tile by its global index across the concatenated side|lid|aux sets
## (side = [0, num_side), lid = [num_side, num_side+num_lid), aux = rest).
func get_tile_image_global(g: int) -> Image:
	if g < num_side:
		return get_tile_image(TileKind.SIDE, g)
	if g < num_side + num_lid:
		return get_tile_image(TileKind.LID, g - num_side)
	return get_tile_image(TileKind.AUX, g - num_side - num_lid)


## Decode one tile to an RGBA8 64x64 Image. `kind` selects the face category,
## `idx` is the 0-based index within that category (as referenced by block faces).
func get_tile_image(kind: TileKind, idx: int) -> Image:
	var g := _global_index(kind, idx)
	var clut := _clut_index(kind, idx)
	return _decode(g, clut)


## Global tile index across the concatenated side|lid|aux regions.
func _global_index(kind: TileKind, idx: int) -> int:
	match kind:
		TileKind.SIDE: return idx
		TileKind.LID:  return num_side + idx
		TileKind.AUX:  return num_side + num_lid + idx
	return idx


## CLUT number for a tile, via the palette-index table. (The ×4 stride and any
## ±1 offset are calibrated against real data in the dump tool.)
func _clut_index(kind: TileKind, idx: int) -> int:
	var phys := _global_index(kind, idx)
	var i := phys * 4
	if i < 0 or i >= _pal_index.size():
		return 0
	return _pal_index[i]


func _decode(g: int, clut_idx: int) -> Image:
	var px := PackedByteArray()
	px.resize(TILE_W * TILE_H * 4)
	var strip := g / 4
	var col := (g % 4) * TILE_W
	var clut_off := CLUT_PAGE * (clut_idx / 64) + 4 * (clut_idx % 64)
	var o := 0
	for row in TILE_H:
		var src := strip * STRIP_BYTES + row * 256 + col
		for c in TILE_W:
			var p := _raw_tiles[src + c] if src + c < _raw_tiles.size() else 0
			var coff := clut_off + p * 256
			# CLUT stores B, G, R (, pad). Palette index 0 == transparent.
			px[o + 0] = _raw_clut[coff + 2] if coff + 2 < _raw_clut.size() else 0
			px[o + 1] = _raw_clut[coff + 1] if coff + 1 < _raw_clut.size() else 0
			px[o + 2] = _raw_clut[coff + 0] if coff < _raw_clut.size() else 0
			px[o + 3] = 0 if p == 0 else 255
			o += 4
	return Image.create_from_data(TILE_W, TILE_H, false, Image.FORMAT_RGBA8, px)
