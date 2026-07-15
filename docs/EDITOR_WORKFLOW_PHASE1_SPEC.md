# FairyGUI Godot 编辑器工作流第一阶段规范

状态：已实施  
适用版本：Godot 4.x，主要在 Godot 4.7 上验证

## 1. 目标

第一阶段把 FairyGUI 从“可以导入和运行”提升为完整的 Godot 编辑器工作流：

1. 将 `.fui` 或 GUI 预览中的组件拖入 2D 画布，自动创建 `FGUIView`。
2. 从 `FGUIView` 一键创建业务脚本，并获得当前组件的强类型绑定。
3. 在 Inspector 中直接显示包、依赖、资源和代码生成诊断。
4. 游戏从编辑器运行时，在调试器中检查 FairyGUI 逻辑树并高亮对象。
5. `.fui` 重新导入或切换组件后，恢复 GUI 预览的工作状态。

## 2. 强制约束：真实解析 `.fui`

所有组件名、包 ID、组件 ID、绑定 URL、生成脚本路径和业务脚本类型都必须来自当前导入的 `FGUIPackageResource` 及其真实 `.fui` 内容。

禁止：

- 在模板中固定使用 `Main`、`Basics` 或 `UI_BasicsMain`。
- 仅根据文件名拼接绑定类名。
- 假定每个包都存在 `Main`。
- 在找不到组件或绑定时生成一个可能编译但类型错误的脚本。

组件解析规则：

1. 使用 Inspector 或拖放数据中明确指定的组件名。
2. 未指定时，如果包中真实存在 `Main`，选择 `Main`。
3. 否则选择 `.fui` 中第一个真实组件。
4. 包中没有组件时停止操作并给出错误。

绑定解析规则：

1. 从真实包 ID 和组件 ID 构造 `ui://<package_id><component_id>`。
2. 从代码生成 manifest 查询该 URL 对应的脚本路径。
3. manifest 缺失或过期时先执行代码生成。
4. 业务脚本通过 `preload(<真实生成脚本路径>)` 获得类型，不依赖固定类名。

## 3. P1-1：拖放创建 `FGUIView`

### 输入

- Godot 文件系统中的单个 `.fui` 文件。
- GUI 预览层级树中的 FairyGUI 组件。

### 行为

- 只在 2D 编辑器画布处理 FairyGUI 拖放，不影响 Godot 原有场景、纹理、音频和资源拖放。
- 自动加载 `FGUIPackageResource`，按第 2 节规则解析组件。
- 创建 `FGUIView`，设置 `package`、`component_name`、`preview_in_editor` 和 `resize_to_content`。
- 节点名称来源于真实组件名，并使用 Godot 的可读唯一命名。
- 放置位置使用 2D 编辑器当前画布变换转换到目标父节点坐标。
- 创建操作必须进入 Godot Undo/Redo 历史。

### 验收

- 拖入 `Basics.fui` 创建的节点使用该包真实组件。
- 拖入不含 `Main` 的包时选择第一个真实组件。
- 从预览树拖动嵌套导出组件时使用该组件所属包和真实组件名。
- 普通 Godot 文件拖放行为不受影响。

## 4. P1-2：动态业务脚本

Inspector 为 `FGUIView` 提供“创建界面脚本”操作。已有业务脚本时，该操作改为打开脚本。

生成脚本结构：

```gdscript
@tool
extends FGUIView

const UI_TYPE := preload("res://generated/fairygui/<真实路径>.gd")

var ui: UI_TYPE


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	ui = fairy as UI_TYPE
	if ui == null:
		push_error("FairyGUI binding mismatch: <真实包>/<真实组件>")
```

要求：

- `UI_TYPE` 的路径必须由真实包 ID、组件 ID 和 manifest 解析。
- 脚本默认创建在当前场景目录，文件名来源于 `FGUIView` 节点名。
- 不覆盖现有用户文件；冲突时生成唯一文件名。
- 写入成功并通过资源扫描后，使用 Undo/Redo 挂载到节点。
- 生成失败时不修改节点脚本。

## 5. P1-3：导入与绑定诊断

Inspector 诊断至少覆盖：

- `.fui` 数据是否可解析。
- 包 ID、包名和组件数量。
- 当前组件是否真实存在。
- 依赖 `.fui` 是否存在且可加载。
- 图集、音频、杂项和外部骨骼资源是否存在。
- 代码生成是否启用。
- manifest 是否存在、可解析且与当前 `content_hash` 一致。
- 当前组件是否有绑定记录，绑定脚本是否存在。

诊断分为错误、警告和正常状态。带资源路径的问题应允许点击并在文件系统中定位。

## 6. P1-4：运行时 FairyGUI 检查器

- 仅在通过 Godot 编辑器启动且 `EngineDebugger` 可用时启用运行时桥接。
- 调试器增加 `FairyGUI` 页签，展示所有运行中的 `FGUIView` 及其递归逻辑树。
- 节点显示名称、实际类型、位置和尺寸。
- 点击调试器节点后，运行中的游戏使用不可交互覆盖层高亮对应 FairyGUI 对象。
- 刷新由编辑器显式请求，不在每帧传输完整树。
- 发布构建不注册调试消息，也不创建覆盖层。

## 7. P1-5：预览状态恢复

状态按 `.fui` 路径和组件名分别保存：

- 当前选中对象的组件内索引路径。
- 层级树折叠状态。
- 搜索文本。
- 缩放比例。
- 水平和垂直滚动位置。

重新导入、重新加载和组件往返切换后恢复状态。对象路径失效时回退到组件根节点，不保留已经释放的对象引用。

## 8. 失败与兼容策略

- 所有编辑器文件写入必须先验证输入，失败时保留上一份可用文件。
- 生成文件和用户业务脚本严格分离。
- 编辑器增强不得改变运行时 FairyGUI 包格式。
- 不依赖 Godot 私有 C++ API；原生编辑器控件查找失败时只禁用拖放增强，其余功能继续工作。
- Godot 4.x API 存在差异时以能力检测为准；当前验收基线为 Godot 4.7。

## 9. 验证

每项功能必须同时具备：

- 独立的纯逻辑测试或 editor probe。
- Godot 编辑器启动和脚本解析验证。
- 至少一个非 `Basics` 包的动态组件/绑定验证，防止固定模板回归。

## 10. 实施映射

| 项目 | 主要实现 | 验证 |
| --- | --- | --- |
| P1-1 拖放创建 | `fui_canvas_drop_overlay.gd`、`plugin.gd`、GUI 预览树拖动数据 | `canvas_drop_editor_probe.gd` |
| P1-2 动态业务脚本 | `business_script_generator.gd`，通过真实 URL 查询 manifest 并预加载实际绑定脚本 | `editor_workflow_phase1_probe.gd` 和 `business_script_editor_probe.gd` 使用 `VirtualList.fui` 验证生成、挂载及无固定示例类型 |
| P1-3 导入诊断 | `package_diagnostics.gd`、`binding_inspector_plugin.gd` | `editor_workflow_phase1_probe.gd`、编辑器启动验证 |
| P1-4 运行时检查器 | `fairygui_debug_bridge.gd`、`fairygui_debugger_plugin.gd`、调试器面板和运行时选框 | `runtime_debugger_editor_probe.gd` 进行编辑器与游戏进程端到端消息验证 |
| P1-5 状态恢复 | `fui_preview_panel.gd` 的资源/组件状态快照 | `fui_preview_panel_probe.gd` |
