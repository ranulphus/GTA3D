extends SceneTree

## Headless unit test for GTA1Map. Builds a minimal, hand-crafted .CMP byte
## buffer (so no original game data is required) and asserts the parser decodes
## it correctly, including the typeMap/typeMapExt bitfields.
##
## Run with:  godot --headless --script res://tests/test_gta1_map.gd

var _failures: int = 0


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
	print("test_gta1_map:")

	var data := _build_minimal_cmp()
	var m := GTA1Map.parse(data)

	_check(m != null, "parse returns a map")
	_check(m.style_number == 7, "style number == 7")
	_check(m.blocks.size() == 1, "one block parsed")
	_check(m.get_num_blocks(0, 0) == 1, "cell (0,0) has 1 block")
	_check(m.get_num_blocks(5, 9) == 1, "cell (5,9) also resolves via base grid")

	var b := m.get_block(0, 0, 0)
	_check(b != null, "block (0,0,0) exists")
	_check(m.get_block(0, 0, 1) == null, "no block above the only one")
	_check(b.lid == 42, "lid tile == 42")
	_check(b.left == 10 and b.right == 11 and b.top == 12 and b.bottom == 13, "face tiles decoded")
	_check(b.block_type() == 5, "block_type() == 5")
	_check(b.rotation() == 2, "rotation() == 2")
	_check(b.is_flat() == true, "is_flat() true")
	_check(b.slope_type() == 0, "slope_type() == 0")
	_check(b.flip_left_right() == true, "flip_left_right() true")
	_check(b.remap_index() == 1, "remap_index() == 1")

	_check(m.objects.size() == 1, "one object parsed")
	if m.objects.size() == 1:
		var o: Dictionary = m.objects[0]
		_check(o.x == 256 and o.y == 512 and o.type == 3, "object fields decoded")

	if _failures == 0:
		print("ALL PASSED")
	else:
		print("%d FAILURE(S)" % _failures)


## Construct a 1-block, 1-object .CMP entirely in memory.
func _build_minimal_cmp() -> PackedByteArray:
	var column_size := 4    # 2 words: [count=1, block index=0]
	var block_size := 8     # 1 block
	var object_size := 14   # 1 object

	var buf := PackedByteArray()
	# header (28 bytes)
	_push_u32(buf, 0)              # version
	buf.append(7)                 # style number
	buf.append(0)                 # sample number
	_push_u16(buf, 0)             # reserved
	_push_u32(buf, 0)             # route_size
	_push_u32(buf, object_size)   # object_pos_size
	_push_u32(buf, column_size)   # column_size
	_push_u32(buf, block_size)    # block_size
	_push_u32(buf, 0)             # nav_data_size

	# base grid: every cell points to column byte-offset 0
	for i in (GTA1Map.DIM * GTA1Map.DIM):
		_push_u32(buf, 0)

	# columns: word0 = offset (5 air levels -> 6-5 = 1 block), word1 = block index (0)
	_push_u16(buf, 5)
	_push_u16(buf, 0)

	# one block: block_type 5 (5<<4=0x50), rotation 2 (2<<14=0x8000), is_flat (128)
	var type_map := 0x50 | 0x8000 | 128
	var type_map_ext := (1 << 3) | 64   # remap index 1, flip_left_right
	_push_u16(buf, type_map)
	buf.append(type_map_ext)
	buf.append(10)   # left
	buf.append(11)   # right
	buf.append(12)   # top
	buf.append(13)   # bottom
	buf.append(42)   # lid

	# one object
	_push_u16(buf, 256)  # x
	_push_u16(buf, 512)  # y
	_push_u16(buf, 0)    # z
	buf.append(3)        # type
	buf.append(0)        # remap
	_push_u16(buf, 0)    # rotation
	_push_u16(buf, 0)    # pitch
	_push_u16(buf, 0)    # roll

	return buf


func _push_u16(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF)
	buf.append((v >> 8) & 0xFF)


func _push_u32(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF)
	buf.append((v >> 8) & 0xFF)
	buf.append((v >> 16) & 0xFF)
	buf.append((v >> 24) & 0xFF)
