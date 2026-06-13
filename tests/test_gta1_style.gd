extends SceneTree

## Headless unit test for GTA1Style. Builds a minimal synthetic .G24 with one
## side tile and a known CLUT, then asserts the full decode chain (header,
## tile de-paging, CLUT application) produces the expected RGBA pixels.
##
## Run with:  godot --headless --script res://tests/test_gta1_style.gd

var _failures := 0


func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   - ", label)
	else:
		print("  FAIL - ", label)
		_failures += 1


func _run() -> void:
	print("test_gta1_style:")

	var data := _build_minimal_g24()
	var s := GTA1Style.parse(data)
	_check(s != null, "parse returns a style")
	if s == null:
		return
	_check(s.version == GTA1Style.VERSION_G24, "version == 336")
	_check(s.num_side == 1 and s.num_lid == 0 and s.num_aux == 0, "one side tile")

	var img := s.get_tile_image(GTA1Style.TileKind.SIDE, 0)
	_check(img != null and img.get_width() == 64 and img.get_height() == 64, "64x64 image")

	# Our synthetic tile: pixel (0,0) uses palette index 0 -> transparent.
	# pixel (0,1) uses palette index 5 -> red. (1,0) uses index 9 -> green.
	var p00 := img.get_pixel(0, 0)
	var p10 := img.get_pixel(1, 0)  # x=1,y=0
	var p01 := img.get_pixel(0, 1)  # x=0,y=1
	_check(p00.a == 0.0, "index 0 is transparent")
	_check(p10.r > 0.9 and p10.g < 0.1 and p10.b < 0.1, "index 5 decodes to red")
	_check(p01.g > 0.9 and p01.r < 0.1 and p01.b < 0.1, "index 9 decodes to green")

	if _failures == 0:
		print("ALL PASSED")
	else:
		print("%d FAILURE(S)" % _failures)


func _build_minimal_g24() -> PackedByteArray:
	var side_size := 4096       # 1 tile
	var clut_size := 1024       # rounds up to one 64 KB page
	var paged_clut := 65536
	var pal_index_size := 8     # 4 u16 entries (side tile 0 reads index 0)

	# --- tiles region: 1 tile, but packed in a 4-tile strip (16384 bytes) ---
	var tiles := PackedByteArray()
	tiles.resize(GTA1Style.STRIP_BYTES)
	# tile 0 occupies columns 0..63 of the 256-wide strip.
	# row 0, col 1 -> palette index 5 ; row 1, col 0 -> palette index 9
	tiles[0 * 256 + 1] = 5
	tiles[1 * 256 + 0] = 9
	# Note: tiles_len is rounded to a multiple-of-4 block count; 1 tile -> pad to 4.
	var tiles_len := GTA1Style.STRIP_BYTES  # 4 blocks worth = 16384

	# --- CLUT page: 64 interleaved cluts; color p of clut 0 at p*256 + 0 (B,G,R) ---
	var clut := PackedByteArray()
	clut.resize(paged_clut)
	# palette index 5 -> red (R=255): stored as B,G,R at offset 5*256
	clut[5 * 256 + 2] = 255
	# palette index 9 -> green (G=255)
	clut[9 * 256 + 1] = 255

	# --- pal index: entry 0 -> clut 0 ---
	var pal := PackedByteArray()
	pal.resize(pal_index_size)  # all zeros -> clut 0

	var buf := PackedByteArray()
	_push_u32(buf, GTA1Style.VERSION_G24)
	_push_u32(buf, side_size)        # sideSize
	_push_u32(buf, 0)                # lidSize
	_push_u32(buf, 0)                # auxSize
	_push_u32(buf, 0)                # animSize
	_push_u32(buf, clut_size)        # clutSize
	_push_u32(buf, 0)                # tileclutSize
	_push_u32(buf, 0)                # spriteclutSize
	_push_u32(buf, 0)                # newcarclutSize
	_push_u32(buf, 0)                # fontclutSize
	_push_u32(buf, pal_index_size)   # paletteIndexSize
	_push_u32(buf, 0)                # objectInfoSize
	_push_u32(buf, 0)                # carInfoSize
	_push_u32(buf, 0)                # spriteInfoSize
	_push_u32(buf, 0)                # spriteGraphicsSize
	_push_u32(buf, 42)               # spriteNumberSize
	# header is 16 u32 = 64 bytes
	buf.append_array(tiles)          # tiles (tiles_len == STRIP_BYTES)
	buf.append_array(clut)           # paged clut
	buf.append_array(pal)            # pal index
	return buf


func _push_u32(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF)
	buf.append((v >> 8) & 0xFF)
	buf.append((v >> 16) & 0xFF)
	buf.append((v >> 24) & 0xFF)
