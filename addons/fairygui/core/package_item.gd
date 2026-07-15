class_name FGUIPackageItem
extends RefCounted

var owner: Variant
var type: int = FGUIEnums.PACKAGE_ITEM_UNKNOWN
var object_type: int = -1
var id: String = ""
var name: String = ""
var width: int = 0
var height: int = 0
var file: String = ""
var exported: bool = false
var decoded: bool = false
var raw_data: FGUIByteBuffer
var high_resolution: Array = []
var branches: Array = []
var scale9_grid: Rect2i = Rect2i()
var has_scale9_grid: bool = false
var scale_by_tile: bool = false
var tile_grid_indice: int = 0
var smoothing: bool = true
var texture: Texture2D
var audio: AudioStream
var bitmap_font: FGUIBitmapFont
var misc_asset: Variant
var pixel_hit_test_data: FGUIPixelHitTestData
var frames: Array = []
var interval: int = 0
var repeat_delay: int = 0
var swing: bool = false
var extension_type: Variant = null


func load() -> Variant:
	return owner.get_item_asset(self) if owner != null else null


func get_branch() -> FGUIPackageItem:
	if not branches.is_empty() and owner != null and owner.branch_index != -1:
		var item_id = branches[owner.branch_index]
		if item_id != null and item_id != "":
			var item: FGUIPackageItem = owner.get_item_by_id(item_id)
			if item != null:
				return item
	return self


func get_high_resolution() -> FGUIPackageItem:
	if not high_resolution.is_empty() and FGUIRoot.content_scale_level > 0 and owner != null:
		var index := FGUIRoot.content_scale_level - 1
		if index >= 0 and index < high_resolution.size():
			var item_id = high_resolution[index]
			if item_id != null and item_id != "":
				var item: FGUIPackageItem = owner.get_item_by_id(str(item_id))
				if item != null:
					return item
	return self


func _to_string() -> String:
	return name
