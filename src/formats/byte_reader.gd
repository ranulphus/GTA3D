class_name ByteReader
extends RefCounted

## Tiny little-endian cursor over a PackedByteArray.
## GTA1 data files are little-endian, which matches Godot's decode_* helpers.

var _data: PackedByteArray
var pos: int = 0

func _init(data: PackedByteArray) -> void:
	_data = data

func seek(p: int) -> void:
	pos = p

func remaining() -> int:
	return _data.size() - pos

func size() -> int:
	return _data.size()

func u8() -> int:
	var v: int = _data[pos]
	pos += 1
	return v

func u16() -> int:
	var v: int = _data.decode_u16(pos)
	pos += 2
	return v

func s16() -> int:
	var v: int = _data.decode_s16(pos)
	pos += 2
	return v

func u32() -> int:
	var v: int = _data.decode_u32(pos)
	pos += 4
	return v

func bytes(n: int) -> PackedByteArray:
	var v: PackedByteArray = _data.slice(pos, pos + n)
	pos += n
	return v
