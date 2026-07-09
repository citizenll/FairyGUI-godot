class_name FGUIPackage
extends RefCounted

const MAGIC := 0x46475549

static var _inst_by_id: Dictionary = {}
static var _inst_by_name: Dictionary = {}
static var _branch: String = ""
static var _vars: Dictionary = {}
static var constructing: int = 0

var id: String = ""
var name: String = ""
var res_key: String = ""
var custom_id: String = ""
var branch_index: int = -1
var items: Array = []
var dependencies: Array = []
var branches: Array = []

var _items_by_id: Dictionary = {}
var _items_by_name: Dictionary = {}
var _sprites: Dictionary = {}


static func add_package(package_path: String, desc_data: PackedByteArray = PackedByteArray()) -> FGUIPackage:
	var normalized := _normalize_package_path(package_path)
	var bytes := desc_data
	if bytes.is_empty():
		bytes = FileAccess.get_file_as_bytes(normalized["file_path"])
		if bytes.is_empty():
			push_error("FairyGUI package not found or empty: %s" % normalized["file_path"])
			return null

	var pkg := FGUIPackage.new()
	pkg.res_key = normalized["res_key"]
	pkg._load_package(FGUIByteBuffer.new(bytes))
	_inst_by_id[pkg.id] = pkg
	_inst_by_name[pkg.name] = pkg
	_inst_by_id[pkg.res_key] = pkg
	return pkg


static func get_by_id(package_id: String) -> FGUIPackage:
	return _inst_by_id.get(package_id)


static func get_by_name(package_name: String) -> FGUIPackage:
	return _inst_by_name.get(package_name)


static func remove_package(package_id_or_name: String) -> void:
	var pkg: FGUIPackage = _inst_by_id.get(package_id_or_name)
	if pkg == null:
		pkg = _inst_by_name.get(package_id_or_name)
	if pkg == null:
		push_error("Unknown FairyGUI package: %s" % package_id_or_name)
		return

	_inst_by_id.erase(pkg.id)
	_inst_by_name.erase(pkg.name)
	_inst_by_id.erase(pkg.res_key)
	if pkg.custom_id != "":
		_inst_by_id.erase(pkg.custom_id)


static func create_object_from_package(package_name: String, resource_name: String, user_class: Variant = null) -> FGUIObject:
	var pkg := get_by_name(package_name)
	return pkg.create_object(resource_name, user_class) if pkg != null else null


static func get_item_by_url(url: String) -> FGUIPackageItem:
	var pos1 := url.find("//")
	if pos1 == -1:
		return null

	var pos2 := url.find("/", pos1 + 2)
	if pos2 == -1:
		if url.length() > 13:
			var pkg := get_by_id(url.substr(5, 8))
			if pkg != null:
				return pkg.get_item_by_id(url.substr(13))
	else:
		var pkg_name := url.substr(pos1 + 2, pos2 - pos1 - 2)
		var pkg := get_by_name(pkg_name)
		if pkg != null:
			return pkg.get_item_by_name(url.substr(pos2 + 1))

	return null


static func get_item_url(package_name: String, resource_name: String) -> String:
	var pkg := get_by_name(package_name)
	if pkg == null:
		return ""
	var item := pkg.get_item_by_name(resource_name)
	return "ui://%s%s" % [pkg.id, item.id] if item != null else ""


static func normalize_url(url: String) -> String:
	if url == "":
		return ""
	if url.begins_with("ui://"):
		return url
	var slash := url.find("/")
	if slash == -1:
		return url
	return get_item_url(url.substr(0, slash), url.substr(slash + 1))


static func create_object_from_url(url: String, user_class: Variant = null) -> FGUIObject:
	var item := get_item_by_url(normalize_url(url))
	if item == null:
		return null
	return item.owner._internal_create_object(item, user_class)


static func get_var(key: String) -> String:
	return _vars.get(key, "")


static func set_var(key: String, value: String) -> void:
	_vars[key] = value


func set_custom_id(value: String) -> void:
	if custom_id != "":
		_inst_by_id.erase(custom_id)
	custom_id = value
	if custom_id != "":
		_inst_by_id[custom_id] = self


func create_object(resource_name: String, user_class: Variant = null) -> FGUIObject:
	var item := _items_by_name.get(resource_name)
	return _internal_create_object(item, user_class) if item != null else null


func get_item_by_id(item_id: String) -> FGUIPackageItem:
	return _items_by_id.get(item_id)


func get_item_by_name(resource_name: String) -> FGUIPackageItem:
	return _items_by_name.get(resource_name)


func get_item_asset_by_name(resource_name: String) -> Variant:
	var item := get_item_by_name(resource_name)
	return get_item_asset(item) if item != null else null


func get_item_asset(item: FGUIPackageItem) -> Variant:
	if item == null:
		return null

	match item.type:
		FGUIEnums.PACKAGE_ITEM_IMAGE:
			if not item.decoded:
				item.decoded = true
				var sprite: Dictionary = _sprites.get(item.id, {})
				if not sprite.is_empty():
					var atlas_texture: Texture2D = get_item_asset(sprite["atlas"])
					if atlas_texture != null:
						item.texture = _create_sprite_texture(atlas_texture, sprite)
			return item.texture

		FGUIEnums.PACKAGE_ITEM_ATLAS:
			if not item.decoded:
				item.decoded = true
				item.texture = _load_texture(item.file)
			return item.texture

		FGUIEnums.PACKAGE_ITEM_COMPONENT:
			return item.raw_data

		_:
			return null


func _internal_create_object(item: FGUIPackageItem, user_class: Variant = null) -> FGUIObject:
	if item == null:
		return null
	var obj := FGUIObjectFactory.new_object_from_item(item, user_class)
	if obj == null:
		return null
	constructing += 1
	obj.construct_from_resource()
	constructing -= 1
	return obj


func _load_package(buffer: FGUIByteBuffer) -> void:
	if buffer.read_u32() != MAGIC:
		push_error("FairyGUI old or invalid package format: %s" % res_key)
		return

	buffer.version = buffer.read_i32()
	var compressed := buffer.read_bool()
	id = buffer.read_utf_string()
	name = buffer.read_utf_string()
	buffer.skip(20)

	if compressed:
		var compressed_data := buffer.data.slice(buffer.pos, buffer.get_length())
		var decompressed := compressed_data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
		if decompressed.is_empty():
			push_error("FairyGUI compressed package could not be decompressed: %s" % res_key)
			return
		var next_buffer := FGUIByteBuffer.new(decompressed)
		next_buffer.version = buffer.version
		buffer = next_buffer

	var ver2 := buffer.version >= 2
	var index_table_pos := buffer.pos

	buffer.seek(index_table_pos, 4)
	var count := buffer.read_i32()
	var string_table: Array = []
	for i in count:
		string_table.append(buffer.read_utf_string())
	buffer.string_table = string_table

	if buffer.seek(index_table_pos, 5):
		count = buffer.read_i32()
		for i in count:
			var index := buffer.read_u16()
			var length := buffer.read_i32()
			string_table[index] = buffer.read_custom_string(length)

	buffer.seek(index_table_pos, 0)
	count = buffer.read_i16()
	for i in count:
		dependencies.append({"id": buffer.read_s(), "name": buffer.read_s()})

	var branch_included := false
	if ver2:
		count = buffer.read_i16()
		if count > 0:
			branches = buffer.read_s_array(count)
			if _branch != "":
				branch_index = branches.find(_branch)
		branch_included = count > 0

	_read_items(buffer, index_table_pos, ver2, branch_included)
	_read_sprites(buffer, index_table_pos, ver2)
	_read_pixel_hit_tests(buffer, index_table_pos)


func _read_items(buffer: FGUIByteBuffer, index_table_pos: int, ver2: bool, branch_included: bool) -> void:
	buffer.seek(index_table_pos, 1)
	var count := buffer.read_u16()
	for i in count:
		var next_pos := buffer.read_i32() + buffer.pos
		var item := FGUIPackageItem.new()
		item.owner = self
		item.type = buffer.read_i8()
		item.id = _string_or_empty(buffer.read_s())
		item.name = _string_or_empty(buffer.read_s())
		buffer.read_s()
		var file_name = buffer.read_s()
		if file_name != null:
			item.file = file_name
		buffer.read_bool()
		item.width = buffer.read_i32()
		item.height = buffer.read_i32()

		match item.type:
			FGUIEnums.PACKAGE_ITEM_IMAGE:
				item.object_type = FGUIEnums.OBJECT_IMAGE
				var scale_option := buffer.read_i8()
				if scale_option == 1:
					item.has_scale9_grid = true
					item.scale9_grid = Rect2i(buffer.read_i32(), buffer.read_i32(), buffer.read_i32(), buffer.read_i32())
					item.tile_grid_indice = buffer.read_i32()
				elif scale_option == 2:
					item.scale_by_tile = true
				item.smoothing = buffer.read_bool()

			FGUIEnums.PACKAGE_ITEM_MOVIE_CLIP:
				item.smoothing = buffer.read_bool()
				item.object_type = FGUIEnums.OBJECT_MOVIE_CLIP
				item.raw_data = buffer.read_buffer()

			FGUIEnums.PACKAGE_ITEM_FONT:
				item.raw_data = buffer.read_buffer()

			FGUIEnums.PACKAGE_ITEM_COMPONENT:
				var extension := buffer.read_i8()
				item.object_type = extension if extension > 0 else FGUIEnums.OBJECT_COMPONENT
				item.raw_data = buffer.read_buffer()
				FGUIObjectFactory.resolve_package_item_extension(item)

			FGUIEnums.PACKAGE_ITEM_ATLAS, FGUIEnums.PACKAGE_ITEM_SOUND, FGUIEnums.PACKAGE_ITEM_MISC:
				item.file = _package_relative_file("%s_%s" % [res_key.get_file(), item.file])

			FGUIEnums.PACKAGE_ITEM_SPINE, FGUIEnums.PACKAGE_ITEM_DRAGON_BONES:
				item.file = _package_relative_file(item.file)
				buffer.read_float32()
				buffer.read_float32()

		if ver2:
			var branch_name = buffer.read_s()
			if branch_name != null and branch_name != "":
				item.name = "%s/%s" % [branch_name, item.name]

			var branch_count := buffer.read_u8()
			if branch_count > 0:
				if branch_included:
					item.branches = buffer.read_s_array(branch_count)
				else:
					_items_by_id[_string_or_empty(buffer.read_s())] = item

			var high_res_count := buffer.read_u8()
			if high_res_count > 0:
				item.high_resolution = buffer.read_s_array(high_res_count)

		items.append(item)
		_items_by_id[item.id] = item
		if item.name != "":
			_items_by_name[item.name] = item

		buffer.pos = next_pos


func _read_sprites(buffer: FGUIByteBuffer, index_table_pos: int, ver2: bool) -> void:
	buffer.seek(index_table_pos, 2)
	var count := buffer.read_u16()
	for i in count:
		var next_pos := buffer.read_u16() + buffer.pos
		var item_id := _string_or_empty(buffer.read_s())
		var atlas_item := _items_by_id.get(_string_or_empty(buffer.read_s()))
		var rect := Rect2i(buffer.read_i32(), buffer.read_i32(), buffer.read_i32(), buffer.read_i32())
		var rotated := buffer.read_bool()
		var offset := Vector2i.ZERO
		var original_size := rect.size
		if ver2 and buffer.read_bool():
			offset = Vector2i(buffer.read_i32(), buffer.read_i32())
			original_size = Vector2i(buffer.read_i32(), buffer.read_i32())
		_sprites[item_id] = {
			"atlas": atlas_item,
			"rect": rect,
			"rotated": rotated,
			"offset": offset,
			"original_size": original_size,
		}
		buffer.pos = next_pos


func _read_pixel_hit_tests(buffer: FGUIByteBuffer, index_table_pos: int) -> void:
	if not buffer.seek(index_table_pos, 3):
		return
	var count := buffer.read_u16()
	for i in count:
		var next_pos := buffer.read_i32() + buffer.pos
		buffer.pos = next_pos


func _load_texture(path: String) -> Texture2D:
	var texture := load(path)
	if texture is Texture2D:
		return texture

	if not path.begins_with("res://") and not path.begins_with("user://"):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	push_warning("FairyGUI texture not found: %s" % path)
	return null


func _create_sprite_texture(atlas_texture: Texture2D, sprite: Dictionary) -> Texture2D:
	var region: Rect2i = sprite["rect"]
	if not bool(sprite.get("rotated", false)) and Vector2i(sprite.get("offset", Vector2i.ZERO)) == Vector2i.ZERO and Vector2i(sprite.get("original_size", region.size)) == region.size:
		var texture := AtlasTexture.new()
		texture.atlas = atlas_texture
		texture.region = Rect2(Vector2(region.position), Vector2(region.size))
		texture.filter_clip = true
		return texture

	var atlas_image := atlas_texture.get_image()
	if atlas_image == null or atlas_image.is_empty():
		return null
	var original_size: Vector2i = sprite.get("original_size", region.size)
	var offset: Vector2i = sprite.get("offset", Vector2i.ZERO)
	var rotated := bool(sprite.get("rotated", false))
	var out_image := Image.create_empty(maxi(1, original_size.x), maxi(1, original_size.y), false, Image.FORMAT_RGBA8)
	out_image.fill(Color.TRANSPARENT)
	if rotated:
		for y in region.size.y:
			for x in region.size.x:
				var source := atlas_image.get_pixel(region.position.x + x, region.position.y + y)
				var tx := offset.x + y
				var ty := offset.y + region.size.x - x - 1
				if tx >= 0 and ty >= 0 and tx < out_image.get_width() and ty < out_image.get_height():
					out_image.set_pixel(tx, ty, source)
	else:
		out_image.blit_rect(atlas_image, region, offset)
	return ImageTexture.create_from_image(out_image)


func _package_relative_file(file_name: String) -> String:
	var base_dir := res_key.get_base_dir()
	return "%s/%s" % [base_dir, file_name] if base_dir != "" else file_name


static func _normalize_package_path(path: String) -> Dictionary:
	var file_path := path
	if not file_path.ends_with(".fui"):
		file_path += ".fui"
	var res_key := file_path.substr(0, file_path.length() - 4)
	return {"file_path": file_path, "res_key": res_key}


static func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
