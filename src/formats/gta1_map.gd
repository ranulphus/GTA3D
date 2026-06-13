class_name GTA1Map
extends RefCounted

## Parser for the GTA1 ".CMP" compressed-map format (e.g. NYC.CMP, SANB.CMP,
## MIAMI.CMP). Ported from OpenGTA's read_cmp.cpp, which in turn implements DMA
## Design's "CityScape Data Structure" (cds.doc).
##
## File layout:
##   [0]   header           : 28 bytes (see _HEADER_SIZE)
##   [28]  base grid        : 256*256 u32 byte-offsets into the column array
##   [..]  columns          : column_size bytes of u16 words
##   [..]  blocks           : block_size bytes, 8 bytes per block
##   [..]  objects          : object_pos_size bytes, 14 bytes per object
##   [..]  routes           : route_size bytes      (not parsed yet)
##   [..]  locations        : (derived)             (not parsed yet)
##   [..]  navdata          : nav_data_size bytes   (not parsed yet)
##
## A column decodes as: word0 = number of blocks N in this map cell, followed by
## N u16 indices into the global block array. Blocks are stacked from the ground
## up (z = 0 at the bottom). NOTE: vertical anchoring vs. the original's 6-high
## column is the one thing to confirm against a real map once data files exist.

const DIM := 256
const _HEADER_SIZE := 28
const _BASE_SIZE := DIM * DIM * 4  # 262144
const _BLOCK_SIZE := 8
const _OBJECT_SIZE := 14

var version: int = 0
var style_number: int = 0
var sample_number: int = 0

## base[x * DIM + y] = byte offset into `columns` for map cell (x, y).
var base := PackedInt32Array()
## Flat array of u16 column words.
var columns := PackedInt32Array()
## All unique blocks referenced by columns.
var blocks: Array[GTA1Block] = []
## Object spawns: Array of { x, y, z, type, remap, rotation, pitch, roll }.
var objects: Array[Dictionary] = []


static func load_file(path: String) -> GTA1Map:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		push_error("GTA1Map: could not read '%s' (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	return parse(data)


static func parse(data: PackedByteArray) -> GTA1Map:
	var m := GTA1Map.new()
	var r := ByteReader.new(data)

	# --- header ---
	m.version = r.u32()
	m.style_number = r.u8()
	m.sample_number = r.u8()
	var _reserved := r.u16()
	var _route_size := r.u32()
	var object_pos_size := r.u32()
	var column_size := r.u32()
	var block_size := r.u32()
	var _nav_data_size := r.u32()

	# --- base grid (read in y-outer, x-inner order; stored as base[x*DIM+y]) ---
	r.seek(_HEADER_SIZE)
	m.base.resize(DIM * DIM)
	for y in DIM:
		for x in DIM:
			m.base[x * DIM + y] = r.u32()

	# --- columns ---
	r.seek(_HEADER_SIZE + _BASE_SIZE)
	var word_count: int = column_size / 2
	m.columns.resize(word_count)
	for i in word_count:
		m.columns[i] = r.u16()

	# --- blocks ---
	r.seek(_HEADER_SIZE + _BASE_SIZE + column_size)
	var block_count: int = block_size / _BLOCK_SIZE
	m.blocks.resize(block_count)
	for i in block_count:
		var b := GTA1Block.new()
		b.type_map = r.u16()
		b.type_map_ext = r.u8()
		b.left = r.u8()
		b.right = r.u8()
		b.top = r.u8()
		b.bottom = r.u8()
		b.lid = r.u8()
		m.blocks[i] = b

	# --- objects ---
	r.seek(_HEADER_SIZE + _BASE_SIZE + column_size + block_size)
	var object_count: int = object_pos_size / _OBJECT_SIZE
	for i in object_count:
		m.objects.append({
			"x": r.u16(), "y": r.u16(), "z": r.u16(),
			"type": r.u8(), "remap": r.u8(),
			"rotation": r.u16(), "pitch": r.u16(), "roll": r.u16(),
		})

	return m


## Columns are a fixed 6 high. The first column word is the "offset" (number of
## empty/air levels), so the real block count is 6 - offset. The block words are
## stored top-to-bottom, hence the (N - z) indexing below. This matches OpenGTA's
## getBlockAtNew / getNumBlocksAtNew (the variant its renderer actually uses).
const COLUMN_HEIGHT := 6


## Number of stacked blocks at map cell (x, y) (0 = empty, e.g. open water/sky).
func get_num_blocks(x: int, y: int) -> int:
	var wi: int = base[x * DIM + y] >> 1
	return maxi(0, COLUMN_HEIGHT - columns[wi])


## Block at (x, y) stack level z (0 = ground), or null if out of range.
func get_block(x: int, y: int, z: int) -> GTA1Block:
	var wi: int = base[x * DIM + y] >> 1
	var n: int = COLUMN_HEIGHT - columns[wi]
	if z < 0 or z >= n:
		return null
	var block_id: int = columns[wi + (n - z)]
	return blocks[block_id]


## World Y of the drivable/visible surface at (x, y): the top of the highest
## SOLID (non-flat, non-empty) block. Columns are mostly air with content at
## scattered levels, so this is NOT the same as get_num_blocks. Flat decals
## (overpass markings etc.) are ignored so we get the real ground/road/roof.
func get_surface_y(x: int, y: int) -> int:
	var n: int = get_num_blocks(x, y)
	for z in range(n - 1, -1, -1):
		var b := get_block(x, y, z)
		if b != null and not b.is_empty() and not b.is_flat():
			return z + 1
	# Fallback: highest non-empty block even if flat.
	for z in range(n - 1, -1, -1):
		var b := get_block(x, y, z)
		if b != null and not b.is_empty():
			return z + 1
	return 0
