# FairyGUI Godot 编辑器工作流第二阶段规范

状态：已实施
适用版本：Godot 4.x，主要在 Godot 4.7 上验证

## 1. 目标

第二阶段把 FairyGUI 的字符串事件 API 提升为接近 Godot 原生信号连接的编辑器工作流：

1. 在 `FGUIView` Inspector 中查看、创建、移除和诊断事件绑定。
2. 从真实 `.fui` 层级选择目标对象和该对象支持的事件。
3. 自动在界面业务脚本中生成类型明确的处理函数。
4. 从 GUI 预览中选择对象并直接跳转到对应的事件绑定目标。
5. 事件绑定随场景保存，在运行时自动连接，并在预览重建时安全重连。

## 2. 强制约束

- 目标层级必须来自当前 `FGUIPackageResource` 实际构建出的 FairyGUI 对象树。
- 目标使用由 FairyGUI 语义名称组成的路径，不保存对象索引或临时实例 ID。
- 未命名父节点下的对象不能建立持久绑定，避免 `.fui` 重排后错误连接。
- 事件列表根据对象实际类型生成，不向用户提供已知不适用的专用事件。
- 连接信息保存到场景，业务脚本仅保存用户处理函数，二者职责分离。
- 不覆盖、重排或重新生成已有用户代码；只在函数不存在时追加一个处理函数。
- 相同目标、事件、函数和捕获模式不得重复连接。

## 3. P2-1：场景化事件绑定

`FGUIEventBinding` 是可序列化 `Resource`，包含：

- `enabled`：是否启用。
- `target_path`：从组件根对象开始的语义名称路径，空路径表示根对象 `ui`。
- `event_name`：真实 FairyGUI 事件值，例如 `onClick`。
- `handler`：业务脚本中的处理函数名。
- `capture`：是否在捕获阶段监听。

`FGUIView.event_bindings` 保存绑定数组。运行时在 FairyGUI 对象创建完成后连接事件；包、组件或预览重建前先断开旧对象连接，再对新对象连接一次。

绑定资源启用 `resource_local_to_scene`，同一 `PackedScene` 的多个实例各自持有绑定配置，运行时启停某个实例不会修改其他实例。

普通监听使用 `add_event_listener()`，处理函数接收 `FGUIEventContext`：

```gdscript
func _on_start_button_clicked(event: FGUIEventContext) -> void:
	print(event.sender, event.data)
```

`FGUIEventContext` 来自对象池，只能在回调执行期间使用，不应保存到成员变量供后续访问。

## 4. P2-2：Inspector 事件面板

`FGUIView` Inspector 增加“FairyGUI 事件连接”区域：

- 现有绑定列表显示目标、事件、处理函数和诊断状态。
- 目标选择器递归展示真实 `.fui` 命名对象。
- 事件选择器根据 Button、List、TextInput、Slider、MovieClip 和可滚动组件等实际类型提供适用事件。
- 处理函数名按目标名称和事件确定性生成，允许用户在连接前修改。
- 支持普通监听和捕获监听。
- 支持生成或打开处理函数、启用/停用绑定、移除绑定。

原始 `event_bindings` 数组在插件启用时由专用面板替代；插件关闭后仍可由 Godot 默认 Resource Inspector 查看，不影响场景数据。

## 5. P2-3：处理函数生成

连接事件前检查当前 `FGUIView` 是否已挂载界面业务脚本。处理函数不存在时，在用户脚本末尾追加：

```gdscript
func _on_start_button_clicked(_event: FGUIEventContext) -> void:
	pass
```

要求：

- 函数名必须是有效的 ASCII GDScript 标识符。
- 已存在同名函数时只定位，不追加重复函数。
- 已存在相同事件连接时不重复添加；该操作改为打开处理函数，函数被删除时自动补全。
- 已在 ScriptEditor 打开的脚本以 `CodeEdit` 当前内容为准，不能依赖 `@tool` 脚本可能滞后的 `GDScript.source_code`。
- 生成时一并保存编辑器尚未写盘的当前脚本修改，并同步磁盘文件、脚本资源和 ScriptEditor 缓冲区，后续保存不得覆盖生成结果。
- 新源码通过 GDScript 校验后，使用临时文件和备份完成原子替换。
- 校验、写入或脚本重载失败时恢复原文件和原脚本资源，不添加场景绑定。
- 同一 `FGUIView` 的脚本修改串行执行；Godot 正在扫描或导入资源时等待完成，避免并发写入同一脚本。
- 写入后重新加载原脚本资源，并定位到处理函数行。
- 场景 Undo 会撤销事件绑定，但不会删除已经生成的用户函数，避免误删用户随后写入的逻辑。

## 6. P2-4：GUI 预览联动

从 `FGUIView` Inspector 打开 GUI 预览时，预览面板保存当前视图上下文。

选择左侧层级或右侧画布中的对象后，“绑定事件”会：

1. 计算该对象相对组件根节点的真实名称路径。
2. 选择场景中的对应 `FGUIView`。
3. 打开 Inspector 的事件绑定面板。
4. 自动选中同一目标对象。

直接双击 `.fui` 打开的资源预览没有场景上下文，因此不允许创建场景事件绑定。预览切换到与 `FGUIView.component_name` 不一致的组件时同样禁用该操作。

## 7. P2-5：诊断与失败策略

Inspector 对每项绑定检查：

- 目标路径能否在当前真实组件中解析。
- 目标类型是否支持所选事件。
- 处理函数是否存在。
- 是否与已有项重复。
- 绑定资源是否为空。

处理函数生成失败时不添加场景绑定。目标在运行时缺失或函数不存在时跳过该项并输出明确警告，不阻止其余 UI 和事件继续工作。

编辑器操作必须显示处理中状态，并通过 Godot Toast 明确报告成功、重复连接或失败原因，不能只写入 Output 面板造成“点击无反应”的假象。

业务脚本自动挂载、手工挂载及 Undo/Redo 切换脚本时，必须保留 `event_bindings`、package、component 和其他 `FGUIView` 配置。

## 8. 事件范围

第二阶段覆盖：

- 通用指针：点击、右键、按下、释放、进入、移出、拖动和接收拖放。
- 状态控件：Button、ComboBox、Slider、TextInput 的状态改变。
- List/Tree：点击 Item、右键 Item。
- 滚动组件：滚动、滚动结束、下拉释放、上拉释放。
- TextInput：提交、获得焦点、失去焦点。
- TextField：点击链接。
- MovieClip：播放结束。
- Slider：滑块释放。

Controller 和 Transition 不是 FairyGUI 显示对象路径，本阶段不混入对象目标选择器；Controller 仍可在业务代码中通过生成绑定直接监听。

## 9. 验收标准

1. 绑定可以保存到 `.tscn` 并重新加载，所有字段保持一致。
2. 运行时点击事件向处理函数传入 `FGUIEventContext`。
3. 刷新或重建 `FGUIView` 后事件只触发一次，不丢失也不重复。
4. 禁用绑定后立即断开运行时监听。
5. Inspector 从真实 `Basics.fui` 解析 `btn_Button`，而不是使用固定目标列表。
6. 自动生成处理函数通过 GDScript 校验，重复打开不会生成第二份。
7. 添加、启停和移除绑定进入场景 Undo/Redo。
8. GUI 预览选择对象后，Inspector 自动定位同一目标。
9. 业务脚本替换和撤销后，事件绑定配置保持不变。

## 10. 实施映射

| 项目 | 主要实现 | 验证 |
| --- | --- | --- |
| P2-1 场景化绑定 | `event_binding.gd`、`fui_view.gd` | `event_binding_probe.gd` |
| P2-2 Inspector 面板 | `event_binding_inspector.gd`、`event_binding_service.gd` | `event_binding_editor_probe.gd` |
| P2-3 函数生成 | `event_handler_generator.gd`、`plugin.gd` | `event_binding_editor_probe.gd` |
| P2-4 预览联动 | `fui_preview_panel.gd`、`plugin.gd` | `event_binding_editor_probe.gd` |
| P2-5 配置与诊断 | `event_binding_service.gd`、`binding_inspector_plugin.gd` | `business_script_editor_probe.gd`、`event_binding_editor_probe.gd` |
