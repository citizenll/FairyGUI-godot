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
6. Editor importer, typed package resources, in-editor preview, and validation.

## Compatibility Notes

- The editor importer turns `.fui` files into `FGUIPackageResource` assets. Imported packages are included in exported projects; `FileAccess` remains a fallback for direct raw loading.
- Compressed FairyGUI packages use the bundled raw-deflate implementation and are covered by the compression probe.
- Single-column and single-row virtual lists support six-copy loop scrolling, logical item renderer/provider indices, visible selection state, and pooled-item recycling. Loop mode for flow and pagination layouts is not implemented yet.
- Text fields support template variables, line spacing, outline/shadow settings, and Both/Height/Ellipsis auto-size behavior through Godot labels.
- Components support forward image/rectangle alpha masks through native `CanvasItem` clipping, including matching component input filtering. Reversed masks are not implemented yet.
- Scroll panes provide header/footer lock layout and top/bottom navigation. Native touch overscroll and pull-release events are not implemented yet.
- Scale9, common widgets, list layout, scroll containers, bitmap fonts, audio, and pixel hit testing are present. Complex transition timelines, very large virtual lists, rendering comparison, and performance still require commercial-freeze parity work.
