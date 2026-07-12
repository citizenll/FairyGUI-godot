# FairyGUI Godot

FairyGUI Godot 是面向 Godot 4 的纯 GDScript FairyGUI 运行时与编辑器插件。它可以直接读取 FairyGUI Editor 导出的 `.fui` 包，在 Godot 编辑器中预览组件，并在运行时保持 FairyGUI 的包、组件、控制器、关系、Gear、Transition 和事件模型。

本项目不修改 Godot 源码，也不需要编译 GDExtension 或引擎模块。将插件目录放入项目并启用后即可使用。

![FairyGUI Godot 示例首屏](docs/demo-main-menu.png)

## 主要功能

- 将 `.fui` 导入为 `FGUIPackageResource`，支持在 Inspector 中拖放资源和实时预览组件。
- 支持未压缩及 raw-deflate 压缩的 FairyGUI 包、图集切片、依赖包和高分辨率资源分支。
- 支持组件、图片、动画、文本、富文本、输入框、Loader、Graph、Group、按钮、标签、进度条、滑动条、滚动条、下拉框、列表、树、窗口、弹窗等常用对象。
- 支持 Controller、Relation、Gear、Transition、路径动画、缓动、循环、暂停、时间缩放和嵌套动画。
- 支持鼠标与触摸输入、拖放、滚动、惯性、回弹、吸附、下拉刷新、横向滚动和列表选择。
- 支持虚拟列表、循环列表、对象池和按可视区域回收，适合大数据量列表。
- 支持 Scale9、平铺、颜色与灰度、常用混合模式、图形遮罩、反向遮罩、像素命中测试及多种进度填充方式。
- 支持位图字体、音频、翻译文本、异步 UI 构建、外部纹理和外部场景加载。
- `FGUILoader3D` 可显示 Godot 2D/3D 场景；Spine、DragonBones 等第三方运行时可通过内容工厂接入。

## 环境要求

- Godot 4.x。当前主要在 Godot 4.7 上开发和测试，不保证所有 Godot 4.x 小版本均完全兼容。
- FairyGUI Editor 导出的 `.fui` 文件及其图集、字体、音频等资源。
- 项目使用 GDScript；无需 C#、GDExtension 或自定义 Godot 构建。

## 安装

1. 将仓库中的 `addons/fairygui` 复制到目标 Godot 项目的 `addons` 目录。
2. 打开 Godot，在“项目设置 > 插件”中启用 `FairyGUI`。
3. 将 FairyGUI 导出的 `.fui` 和关联资源放入项目，等待 Godot 完成导入。

建议将 `.fui` 及对应的 `.fui.import` 文件一并纳入版本管理，以保持资源 UID 和导入结果稳定。

## 编辑器预览

1. 在场景中创建一个空的 `Control`。
2. 挂载 `res://addons/fairygui/ui/fui_view.gd`，或直接创建 `FGUIView` 节点。
3. 将 `.fui` 文件拖到 Inspector 的 `package` 属性。
4. 在 `component_name` 中选择需要显示的组件。

`FGUIView` 提供以下常用选项：

- `preview_in_editor`：是否在编辑器中显示预览。
- `resize_to_content`：是否让节点尺寸跟随 FairyGUI 组件。
- `match_control_size`：是否让 FairyGUI 组件匹配当前 `Control` 尺寸。

参考场景位于 `examples/editor_preview/fui_preview.tscn`。

## 运行时使用

下面的示例加载 `res://ui/Main.fui`，创建其中的 `Main` 组件并加入 FairyGUI 根节点：

```gdscript
extends Control

var _package: FGUIPackage
var _view: FGUIComponent


func _ready() -> void:
	var root := FGUIRoot.get_inst()
	root.attach_to(self)

	_package = FGUIPackage.add_package("res://ui/Main")
	if _package == null:
		return

	_view = _package.create_object("Main") as FGUIComponent
	if _view == null:
		return

	root.add_child(_view)
	_view.make_full_screen()

	var start_button := _view.get_child("start")
	if start_button != null:
		start_button.on(FGUIEvents.CLICK, _on_start_clicked)


func _on_start_clicked(_event: Variant) -> void:
	print("start")
```

也可以不使用 `FGUIRoot`，直接把对象对应的 Godot 节点加入现有场景树：

```gdscript
var package := FGUIPackage.add_package("res://ui/Inventory")
var inventory := package.create_object("Main")
add_child(inventory.node)
```

## 示例

- `demo.tscn`：完整示例入口，覆盖基础控件、Transition、虚拟列表、循环列表、命中测试、下拉刷新、窗口、拖放、树、遮罩和冷却效果等功能。
- `examples/minimal/main.tscn`：最小运行时接入示例。
- `examples/editor_preview/fui_preview.tscn`：`.fui` Inspector 资源与编辑器预览示例。

直接使用 Godot 打开仓库并运行项目，即可进入完整示例。

## 商业项目使用

本项目采用 MIT License，可用于个人和商业项目。正式上线前仍应使用项目自己的 `.fui` 包、字体、语言、输入方式和目标设备完成回归测试，并根据实际界面规模进行性能分析。

建议在生产项目中遵循以下原则：

- 大数据列表使用虚拟列表和对象池，避免一次创建全部 Item。
- 高频变化的复杂遮罩、超大位图文本和大量同时运行的 Transition 需要在目标设备上测量开销。
- Spine、DragonBones 等内容应使用项目已获得授权并适配 Godot 的运行时。
- `examples` 中的演示资源用于功能展示和兼容性验证，产品发布前应确认其授权范围或替换为自有资源。

## 当前兼容边界

- Transition 的 `skew` 动作暂不支持。
- FairyGUI 自定义混合槽位 1-3 当前按普通混合模式处理。
- Spine、DragonBones 不随插件捆绑，需要通过 `FGUILoader3D.set_content_factory` 接入对应运行时。
- 本项目面向 Godot 4.x，仓库工程及当前回归测试使用 Godot 4.7；其他 Godot 4.x 小版本需要由项目自行验证。

## 项目结构

```text
addons/fairygui/          FairyGUI 运行时、编辑器导入器与预览组件
examples/                 完整示例、最小接入示例及示例资源
demo.tscn                 示例项目入口
project.godot             示例项目配置
```

## 许可

项目新增代码使用 [MIT License](LICENSE.md)。FairyGUI 上游版权声明及演示资源说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

MIT License 不包含任何质量担保。使用方需要自行确认第三方资源、字体、音频及外部运行时的授权。
