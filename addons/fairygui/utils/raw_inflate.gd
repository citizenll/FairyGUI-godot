class_name FGUIRawInflate
extends RefCounted

const LENGTH_BASE := [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
const LENGTH_EXTRA := [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
const DIST_BASE := [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
const DIST_EXTRA := [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
const CODE_LENGTH_ORDER := [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]


class BitReader:
	var bytes: PackedByteArray
	var byte_pos: int = 0
	var bit_buffer: int = 0
	var bit_count: int = 0
	var failed: bool = false

	func _init(source: PackedByteArray) -> void:
		bytes = source

	func fail() -> void:
		failed = true

	func read_bits(count: int) -> int:
		var result := 0
		var shift := 0
		while count > 0:
			if bit_count == 0:
				if byte_pos >= bytes.size():
					fail()
					return result
				bit_buffer = int(bytes[byte_pos])
				byte_pos += 1
				bit_count = 8
			var take := mini(count, bit_count)
			result |= (bit_buffer & ((1 << take) - 1)) << shift
			bit_buffer >>= take
			bit_count -= take
			count -= take
			shift += take
		return result

	func align_byte() -> void:
		bit_buffer = 0
		bit_count = 0


class Huffman:
	var table: Dictionary = {}
	var max_bits: int = 0

	func _init(lengths: Array) -> void:
		var bl_count: Array[int] = []
		bl_count.resize(16)
		for length_value in lengths:
			var length := int(length_value)
			if length > 0:
				if length >= bl_count.size():
					bl_count.resize(length + 1)
				bl_count[length] += 1
				max_bits = maxi(max_bits, length)

		var code := 0
		var next_code: Array[int] = []
		next_code.resize(maxi(16, max_bits + 1))
		for bits in range(1, max_bits + 1):
			code = (code + bl_count[bits - 1]) << 1
			next_code[bits] = code

		for symbol in lengths.size():
			var length := int(lengths[symbol])
			if length == 0:
				continue
			var canonical := next_code[length]
			next_code[length] += 1
			var reversed := FGUIRawInflate.reverse_bits(canonical, length)
			table[(length << 16) | reversed] = symbol

	func decode(reader: BitReader) -> int:
		var code := 0
		for length in range(1, max_bits + 1):
			code |= reader.read_bits(1) << (length - 1)
			if reader.failed:
				return -1
			var key := (length << 16) | code
			if table.has(key):
				return table[key]
		reader.fail()
		return -1


static func decompress(source: PackedByteArray) -> PackedByteArray:
	var reader := BitReader.new(source)
	var output := PackedByteArray()
	var final_block := false
	while not final_block:
		final_block = reader.read_bits(1) == 1
		var block_type := reader.read_bits(2)
		if reader.failed:
			return PackedByteArray()
		match block_type:
			0:
				if not _read_stored_block(reader, output):
					return PackedByteArray()
			1:
				var fixed := _fixed_trees()
				if not _decode_compressed_block(reader, output, fixed["lit"], fixed["dist"]):
					return PackedByteArray()
			2:
				var dynamic := _dynamic_trees(reader)
				if dynamic.is_empty() or not _decode_compressed_block(reader, output, dynamic["lit"], dynamic["dist"]):
					return PackedByteArray()
			_:
				return PackedByteArray()
	return output


static func reverse_bits(value: int, count: int) -> int:
	var result := 0
	for i in count:
		result = (result << 1) | (value & 1)
		value >>= 1
	return result


static func _read_stored_block(reader: BitReader, output: PackedByteArray) -> bool:
	reader.align_byte()
	var length := reader.read_bits(16)
	var inv_length := reader.read_bits(16)
	if reader.failed or (length ^ 0xffff) != inv_length:
		return false
	for i in length:
		output.append(reader.read_bits(8))
		if reader.failed:
			return false
	return true


static func _decode_compressed_block(reader: BitReader, output: PackedByteArray, lit_tree: Huffman, dist_tree: Huffman) -> bool:
	while true:
		var symbol := lit_tree.decode(reader)
		if symbol < 0:
			return false
		if symbol < 256:
			output.append(symbol)
		elif symbol == 256:
			return true
		else:
			var length_index := symbol - 257
			if length_index < 0 or length_index >= LENGTH_BASE.size():
				return false
			var length := int(LENGTH_BASE[length_index]) + reader.read_bits(int(LENGTH_EXTRA[length_index]))
			var dist_symbol := dist_tree.decode(reader)
			if dist_symbol < 0 or dist_symbol >= DIST_BASE.size():
				return false
			var distance := int(DIST_BASE[dist_symbol]) + reader.read_bits(int(DIST_EXTRA[dist_symbol]))
			if reader.failed or distance <= 0 or distance > output.size():
				return false
			for i in length:
				output.append(output[output.size() - distance])
	return false


static func _fixed_trees() -> Dictionary:
	var lit_lengths: Array[int] = []
	lit_lengths.resize(288)
	for i in range(0, 144):
		lit_lengths[i] = 8
	for i in range(144, 256):
		lit_lengths[i] = 9
	for i in range(256, 280):
		lit_lengths[i] = 7
	for i in range(280, 288):
		lit_lengths[i] = 8
	var dist_lengths: Array[int] = []
	dist_lengths.resize(32)
	for i in dist_lengths.size():
		dist_lengths[i] = 5
	return {"lit": Huffman.new(lit_lengths), "dist": Huffman.new(dist_lengths)}


static func _dynamic_trees(reader: BitReader) -> Dictionary:
	var hlit := reader.read_bits(5) + 257
	var hdist := reader.read_bits(5) + 1
	var hclen := reader.read_bits(4) + 4

	var code_lengths: Array[int] = []
	code_lengths.resize(19)
	for i in hclen:
		code_lengths[int(CODE_LENGTH_ORDER[i])] = reader.read_bits(3)
	var code_tree := Huffman.new(code_lengths)

	var lengths: Array[int] = []
	var total := hlit + hdist
	while lengths.size() < total:
		var symbol := code_tree.decode(reader)
		if symbol < 0:
			return {}
		if symbol <= 15:
			lengths.append(symbol)
		elif symbol == 16:
			if lengths.is_empty():
				return {}
			var repeat_prev := lengths[lengths.size() - 1]
			var repeat_count := reader.read_bits(2) + 3
			for i in repeat_count:
				lengths.append(repeat_prev)
		elif symbol == 17:
			var repeat_count := reader.read_bits(3) + 3
			for i in repeat_count:
				lengths.append(0)
		elif symbol == 18:
			var repeat_count := reader.read_bits(7) + 11
			for i in repeat_count:
				lengths.append(0)
		if reader.failed or lengths.size() > total:
			return {}

	var lit_lengths := lengths.slice(0, hlit)
	var dist_lengths := lengths.slice(hlit, total)
	if dist_lengths.is_empty():
		dist_lengths = [0]
	return {"lit": Huffman.new(lit_lengths), "dist": Huffman.new(dist_lengths)}
