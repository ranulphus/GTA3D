# GTA1 file formats (reference)

Grounded in the community [OpenGTA](https://github.com/madebr/OpenGTA) source
(`read_cmp.cpp`, `opengta.h`) and DMA Design's *CityScape Data Structure*
(`cds.doc`). All multi-byte values are **little-endian**.

## The world is already 3D

A GTA1 city is a **256 × 256 grid of columns**. Each column is a vertical stack
of up to **6 cubes ("blocks")**. Every block carries 5 textured faces (4 side
walls + a top "lid") plus slope/rotation flags. The original engine drew this
grid with an orthographic top-down camera; we extrude it and use a perspective
camera instead. No geometry needs to be invented — the height data is in the map.

## `.CMP` — compressed map

| Offset | Size | Field |
|-------:|-----:|-------|
| 0 | 4 | version code (u32) |
| 4 | 1 | style number (u8) |
| 5 | 1 | sample number (u8) |
| 6 | 2 | reserved (u16) |
| 8 | 4 | route size (u32) |
| 12 | 4 | object-position size (u32) |
| 16 | 4 | column size (u32) |
| 20 | 4 | block size (u32) |
| 24 | 4 | navdata size (u32) |
| 28 | 256·256·4 | **base grid**: u32 byte-offset into the column array, per (x,y) |
| … | column size | **columns**: u16 words |
| … | block size | **blocks**: 8 bytes each |
| … | object size | **objects**: 14 bytes each |
| … | route size | routes (not parsed yet) |
| … | navdata size | named sectors (not parsed yet) |

The base grid is stored in `y`-outer, `x`-inner order.

### Column decoding

`base[x][y]` is a **byte** offset; divide by 2 for a word index into `columns`.
Columns are a fixed **6** high.

- `columns[base[x][y]/2]` = **offset**, the number of empty/air levels.
- Real block count **N = 6 − offset**.
- The next **N** words are block indices, stored **top → bottom**, so the block
  at stack level `z` (0 = ground) is `columns[base/2 + (N − z)]`.

> This matches OpenGTA's `getBlockAtNew` / `getNumBlocksAtNew` — the variant its
> renderer actually uses. (The legacy `getBlockAt`, which treats the first word
> as a count, is wrong: it makes tall buildings — offset≈0 — decode to ~0 blocks
> and vanish, and flat cells — offset=5 — decode to 5 garbage blocks.)

### Block record (8 bytes)

| Size | Field |
|-----:|-------|
| 2 | `type_map` (u16, bitfield below) |
| 1 | `type_map_ext` (u8, bitfield below) |
| 1 | `left` tile index |
| 1 | `right` tile index |
| 1 | `top` tile index |
| 1 | `bottom` tile index |
| 1 | `lid` tile index |

A face value of `0` = no face (transparent / air).

#### `type_map` bits

| Bits | Meaning |
|------|---------|
| 0 | up traversable |
| 1 | down traversable |
| 2 | left traversable |
| 3 | right traversable |
| 4–6 | block type 0–7 (air, road, pavement, field, building, …) |
| 7 | is-flat (face drawn as a flat decal, not a cube) |
| 8–13 | slope type 0–44 (0 = full cube; others = ramps/diagonals) |
| 14–15 | rotation 0–3 → 0/90/180/270° |

#### `type_map_ext` bits

| Bits | Meaning |
|------|---------|
| 0 | traffic lights |
| 2 | rail end-turn |
| 3–4 | palette remap index 0–3 |
| 5 | flip top/bottom faces |
| 6 | flip left/right faces |
| 7 | railway |

### Object record (14 bytes)

`u16 x, u16 y, u16 z, u8 type, u8 remap, u16 rotation, u16 pitch, u16 roll`.
Coordinates are fixed-point (≫6 gives block coordinates).

## `.G24` / `.GRY` — style (graphics)

Not yet parsed. `.G24` = 24-bit in-game graphics, `.GRY` = 8-bit (palette-based).
Contains: tile textures (64×64) used by block faces, object/car/ped sprites,
"delta" overlays (damage, doors), palettes, and car-handling info. This is the
next parser to implement (see ROADMAP).
