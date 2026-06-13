class_name GTA1Block
extends RefCounted

## One cube ("block") of the GTA1 city grid. The city is a 256x256 grid of
## columns; each column is a vertical stack of up to 6 of these blocks.
##
## Layout on disk (8 bytes), per OpenGTA read_cmp.cpp / DMA cds.doc:
##   u16 type_map      -- packed flags: movement, block type, slope, rotation
##   u8  type_map_ext  -- packed flags: traffic/rail, remap index, face flips
##   u8  left, right, top, bottom, lid  -- tile (texture) index for each face
##
## The 5 faces are the 4 side walls plus the "lid" (the top face you see from
## above in the original game). A face value of 0 means "no face" (empty/air).

var type_map: int = 0
var type_map_ext: int = 0
var left: int = 0
var right: int = 0
var top: int = 0
var bottom: int = 0
var lid: int = 0

# --- type_map bitfield (see opengta.h Map::BlockInfo) ---

## Movement permissions across each edge of the block.
func up_ok() -> bool:    return (type_map & 1) != 0
func down_ok() -> bool:  return (type_map & 2) != 0
func left_ok() -> bool:  return (type_map & 4) != 0
func right_ok() -> bool: return (type_map & 8) != 0

## Surface/material category 0..7 (air, road, pavement, field, building, ...).
func block_type() -> int:
	return (type_map >> 4) & 0x7

## A "flat" block is drawn as a flat decal (e.g. road markings, doors painted on
## a wall) rather than a solid cube face.
func is_flat() -> bool:
	return (type_map & 128) != 0

## Slope/ramp geometry id, 0..44. 0 == a normal full cube; the rest select one of
## the predefined ramp shapes (hills, road inclines, diagonal roofs, etc.).
func slope_type() -> int:
	return (type_map >> 8) & 0x3F

## Block rotation, 0..3 -> 0/90/180/270 degrees clockwise.
func rotation() -> int:
	return (type_map >> 14) & 0x3

# --- type_map_ext bitfield ---

func traffic_lights() -> bool: return (type_map_ext & 1) != 0
func railway() -> bool:        return (type_map_ext & 128) != 0

## Palette remap index applied to this block's tiles, 0..3.
func remap_index() -> int:
	return (type_map_ext >> 3) & 0x3

func flip_top_bottom() -> bool: return (type_map_ext & 32) != 0
func flip_left_right() -> bool: return (type_map_ext & 64) != 0

## True when this block contributes no visible geometry at all.
func is_empty() -> bool:
	return left == 0 and right == 0 and top == 0 and bottom == 0 and lid == 0
