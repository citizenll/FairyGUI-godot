# Commercial Freeze

## Current Result

The 2026-07-12 freeze run completed with 77 passed checks, 0 failures, and 0 skipped checks on Godot `4.7.stable.steam.5b4e0cb0f`.

Run the same gate with:

```powershell
pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\run_commercial_freeze.ps1
```

Machine-readable and Markdown results are written to the ignored `.commercial-freeze/` directory. The script preserves an existing local `export_presets.cfg` and uses `tools/commercial_export_presets.cfg` only during validation.

## Verified Scope

- The complete FairyGUI preload graph parses under Godot 4.7.
- 53 headless behavior probes and the all-package component smoke test pass.
- `.fui` editor import, Inspector assignment, component selection, and `FGUIView` editor preview pass.
- Pixel, fill, blend, forward-mask, and reversed-mask probes pass on Compatibility/OpenGL, Mobile/D3D12, and Forward+/D3D12.
- Uniform million-item lists, sparse variable sizes, distant seeking, count mutation, loop mode, and bounded object recycling pass.
- Windows debug export starts and constructs every component in every bundled demo package from the exported PCK.
- Linux, Web, Android arm64, unsigned universal macOS, and iOS Xcode project exports are generated from official Godot 4.7 templates.
- The Web export was loaded in Chromium at 1280x720. Rendering, selecting item 500, scrolling to item 999, and browser console checks passed.

## Platform Limits

- Windows and Web were executed locally.
- Android produced a debug-signed arm64 APK and passed Godot's APK verification, but no Android device or AVD was available for runtime execution.
- Linux and macOS artifacts were generated on Windows but were not executed on their target operating systems.
- iOS validation generates an Xcode project only. Compilation, signing, App Store validation, and device execution require macOS, Xcode, and the product team's real Apple Team ID and provisioning profile.
- The headless Godot 4.7 editor emits engine-level RID leak diagnostics when a `--editor --script` main loop exits. The preview probe verifies FairyGUI reference counts and allows only those known engine shutdown diagnostics.

## Deliberate Exceptions

- Transition skew actions are intentionally unsupported for this milestone, as requested.
- FairyGUI custom blend slots 1-3 fall back to normal blending. Standard exported blend modes are covered by pixel tests.
- Spine, DragonBones, and similar third-party content require a project-provided `FGUILoader3D` content factory.
- Shipping projects must still run their own real-package screenshot baselines, target-device performance budgets, localization/font coverage, accessibility review, and platform store compliance.

The runtime code is MIT licensed. This freeze is a reproducible engineering baseline, not a universal certification for every external FairyGUI package or third-party asset.
