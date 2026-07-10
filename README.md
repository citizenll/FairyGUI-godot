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

## Editor Workflow

Enable the FairyGUI addon in Project Settings, then attach
`res://addons/fairygui/ui/fui_view.gd` to an empty `Control` or create an
`FGUIView` node. The Inspector exposes a typed `Package` property: drag a
`.fui` file onto it and select the component from `Component Name`.

The addon imports `.fui` files into an `FGUIPackageResource`, creates an
in-editor preview, and instantiates the same component at runtime. An empty
`Control` sizes itself to the package component by default. Set
`match_control_size` when the package should instead fill a pre-sized Control.

Open `examples/editor_preview/fui_preview.tscn` to see the setup. The
generated `*.fui.import` files should be kept with project source so Godot can
preserve imported-resource UIDs across machines and exports.

## Verification

The repository is checked against Godot 4.7 Steam:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --check-only --script res://addons/fairygui/fairygui.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --editor --import --path .
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/editor_preview_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --editor --script res://tests/editor_hint_preview_probe.gd --path .
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/compression_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/pixel_hit_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/relation_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/scroll_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/transition_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/leak_probe.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --script res://tests/smoke_test.gd
```

## Commercial Readiness

This is still a pure-GDScript port in progress, not a certified drop-in replacement for every FairyGUI runtime feature. The current milestone is suitable for loading real packages, using `.fui` resources from the Inspector, and validating Godot integration. Before shipping a commercial product on it, finish parity testing for complex transition timelines, very large virtual lists, visual comparison, and large UI performance.

## License

MIT, matching the upstream FairyGUI runtimes.
