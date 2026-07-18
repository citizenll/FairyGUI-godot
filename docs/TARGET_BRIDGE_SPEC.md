# FairyGUI Godot 节点暴露桥接规范

状态：层级附件阶段已实现

目标版本：0.6.0

适用范围：Godot 4.x，主要在 Godot 4.7 上验证

## 1. 目标

允许开发者在不展开、复制或接管 FairyGUI 运行时节点树的前提下，把指定 FUI 对象暴露为场景中的普通 Godot 节点，并完成以下工作：

- 在 Inspector 中为 FUI 图片、文本、Loader 等显示对象配置 `Material` / `ShaderMaterial`。
- 在暴露节点下添加 Godot `Control`、粒子、动画和其他场景节点，并在编辑器中跟随 FUI 目标预览。
- FUI 包重新导入、组件重建或场景运行后，自动重新定位目标并恢复覆盖。
- 保持现有 Controller、Gear、Relation、Transition、ScrollPane、虚拟列表、事件绑定和强类型代码生成行为不变。

## 2. 非目标

- 不把 FUI 运行时生成的 `Control` 保存进 `.tscn`。
- 不把 FUI 转换为 Godot 原生 UI 并替代 FairyGUI 运行时。
- 不允许编辑暴露节点的位置和尺寸后反向写入 `.fui`。
- 不改变 Godot 附件节点在场景树中的父节点、owner 或稳定 NodePath。
- 不把附件节点复制、实例化第二份或写入 FairyGUI 的逻辑 children 数组。
- 不为虚拟列表单元、Tree 动态节点等回收对象建立持久目标引用。

## 3. 核心原则

1. `.fui` 始终是布局、层级和 FairyGUI 行为的唯一数据源。
2. `FGUITarget` 是引用和覆盖节点，不是 FUI 渲染节点的副本。
3. 目标引用使用 FUI package/component ID 和 child ID 链；名称仅作为唯一匹配时的迁移回退。
4. 暴露节点只读取目标变换、尺寸和可见性，不修改 FUI 布局属性。
5. 材质覆盖只修改目标明确公开的 material target，并在解绑时恢复原材质。
6. FUI 预览重建前先解除覆盖，重建后重新解析；不得持有已释放的 `FGUIObject` 或 native node。
7. 找不到目标时必须保持场景可运行并显示诊断，不得绑定到不确定的同名节点。
8. 用户添加的 Godot 子节点始终由 `.tscn` 持有，不得在编辑器预览刷新时删除或重建。
9. 暴露功能必须是显式操作；导入 `.fui`、创建 `FGUIView` 和运行现有项目时不自动创建代理节点。
10. 默认只改变 `FGUITarget` 的 CanvasItem 渲染父级，不改变 Godot 场景树父子关系。

## 4. 数据模型

### 4.1 FGUIObjectRef

`FGUIObjectRef` 是 `resource_local_to_scene` 的 Resource，保存：

```text
package_id
package_name
component_id
component_name
child_ids[]
child_names[]
```

解析规则：

1. 校验根组件 package/component 身份。
2. 每一级优先使用 child ID 查找。
3. ID 失效时，只有同级恰好存在一个同名对象才允许名称回退。
4. 任一级无法唯一解析时返回 `null`。

根组件使用空 child path。引用 key 必须只由 package/component ID 和 child ID 链组成，用于去重。

### 4.2 FGUITarget

`FGUITarget` 是普通、可保存到 `.tscn` 的 `Control`：

```text
target_ref: FGUIObjectRef
material_override: Material
attachment_mode: FUI_HIERARCHY | OVERLAY
attachment_behind_target: bool
enabled: bool
sync_transform: bool
sync_size: bool
sync_visibility: bool
hide_when_missing: bool
clip_attachments: bool
```

运行时状态不序列化：

```text
resolved_object: FGUIObject
material_target: CanvasItem
previous_material: Material
owning_view: FGUIView
render_parent_target: CanvasItem
```

`FGUITarget` 必须位于 `FGUIView` 的后代层级。它通过祖先查找所属 View，并监听 `fairy_ready` / `fairy_cleared`。

`enabled == false` 时代理隐藏、材质覆盖解除，但引用和场景附件保持不变；重新启用后按当前 FUI 实例重新应用。

## 5. 材质覆盖

`FGUIObject` 提供：

```gdscript
func get_material_target() -> CanvasItem
```

默认返回 `node`。具有容器外壳的类型必须覆盖该方法并返回实际绘制节点，例如 Loader 返回其 TextureRect、MovieClip/Image 返回 NinePatchRect、TextInput 返回原生输入控件。

应用规则：

1. 记录覆盖前材质。
2. 设置 `material_override`。
3. 目标、View、引用或材质发生变化时重新应用。
4. 解绑时仅当目标仍持有本节点应用的材质时恢复，避免覆盖其他系统之后的修改。
5. `material_override == null` 表示不接管材质。

第一阶段材质作用于单个绘制对象。整个组件的后处理应作为后续独立的 `CanvasGroup` 模式实现，不伪装成当前能力。

## 6. Godot 附件节点

用户可以把普通 Godot 节点添加为 `FGUITarget` 子节点：

```text
InventoryView (FGUIView)
└── PortraitTarget (FGUITarget)
    ├── GlowParticles
    └── AnimationPlayer
```

`FGUITarget` 在编辑器和运行时同步目标的全局变换、尺寸和可见性。附件始终保留在代理节点下，场景 owner、信号连接、脚本状态及 `$PortraitTarget/GlowParticles` 等 NodePath 不发生变化。

默认 `attachment_mode == FUI_HIERARCHY`。运行时通过 `RenderingServer.canvas_item_set_parent` 把 `FGUITarget` 的 CanvasItem 渲染父级桥接到目标 FUI native CanvasItem，并使用局部恒等变换抵消重复变换。因此附件在渲染上等价于目标 FUI 对象的普通子节点，会继承目标及其祖先的绘制顺序、可见性、ScrollPane 裁剪和 CanvasItem 遮罩。

该桥接只作用于 RenderingServer，不调用 `Node.reparent`，不修改 FairyGUI display list，也不影响场景保存。FUI 重建前恢复场景渲染父级，重建后绑定到新的 native CanvasItem。

`attachment_mode == OVERLAY` 保留旧行为：附件绘制在完整 FUI 视图上方。`attachment_behind_target == true` 仅在层级模式下生效，使附件作为目标的 behind-parent 内容绘制。

## 7. 编辑器工作流

1. 从 `FGUIView` Inspector 或文件系统打开 GUI 预览。直接打开 `.fui` 时优先关联场景树当前选中的匹配 View；否则只允许自动关联当前场景中唯一匹配的 View。
2. 在左侧层级或右侧画布选择 FUI 对象。
3. 点击“暴露节点”。
4. 插件通过 Undo/Redo 在当前 `FGUIView` 下创建 `FGUITarget`，写入稳定引用并选中它。
5. 如果相同引用已经暴露，选中已有节点，不重复创建。
6. 在 `FGUITarget` Inspector 中配置材质或添加 Godot 子节点。
7. “在 GUI 预览中定位”必须重新打开对应组件并选中引用目标。

没有唯一 `FGUIView` 上下文、组件不一致、目标属于动态列表内容或无法建立稳定引用时，“暴露节点”必须禁用并说明原因。多个 View 使用同一包和组件时不得猜测，必须由场景树选中项确定目标。

## 8. 生命周期

```text
FGUIView clear
  -> fairy_cleared
  -> FGUITarget 恢复 CanvasItem 场景渲染父级
  -> FGUITarget 恢复材质并清除弱引用
  -> FGUIObject dispose

FGUIView rebuild
  -> fairy_ready(new_root)
  -> FGUIObjectRef.resolve(new_root)
  -> FGUITarget 同步、应用材质并桥接新渲染父级
```

`FGUITarget` 离开场景树、被重新挂载、目标引用改变或所属 View 改变时执行同样的解除/重绑定流程。

## 9. 兼容性边界

- 现有没有 `FGUITarget` 的场景不得产生额外节点、处理循环或材质修改。
- `FGUIView.fairy`、生成绑定类和事件绑定接口保持不变。
- FUI native 节点名称和父子关系保持由 FairyGUI 管理。
- 暴露节点不得加入 FGUIComponent.children，也不得参与 FairyGUI display list 排序。
- 默认层级模式不得改变 `FGUITarget` 及附件的 Godot Node 父子关系；覆盖层模式必须可随时切换并恢复旧行为。

## 10. 验收标准

1. 暴露图片后可在 Inspector 拖入 `ShaderMaterial`，编辑器预览和运行时均生效。
2. FUI 预览刷新后代理仍解析到新对象，材质重新生效。
3. 清除或更换目标后原对象材质恢复。
4. `FGUITarget` 子节点默认继承目标 FUI 对象的渲染层级、祖先裁剪和可见性，同时 NodePath 保持不变。
5. ID 失效但名称唯一时可以迁移；名称重复时不得误绑定。
6. 无效目标只报告诊断，不阻止 `FGUIView` 创建和运行。
7. 重复暴露同一对象不会创建第二个代理。
8. 删除 `FGUITarget` 后 FairyGUI 节点树、事件、Controller 和 Transition 行为不变。
9. Godot 4.7 下通过运行时桥接、编辑器预览、场景 Undo/Redo、现有 smoke 和代码生成回归测试。
10. 切换 Overlay 后恢复旧的全局覆盖绘制，重新切回层级模式后无需重建附件节点。
