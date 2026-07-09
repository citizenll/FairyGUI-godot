# FairyGUI-godot

Pure GDScript FairyGUI runtime for Godot 4.x.

This repository starts from the TypeScript `FairyGUI-layabox/source` runtime because it is the cleanest reference in the local source tree: it is pure script, loads the current `.fui` package format, and keeps engine integration concentrated in a small display layer. The Godot port follows the same package/object model while mapping render nodes to Godot `Control` classes.

## Current Scope

- Loads uncompressed FairyGUI `.fui` descriptors and raw-deflate compressed package bodies used by FairyGUI exports.
- Parses package items, string tables, atlas sprite regions, component raw data, controllers, relations, gears, and child display lists.
- Creates Godot controls for components, images, movie clips, text, rich text, input text, loaders, graphs, groups, labels, buttons, progress bars, sliders, scroll bars, combo boxes, lists, trees, roots, windows, popups, and drag/drop helpers.
- Parses and runs controller actions and common transition timelines for position, size, scale, pivot, alpha, rotation, color, visibility, animation state, text, icon, nested transitions, and hooks.
- Supports loader alignment/fill options, component loader targets, bitmap-font package parsing/rendering, packaged audio playback, pixel hit-test masks, and flow/pagination list layout.
- Supports normal atlas regions through `AtlasTexture` and rotated/offset regions through generated `ImageTexture` sprites.
- Includes FairyGUI Laya demo package assets under `examples/assets/ui` and a smoke test that loads every demo package.

This is intentionally not a Godot engine module. The first target is a portable addon that can be dropped into a normal project.

## Quick Start

Open this folder as a Godot project and run `examples/minimal/main.tscn`.

Programmatic usage:

```gdscript
var pkg := FGUIPackage.add_package("res://examples/assets/ui/VirtualList")
var view := pkg.create_object("Main")
add_child(view.node)
```

For exported games, make sure `*.fui` is included in Godot's non-resource export filters.

## Verification

The repository is checked against the local Godot 4.5.2 build:

```powershell
& 'C:\toolkit\godot4-custom\bin\godot.windows.4.5.2.exe' --headless --check-only --script res://addons/fairygui/fairygui.gd
& 'C:\toolkit\godot4-custom\bin\godot.windows.4.5.2.exe' --headless --script res://tests/compression_probe.gd
& 'C:\toolkit\godot4-custom\bin\godot.windows.4.5.2.exe' --headless --script res://tests/pixel_hit_probe.gd
& 'C:\toolkit\godot4-custom\bin\godot.windows.4.5.2.exe' --headless --script res://tests/transition_probe.gd
& 'C:\toolkit\godot4-custom\bin\godot.windows.4.5.2.exe' --headless --script res://tests/smoke_test.gd
```

## Commercial Readiness

This is still a pure-GDScript port in progress, not a certified drop-in replacement for every FairyGUI runtime feature. The current milestone is suitable for loading real packages and validating Godot integration. Before shipping a commercial product on it, finish parity testing for complex transition timelines, very large virtual lists, editor import/export filters, and large UI performance.

## License

MIT, matching the upstream FairyGUI runtimes.
