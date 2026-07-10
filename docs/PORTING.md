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
- `GObject` provides pivot-aware local/global point and rectangle transforms, cross-object/root-space conversion, disposal state, focus requests, parent-constrained fullscreen sizing, move/scale/resize/fade/rotation tween convenience methods, and reusable object/component hit testing while retaining physical node-local coordinates for input controls.
- `FGUIGTween` is driven automatically from the Godot frame loop and supports scalar through four-value, color, path, shake, delay, repeat/yoyo, pause, snapping, target-property/callback, lookup, and kill workflows.
- `FGUIPackage.branch` and `FGUIPackage.set_branch` update loaded package branch indices, so branch-specific resources are selected for newly constructed UI objects.
- `FGUIRoot.content_scale_factor` derives `FGUIRoot.content_scale_level`; package items use configured 2x, 3x, and 4x high-resolution variants when available.
- Compressed FairyGUI packages use the bundled raw-deflate implementation and are covered by the compression probe.
- Virtual lists support single-row, single-column, flow-horizontal, flow-vertical, and pagination layouts with pooled-item recycling, logical item renderer/provider indices, and visible selection state. Single-row and single-column lists cache renderer-provided item sizes for variable primary-axis layout and six-copy loop scrolling. Flow/pagination layouts remain uniform-cell; loop mode remains limited to single-row and single-column layouts.
- Multiple list selection supports ordinary replacement selection, Ctrl toggles, Shift ranges, and multiple-single-click toggles in both regular and virtual lists.
- Text fields support template variables, line spacing, outline/shadow settings, and Both/Height/Ellipsis auto-size behavior through Godot labels. Text inputs support FairyGUI `restrict` character ranges, inverse ranges, and escaped literals.
- Rich-text UBB is converted to Godot BBCode for basic styling, colors, sizes, links, package images, alignment, line breaks, and escaped tags; remove mode remains available for plain-text inputs.
- Loaders preserve package MovieClip frame playback and propagate `playing`, `frame`, and `time_scale` to loaded movie content.
- Buttons, component hit areas, drag operations, sliders, combo boxes, scroll bars, and window focus handling accept Godot screen-touch input in addition to mouse input. Object drags use configurable mouse/touch thresholds, root-relative bounds, and a global input relay; `FGUIDragDropManager` supplies a touch-disabled drag agent and dispatches `DROP` payloads containing `data`, `source`, and `event`.
- `GRoot` tracks Godot Viewport resizing, manages nested popup stacks, automatic up/down placement, target-relative coordinates, outside-pointer dismissal, configured/custom tooltip windows, root-level modal waits, bulk window closure, top-window lookup, and FairyGUI-to-Godot input focus. Objects fall back to Godot native tooltip text when no FairyGUI tooltip resource is configured.
- `FGUITranslationHelper.load_from_xml` parses FairyGUI translation XML. Load translations before adding packages so component text, prompts, list entries, controller text, labels, buttons, and combo boxes are localized during package construction.
- Components support forward and reversed image/rectangle alpha masks. Forward masks use native `CanvasItem` clipping; reversed masks use a local Canvas shader and preserve texture alpha. Component input filtering follows mask bounds and configured pixel-hit tests.
- Controller display gears implement page visibility, secondary AND/OR display conditions, transition display locks, and grouped-child visibility propagation.
- Groups support horizontal/vertical automatic bounds, grouped-child movement and alpha propagation, proportional resize distribution, main-grid minimum sizing, and invisible-child exclusion.
- Scroll panes provide header/footer lock layout, top/bottom navigation, cancellable programmatic tweening for animated positioning and `scroll_to_view`, velocity-based pointer inertia honoring `inertiaDisabled`, component item/page snap settling after pointer drags, edge-drag `PULL_DOWN_RELEASE`/`PULL_UP_RELEASE` events, and `SCROLL_END` for completed pointer drags. Godot's native elastic overscroll animation is not replicated yet.
- Tree nodes support dynamic insertion, removal, reordering, selection, and single-click folder expansion with pooled cell refreshes.
- Windows attach through `GRoot`, preserve init/show/hide lifecycle callbacks, support content panes, close controls, modal root overlays, ordering, and modal-wait pane ownership.
- Transition XY paths support straight, quadratic/cubic Bezier, and Catmull-Rom segments with FairyGUI-compatible start offsets. Skew actions remain intentionally out of scope for the current milestone.
- `FGUIAsyncOperation` collects package display lists, builds package objects against `FGUIConfig.frame_time_for_async_ui_construction`, reuses prebuilt component/list children, defers completion to a frame boundary, and disposes pending work on cancellation.
- Scale9, common widgets, list layout, scroll containers, bitmap fonts, audio, and pixel hit testing are present. Complex transition timelines, very large virtual lists, rendering comparison, and performance still require commercial-freeze parity work.
