# Porting Notes

## Chosen Source

Use `FairyGUI-layabox/source` as the primary reference.

Reasons:

- It is a script runtime, so its architecture maps more directly to GDScript than the Cocos Creator runtime.
- The package parser is current and self-contained around `ByteBuffer`, `UIPackage`, `PackageItem`, and `UIObjectFactory`.
- Engine-specific rendering is concentrated in classes like `GObject`, `GImage`, `GTextField`, and `GLoader`, which can be replaced with Godot `Control` nodes.

`FairyGUI-cocoscreator` remains useful for cross-checking behavior, but it is more coupled to Cocos node/component APIs. `FairyGUI-dom` is useful for ideas around browser rendering but is not the best runtime baseline for Godot.

## Godot Shape

This port is a pure GDScript addon:

- No fork or module patch to `C:\toolkit\godot`.
- Runtime objects are lightweight wrappers that own a Godot `Control`.
- Users add `gobject.node` to their scene tree.
- Package loading stays compatible with `.fui` exports from FairyGUI Editor.

The Godot source tree is still useful as the API reference for current Control, TextureRect, Label, AtlasTexture, FileAccess, and PackedByteArray behavior.

## Implementation Order

1. Package binary parser and atlas texture slicing.
2. Basic display tree: component, image, text, loader, graph.
3. Controllers, gears, relations.
4. Button/list/scroll pane behavior.
5. Transitions and tweening.
6. Editor importer and validation.

## Compatibility Notes

- `.fui` files are read with `FileAccess`, so exported games must include them in non-resource export filters.
- Compressed packages are only best-effort until raw deflate behavior is verified in Godot. FairyGUI's Laya runtime uses raw deflate; Godot's built-in deflate path may expect a zlib wrapper depending on the engine build.
- Scale9, common widgets, list layout, and basic scroll containers are present. Virtual-list recycling, transition timelines, bitmap fonts, audio, and pixel hit testing still require parity work before a commercial freeze.
