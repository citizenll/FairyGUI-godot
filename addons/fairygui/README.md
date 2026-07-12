# FairyGUI Godot

FairyGUI Godot 是面向 Godot 4.x 的纯 GDScript FairyGUI 运行时与编辑器插件。当前版本主要使用 Godot 4.7 开发和测试，不保证所有 Godot 4.x 小版本均完全兼容。

## 安装

1. 保持本目录位于项目的 `addons/fairygui`。
2. 在 Godot 的“项目设置 > 插件”中启用 `FairyGUI`。
3. 将 FairyGUI Editor 导出的 `.fui` 及关联资源放入项目，等待导入完成。

## 编辑器预览

在场景中创建 `Control`，挂载 `res://addons/fairygui/ui/fui_view.gd`，然后将 `.fui` 文件拖到 Inspector 的 `package` 属性，并在 `component_name` 中选择需要预览的组件。

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
