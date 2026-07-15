# FairyGUI Godot

FairyGUI Godot 是面向 Godot 4.x 的纯 GDScript FairyGUI 运行时与编辑器插件。当前版本主要使用 Godot 4.7 开发和测试，不保证所有 Godot 4.x 小版本均完全兼容。

## 安装

1. 保持本目录位于项目的 `addons/fairygui`。
2. 在 Godot 的“项目设置 > 插件”中启用 `FairyGUI`。
3. 将 FairyGUI Editor 导出的 `.fui` 及关联资源放入项目，等待导入完成。

## 编辑器预览

在场景中创建 `Control`，挂载 `res://addons/fairygui/ui/fui_view.gd`，然后将 `.fui` 文件拖到 Inspector 的 `package` 属性，并在 `component_name` 中选择需要预览的组件。

也可以直接将 `.fui` 或 GUI 预览层级树中的组件拖入 2D 画布，插件会创建已配置的 `FGUIView` 并接入 Undo/Redo。

## 强类型绑定

`.fui` 导入后会生成 `res://generated/fairygui` 下的强类型组件类。也可以使用“项目 > 工具 > Generate FairyGUI Bindings”或 Inspector 中的“生成绑定”手工生成。

```gdscript
@onready var ui: UI_InventoryMain = %InventoryView.fairy as UI_InventoryMain


func _ready() -> void:
	ui.item_list.on(FGUIEvents.CLICK_ITEM, _on_item_clicked)
```

生成成员按 FairyGUI 名称绑定，不依赖索引；生成失败会保留上一份可用文件。`fairygui/codegen` 项目设置可调整自动生成、输出目录、注册表、类名前缀和默认名称策略。

`FGUIView` Inspector 中的“创建界面脚本”会从真实 `.fui` 包 ID、组件 ID 和生成清单解析绑定，生成使用实际绑定脚本的 `UI_TYPE`，不会固定使用示例类名。Inspector 同时显示包依赖、外部资源和绑定新鲜度诊断。

## 运行时示例

```gdscript
var package := FGUIPackage.add_package("res://ui/Main")
var view := package.create_object("Main")
add_child(view.node)
```

完整文档、示例和已知兼容边界：

https://github.com/citizenll/FairyGUI-godot

## 许可

项目新增代码使用 MIT License。FairyGUI 上游版权声明见 `THIRD_PARTY_NOTICES.md`。
