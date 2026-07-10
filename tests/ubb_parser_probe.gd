extends SceneTree


func _initialize() -> void:
	var parser := FGUIUBBParser.new()
	parser.link_underline = true
	parser.link_color = "#44ccff"
	var source := "[b]Bold[/b] [size=18]Large[/size] [color=#ff0000]Red[/color] [url=https://example.com]Link[/url] [url]https://plain.example[/url] [img]ui://packageimage[/img] [align=center]Centered[/align] \\[b]"
	var parsed := parser.parse(source)
	var expected := "[b]Bold[/b] [font_size=18]Large[/font_size] [color=#ff0000]Red[/color] [url=https://example.com][u][color=#44ccff]Link[/color][/u][/url] [url=https://plain.example][u][color=#44ccff]https://plain.example[/color][/u][/url] [img]ui://packageimage[/img] [center]Centered[/center] [b]"
	if parsed != expected:
		_fail("UBB parsing did not map FairyGUI tags to Godot BBCode: %s" % parsed)
		return
	if parser.last_color != "#ff0000" or parser.last_size != "18":
		_fail("UBB parsing did not retain the latest color and size metadata.")
		return
	var stripped := parser.parse(source, true)
	if stripped != "Bold Large Red Link https://plain.example ui://packageimage Centered [b]":
		_fail("UBB remove mode did not preserve text while stripping recognized tags: %s" % stripped)
		return
	if parser.last_color != "#ff0000" or parser.last_size != "18":
		_fail("UBB remove mode did not preserve color and size metadata for text inputs.")
		return
	var extended := parser.parse("A[strike]B[/strike][br]C[unknown=x]D[/unknown]")
	if extended != "A[s]B[/s]\nC[unknown=x]D[/unknown]":
		_fail("UBB parsing did not handle strike, line break, and unknown tags: %s" % extended)
		return
	var extended_stripped := parser.parse("A[strike]B[/strike][br]C[unknown=x]D[/unknown]", true)
	if extended_stripped != "ABC[unknown=x]D[/unknown]":
		_fail("UBB remove mode stripped unsupported tags or left supported tags behind: %s" % extended_stripped)
		return
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
