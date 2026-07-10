class_name FGUIByteBuffer
extends RefCounted

const STRING_NULL := 65534
const STRING_EMPTY := 65533

var data: PackedByteArray
var pos: int = 0
var string_table: Array = []
var version: int = 0


func _init(source: PackedByteArray = PackedByteArray(), offset: int = 0, length: int = -1) -> void:
	if length < 0:
		length = source.size() - offset
	data = source.slice(offset, offset + length)


func get_length() -> int:
	return data.size()


func bytes_available() -> int:
	return data.size() - pos


func skip(count: int) -> void:
	pos = clampi(pos + count, 0, data.size())


func read_u8() -> int:
	_require(1)
	var value := int(data[pos])
	pos += 1
	return value


func read_i8() -> int:
	var value := read_u8()
	return value - 256 if value >= 128 else value


func read_bool() -> bool:
	return read_u8() == 1


func read_u16() -> int:
	_require(2)
	var value := (int(data[pos]) << 8) | int(data[pos + 1])
	pos += 2
	return value


func read_i16() -> int:
	var value := read_u16()
	return value - 0x10000 if value >= 0x8000 else value


func read_u32() -> int:
	_require(4)
	var value := (int(data[pos]) << 24) | (int(data[pos + 1]) << 16) | (int(data[pos + 2]) << 8) | int(data[pos + 3])
	pos += 4
	return value


func read_i32() -> int:
	var value := read_u32()
	return value - 0x100000000 if value >= 0x80000000 else value


func read_float32() -> float:
	_require(4)
	var stream := StreamPeerBuffer.new()
	stream.big_endian = true
	stream.data_array = data.slice(pos, pos + 4)
	pos += 4
	return stream.get_float()


func read_utf_string() -> String:
	var count := read_u16()
	if count == 0:
		return ""
	var bytes := read_bytes(count)
	return bytes.get_string_from_utf8()


func read_custom_string(count: int) -> String:
	if count <= 0:
		return ""
	var bytes := read_bytes(count)
	return bytes.get_string_from_utf8()


func read_bytes(count: int) -> PackedByteArray:
	_require(count)
	var bytes := data.slice(pos, pos + count)
	pos += count
	return bytes


func read_s() -> Variant:
	var index := read_u16()
	if index == STRING_NULL:
		return null
	if index == STRING_EMPTY:
		return ""
	if index < 0 or index >= string_table.size():
		push_error("FairyGUI string table index out of range: %s" % index)
		return ""
	return string_table[index]


func write_s(value: String) -> void:
	var index := read_u16()
	if index == STRING_NULL or index == STRING_EMPTY:
		return
	if index < 0 or index >= string_table.size():
		push_error("FairyGUI string table index out of range: %s" % index)
		return
	string_table[index] = value


func read_s_array(count: int) -> Array:
	var result: Array = []
	for i in count:
		result.append(read_s())
	return result


func read_color(has_alpha: bool = false) -> Color:
	var r := read_u8()
	var g := read_u8()
	var b := read_u8()
	var a := read_u8()
	return Color8(r, g, b, a if has_alpha else 255)


func read_buffer() -> FGUIByteBuffer:
	var count := read_u32()
	var buffer := FGUIByteBuffer.new(data, pos, count)
	pos += count
	buffer.string_table = string_table
	buffer.version = version
	return buffer


func seek(index_table_pos: int, block_index: int) -> bool:
	var old_pos := pos
	pos = index_table_pos
	var segment_count := read_u8()
	if block_index >= segment_count:
		pos = old_pos
		return false

	var use_short := read_u8() == 1
	var new_pos := 0
	if use_short:
		pos += 2 * block_index
		new_pos = read_u16()
	else:
		pos += 4 * block_index
		new_pos = read_u32()

	if new_pos > 0:
		pos = index_table_pos + new_pos
		return true

	pos = old_pos
	return false


func _require(count: int) -> void:
	if pos + count > data.size():
		push_error("FairyGUI buffer underflow at %s, need %s bytes, size %s" % [pos, count, data.size()])
