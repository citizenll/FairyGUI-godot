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
- FairyGUI's exported additive blend mode is mapped to Godot canvas-item additive blending and remains active with direct color-filter/gray shaders. Unsupported blend-mode codes fall back to normal blending.
- `GObject` provides pivot-aware local/global point and rectangle transforms, cross-object/root-space conversion, disposal state, focus requests, parent-constrained fullscreen sizing, move/scale/resize/fade/rotation tween convenience methods, and reusable object/component hit testing while retaining physical node-local coordinates for input controls.
- `GObject` retains requested raw dimensions under min/max constraints, preserves both anchored and non-anchored pivot geometry during resize, and synchronizes position, size/scale, and look changes with FairyGUI gears.
- `FGUIGTween` is driven automatically from the Godot frame loop and supports scalar through four-value, color, path, shake, delay, repeat/yoyo, pause, snapping, target-property/callback, lookup, and kill workflows.
- `FGUIPackage.branch` and `FGUIPackage.set_branch` update loaded package branch indices, so branch-specific resources are selected for newly constructed UI objects.
- `FGUIPackage` exposes URL asset lookup, synchronous callback-compatible asset requests, bulk preloading, unload/reload, and Godot-native miscellaneous resource/text/byte loading. `FGUIPackage.set_strings_source` mirrors the upstream translation entry point.
- `FGUIRoot.content_scale_factor` derives `FGUIRoot.content_scale_level`; package items use configured 2x, 3x, and 4x high-resolution variants when available.
- Compressed FairyGUI packages use the bundled raw-deflate implementation and are covered by the compression probe.
- Virtual lists support single-row, single-column, flow-horizontal, flow-vertical, and pagination layouts with pooled-item recycling, logical item renderer/provider indices, visible selection state, `scroll_to_view` visibility/`set_first` behavior, runtime `virtual_item_size`/gap layout refreshes, and horizontal/vertical content alignment. `auto_resize_item` fills single-axis viewports and explicit flow/pagination grid cells. Single-row and single-column lists cache renderer-provided item sizes for variable primary-axis layout and six-copy loop scrolling. Pagination loop scrolling follows FairyGUI's six-copy physical-list behavior; flow layouts remain uniform-cell and do not support loop mode.
- Ordinary and virtual lists return the selected logical index from arrow-key navigation, preserve rows/columns across flow and pagination layouts, and resize the correct view axis in `resize_to_fit`.
- Regular lists retain FairyGUI's default opaque, bounds-tracked layout and reflow auto-resized cells after size changes. Multiple list selection supports ordinary replacement selection, Ctrl toggles, Shift ranges, and multiple-single-click toggles in both regular and virtual lists.
- Text fields support exported system/resource font names, `FGUIConfig.default_font`, bold/italic/underline flags, glyph spacing, template variables, line spacing, outline/shadow settings, measured text dimensions, explicit size refresh, and Both/Height/Shrink/Ellipsis auto-size behavior through Godot labels. Text inputs switch between native `TextEdit` multiline mode and `LineEdit` single-line/password mode while preserving text, input settings, UBB prompt text/color, and font/outline/shadow styling; they also support FairyGUI `restrict` character ranges, inverse ranges, escaped literals, and `max_length`.
- Labels forward editable, color, font-size, and outline properties to nested text/input controls and parse exported prompt, restrict, max-length, keyboard-type, and password settings for input-backed label components.
- Rich-text UBB is converted to Godot BBCode for basic styling, colors, sizes, links, package images, alignment, line breaks, and escaped tags. Ordinary text fields with `ubbEnabled` switch to the same RichText renderer while preserving their parent display placement and visual state. Rich text fields preserve base text alignment, outline/shadow, wrapping, automatic content sizing, and pointer click delivery; remove mode remains available for plain-text inputs.
- Movie clips support elapsed-time seeking, swing playback, repeat delays, and bounded play settings; transitions fast-forward animation actions when starting from a nonzero timestamp. Loaders preserve MovieClip playback and propagate `playing`, `frame`, `time_scale`, and elapsed-time updates to loaded movie content. `FGUIConfig.loader_error_sign` displays a pooled FairyGUI component for failed loader requests. External loaders support imported textures, runtime image files, and HTTP(S) PNG/JPEG/WebP/BMP/TGA/SVG responses with stale-response protection.
- `GLoader3D` instantiates external `PackedScene` content, lays out CanvasItem/Control content, and renders Node3D scenes through an internal `SubViewport`. Register `FGUILoader3D.set_content_factory` for package Spine/DragonBones or another third-party runtime; the factory receives the resolved package item or external path and returns a Node or `{ node, size, owns_content }` dictionary.
- Buttons, component hit areas, drag operations, sliders, combo boxes, scroll bars, and window focus handling accept Godot screen-touch input in addition to mouse input. Object drags use configurable mouse/touch thresholds, root-relative bounds, and a global input relay; `FGUIDragDropManager` supplies a touch-disabled drag agent and dispatches `DROP` payloads containing `data`, `source`, and `event`.
- Buttons synchronize Up/Over/Down/Selected/Disabled controller pages, honor controller automatic radio-group depth, support tint/scale down effects, expose title outline properties, run the upstream Over/Down/Up programmatic click sequence, and toggle linked popups or windows without reopening a popup closed by the same propagated pointer event.
- Combo boxes rebuild pooled dropdown rows from runtime item/value/icon arrays, size the list to the configured visible count, synchronize button hover/down state with popup lifetime, dispatch selection changes, and expose title color/font/outline properties through FairyGUI gears.
- Package-version-5 click/stage sound fields and version-6 Loader3D animation/skin Gear and Transition values are parsed and dispatched.
- Popup menus support pooled insertion at arbitrary positions, separators, runtime text/visibility/disabled state, checkable and checked controller pages, deferred callbacks after popup closure, removal/clearing, and cleanup of open root popup stacks during disposal.
- `GRoot` tracks Godot Viewport resizing, manages nested popup stacks, pointer or target-relative placement, automatic/explicit/legacy-boolean directions, outside-pointer dismissal, configured/custom tooltip windows, root-level modal waits, animated bulk window closure, top-window lookup, modal-safe window ordering, and FairyGUI-to-Godot input focus. Objects fall back to Godot native tooltip text when no FairyGUI tooltip resource is configured.
- `FGUITranslationHelper.load_from_xml` parses FairyGUI translation XML. Load translations before adding packages so component text, prompts, list entries, controller text, labels, buttons, and combo boxes are localized during package construction.
- Components support forward and reversed image/rectangle alpha masks. Forward masks use native `CanvasItem` clipping; reversed masks use a local Canvas shader and preserve texture alpha. Native Godot `Control` hit testing also follows component opacity, mask bounds, and configured child hit targets.
- Components expose `display_list_container` for custom native content and non-mutating `base_user_data` access for package extension metadata.
- Component child-bound recalculation is coalesced to the end of the current frame, keeping ScrollPane content dimensions current after dynamic add, remove, move, or resize operations.
- Controller display gears implement page visibility, secondary AND/OR display conditions, transition display locks, and grouped-child visibility propagation. XY, size/scale, look, and color gears honor packaged delay, duration, standard/custom easing, display locks, global tween suppression, retarget cancellation, and `GEAR_STOP` completion events.
- Controllers expose runtime page insertion/removal, silent selection changes, opposite-page selection, page ID/name lookup, and `FGUIEvents.STATE_CHANGED` listeners.
- Groups support horizontal/vertical automatic bounds, grouped-child movement and alpha propagation, proportional resize distribution, main-grid minimum sizing, and invisible-child exclusion.
- Scroll panes provide header/footer lock layout, top/bottom navigation, cancellable programmatic tweening for animated positioning and object/`Rect2` `scroll_to_view`, velocity-based pointer inertia honoring `inertiaDisabled`, component item/page snap settling after pointer drags, edge-drag `PULL_DOWN_RELEASE`/`PULL_UP_RELEASE` events, configurable FairyGUI-style mouse-wheel steps and page movement, and `SCROLL_END` for completed pointer drags. Dynamic content-size changes preserve trailing edges, active drag offsets, and inertia targets; variable-size virtual lists compensate newly measured leading cells. Leading/trailing edge drags render resistance and return animation when `bounceback_effect` is enabled. Components expose first-child and per-child viewport queries for both clipping and scroll panes.
- Tree nodes default folders to collapsed, support dynamic insertion, removal, indexed/object swapping, selection, pre-expanded lazy-load callbacks, and controller or single-click folder expansion with pooled cell refreshes.
- Windows attach through `GRoot`, wait for cancellable `FGUIUISource` dependencies before initialization, expose overridable show/hide animation hooks, keep content panes size-related, configure frame close/drag/content controls, and support modal root overlays, ordering, and correctly nested modal-wait pane placement.
- Transition XY paths support straight, quadratic/cubic Bezier, and Catmull-Rom segments with FairyGUI-compatible start offsets. Package-version-4 custom easing paths are sampled and used by transitions and `GTweener`. Active transitions propagate pause/resume and time-scale changes to nested transitions and animation targets. Stopping with completion finishes only currently scheduled actions, honors end-time breakpoints, and leaves an initial delayed timeline untouched. Skew actions remain intentionally out of scope for the current milestone.
- `FGUIAsyncOperation` collects package display lists, builds package objects against `FGUIConfig.frame_time_for_async_ui_construction`, reuses prebuilt component/list children, defers completion to a frame boundary, and disposes pending work on cancellation.
- `FGUIObjectFactory` accepts script classes or bound `Callable` creators for package components, 2D loaders, and 3D loaders, and can be reset with `clear()`. `FGUIObjectPool.init_callback` runs only for newly constructed objects, not reused entries.
- Relation constraints distinguish package construction from runtime target resizing for parent-to-child width, height, and extended-edge formulas; active group layout passes suppress recursive target-size application while preserving the next delta baseline.
- Scale9, common widgets, list layout, scroll containers, bitmap fonts, audio, and pixel hit testing are present. `GImage` and `GLoader` support horizontal, vertical, Radial90, Radial180, and Radial360 fill meshes, including progress-bar fill amount updates. Complex transition timelines, very large virtual lists, rendering comparison, and performance still require commercial-freeze parity work.
- Progress bars support cancellable linear `tween_value` updates and recalculate fills after runtime range, title-mode, reverse, or size changes. Sliders preserve the initial percentage during grip drags, use the exported usable bar length, honor reverse/whole-number modes, and keep grip presses separate from track clicks.
