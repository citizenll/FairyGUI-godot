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
- Uniform-size virtual lists support single-row, single-column, flow-horizontal, flow-vertical, and pagination layouts with pooled-item recycling, logical item renderer/provider indices, and visible selection state. Six-copy loop scrolling remains limited to single-row and single-column layouts; variable item measurements and loop mode for flow/pagination layouts are not implemented yet.
- Text fields support template variables, line spacing, outline/shadow settings, and Both/Height/Ellipsis auto-size behavior through Godot labels. Text inputs support FairyGUI `restrict` character ranges, inverse ranges, and escaped literals.
- Components support forward and reversed image/rectangle alpha masks. Forward masks use native `CanvasItem` clipping; reversed masks use a local Canvas shader and preserve texture alpha. Component input filtering follows mask bounds and configured pixel-hit tests.
- Scroll panes provide header/footer lock layout, top/bottom navigation, edge-drag `PULL_DOWN_RELEASE`/`PULL_UP_RELEASE` events, and `SCROLL_END` for completed pointer drags. Godot's native elastic overscroll animation is not replicated yet.
- Tree nodes support dynamic insertion, removal, reordering, selection, and single-click folder expansion with pooled cell refreshes.
- Windows attach through `GRoot`, preserve init/show/hide lifecycle callbacks, support content panes, close controls, modal root overlays, ordering, and modal-wait pane ownership.
- Transition XY paths support straight, quadratic/cubic Bezier, and Catmull-Rom segments with FairyGUI-compatible start offsets. Skew actions remain intentionally out of scope for the current milestone.
- Async object creation defers completion to the next frame and supports cancellation. Time-sliced construction of a single very large component is not implemented yet.
- Scale9, common widgets, list layout, scroll containers, bitmap fonts, audio, and pixel hit testing are present. Complex transition timelines, very large virtual lists, rendering comparison, and performance still require commercial-freeze parity work.
