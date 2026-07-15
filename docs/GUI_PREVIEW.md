# FairyGUI Godot GUI 预览面板

状态：已实施  
适用版本：Godot 4.x，主要在 Godot 4.7 上验证

## 1. 入口

以下操作会打开编辑器底部的“GUI预览”面板：

- 在 Godot 文件系统中双击导入后的 `.fui`。
- 在 `FGUIPackageResource` Inspector 中点击 `Open Preview`。
- 在配置了 package 的 `FGUIView` Inspector 中点击 `Open Preview`。

重新导入当前 `.fui` 后，已打开的面板会自动重新加载。

## 2. 面板结构

顶部工具栏提供：

- 当前 `.fui` 资源路径。
- 包内组件选择器，默认优先选择 `Main`。
- 重新加载。
- 缩小、放大和适应窗口。

左侧层级树提供：

- 递归展示 `FGUIComponent.children` 中的全部对象。
- 单独显示节点名称和实际 FairyGUI 类型。
- 展示嵌套组件、按钮内部结构和未命名对象。
- 按节点名称或类型即时筛选。
- Tooltip 展示对象 ID、坐标和尺寸。

右侧区域使用与 `FGUIView` 相同的 `.fui` 构建和渲染链路，不创建另一套预览实现。

## 3. 双向选择

左侧选择节点时：

1. 保存对应 `FGUIObject`。
2. 展开并滚动到 TreeItem。
3. 将预览滚动到对象中心。
4. 按对象的实际 Godot `Transform2D` 绘制选框和四角控制点。

右侧点击预览时：

1. 使用根组件的 `hit_test(global_position, true)` 获取最深层对象。
2. 根据 `FGUIObject` 实例 ID 找到对应 TreeItem。
3. 展开、滚动并选中左侧节点。
4. 更新底部状态栏中的名称、类型、位置和尺寸。

选择层只负责检查和定位，不会把输入继续传给预览 UI，也不会修改 `.fui` 数据。

## 4. 解析范围

层级树展示当前组件实际构建出的 FairyGUI 显示对象，包括所有递归子组件。Controller、Transition、Gear 和 Relation 不属于显示对象树，因此不作为独立树节点展示；它们仍由运行时完整解析并影响预览结果。

虚拟列表只展示当前实际构建出的物理 Item，不会为尚未实例化的逻辑 Item 创建伪节点。滚动条、下拉刷新 Header/Footer 等运行时辅助对象不属于 `FGUIComponent.children` 时，也不会混入设计层级树。

## 5. 编辑器安全

- 预览面板只运行 FairyGUI 包解析和渲染，不执行自动生成的业务绑定脚本。
- 切换组件、重新导入、关闭插件时会释放预览对象和 package 引用。
- 面板是只读工具，不写回 `.fui`，不改变生成代码。
- 对象映射使用运行时实例 ID；每次重新构建组件都会重新生成完整映射，避免保留失效引用。
