extends SceneTree

const TranslationHelper := preload("res://addons/fairygui/utils/translation_helper.gd")


func _initialize() -> void:
	TranslationHelper.load_from_xml("<resources><string name=\"pkgcomp-child\">Localized text</string></resources>")
	if not TranslationHelper.strings.has("pkgcomp") or TranslationHelper.strings["pkgcomp"].get("child") != "Localized text":
		_fail("Translation XML strings were not parsed.")
		return

	var buffer := FGUIByteBuffer.new(_make_component_data())
	buffer.string_table = ["child", "tip", "Original text"]
	var package := FGUIPackage.new()
	package.id = "pkg"
	var item := FGUIPackageItem.new()
	item.owner = package
	item.id = "comp"
	item.raw_data = buffer
	TranslationHelper.translate_component(item)
	if buffer.string_table[2] != "Localized text":
		_fail("Component text was not translated through the string table.")
		return
	TranslationHelper.clear()
	quit(0)


func _make_component_data() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(64)
	bytes[0] = 3
	bytes[1] = 1
	_write_u16(bytes, 6, 8)
	_write_u16(bytes, 8, 1)
	_write_u16(bytes, 10, 41)

	var child_start := 12
	bytes[child_start] = 7
	bytes[child_start + 1] = 1
	_write_u16(bytes, child_start + 2, 16)
	_write_u16(bytes, child_start + 4, 23)
	_write_u16(bytes, child_start + 6, 25)
	_write_u16(bytes, child_start + 14, 27)

	bytes[child_start + 16] = FGUIEnums.OBJECT_TEXT
	_write_u16(bytes, child_start + 21, 0)
	_write_u16(bytes, child_start + 23, 1)
	_write_u16(bytes, child_start + 25, 0)
	_write_u16(bytes, child_start + 27, 2)
	return bytes


func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = (value >> 8) & 0xff
	bytes[offset + 1] = value & 0xff


func _fail(message: String) -> void:
	TranslationHelper.clear()
	push_error(message)
	quit(1)
