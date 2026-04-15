# 需求 #54: 格子系统重构计划

## 一、三角洲行动（Delta Force）物资系统功能总结

### 核心机制（我们要实现的简化版）

| 功能 | 描述 | 优先级 |
|------|------|--------|
| **逐个搜索** | 打开箱子后，每个物品需单独搜索（按稀有度耗时不同） | P0 |
| **搜索持久化** | 已搜过的物品再次打开不重新搜索，直接显示 | P0 |
| **物品位置固定** | 生成时确定位置，再次打开顺序/位置不变 | P0 |
| **未搜索占位** | 未搜索物品显示 "?" 问号 | P0 |
| **拖拽拾取** | 从物资箱拖物品到背包（自动找空位） | P0 |
| **拖拽放回** | 从背包拖物品回物资箱（精确放置） | P0 |
| **背包内移动** | 在背包内拖动物品换位置 | P0 |
| **双击快拾** | 双击物资箱物品自动入包 | P0 |
| **拖拽预览** | 绿色高亮=可放，红色=不可放 | P0 |
| **幽灵跟随** | 拖拽时物品跟鼠标移动 | P0 |
| **右键取消** | 拖拽中右键取消操作 | P0 |
| ~~拖拽丢出~~ | 从背包/箱子拖出丢弃到地面 | **不做** |

## 二、现有代码 Bug 分析

### Bug #1: 物品重复搜索（需求要求修复）
**现状**: `loot_ui.gd` 的搜索系统实际上已经正确实现了持久化（通过 `searched` 字段），但需验证

### Bug #2: 再次打开物资箱排列顺序改变（需求要求修复）
**现状**: `loot_ui.gd._refresh_loot()` 按数组原始顺序绘制，理论上不变。但 `_move_to_loot` 是 append 到末尾，会改变顺序

### Bug #3: 背包内拖拽移动（需求要求修复）
**现状**: `loot_ui.gd._move_item_in_bag` 存在但逻辑复杂，依赖 `set_drag_source` 机制，容易出 bug

### 🔴 严重问题：大量死代码和不存在的方法调用

| 问题 | 位置 | 详情 |
|------|------|------|
| `get_shape_cells()` 不存在 | grid_container_ui.gd 多处调用 | GameData 没有此方法！ |
| `get_shape_cells()` 不存在 | loot_ui.gd 间接引用 | 通过 GridContainerUI |
| `shape_key` 字段无意义 | loot_box.gd 生成时写入 | ItemDB 物品定义里没有 shape 字段 |
| `rotated` 字段无意义 | 全局到处都是 | 单格系统不需要旋转 |
| `grid_container_ui.gd` 整个文件 | 481行多格系统 | 完全未被使用（LootUI 自己实现了） |
| `grid_panel.gd` 整个文件 | 140行 | 基本未被使用 |
| `GameData.place_item` 过度复杂 | game_data.gd | drag_source 匹配逻辑脆弱难维护 |

## 三、重构方案

### 设计原则
1. **纯单格**：删掉所有 shape_key / rotated / multi-cell / get_shape_cells
2. **数据格式统一**：所有物品用 `{instance_id, item_id, amount, row, col}` (+ searched 仅物资箱)
3. **单一职责**：GameData 只管数据，UI 只管显示+交互
4. **最小改动**：不动场景文件(.tscn)，只改脚本(.gd)

### 文件变更清单

#### 1. game_data.gd → 精简重构
```
删除:
  - _drag_source_* 变量（3个）
  - set_drag_source() / clear_drag_source()
  - place_item() 里的 drag_source 匹配分支（约30行）

新增/修改:
  - move_item(instance_id, new_row, new_col): 专用于背包内移动
  - place_item() 简化为: 检查空格→放进去
  - can_place_item() 简化为: 目标格==空 或 目标格==自身instance_id
```

#### 2. loot_ui.gd → 重写（保留场景结构）
```
删除:
  - 所有 shape_key / rotated 引用
  - set_drag_source / clear_drag_source 调用
  - 复杂的 _move_item_in_bag 逻辑

重写:
  - _end_drag(): 统一4种情况(bag→bag, loot→bag, bag→loot, 取消)
  - 拖拽预览: 单格版（不需要计算形状）
  - _make_item_slot(): 简化，去掉 shape 参数
```

#### 3. warehouse_ui.gd → 小改
```
删除:
  - 无重大修改（已经是较干净的单格系统）
```

#### 4. loot_box.gd → 数据格式修复
```
修改:
  - 删除 shape_key 字段
  - 统一为 {instance_id, item_id, rarity, row, col, searched}
  - 分配固定 row,col（像 LootSpot 一样）
```

#### 5. 归档废弃文件
```
grid_container_ui.gd → _archive/grid_container_ui.gd.old
grid_panel.gd → _archive/grid_panel.gd.old
(这些是多格系统的遗留物，不再需要)
```

#### 6. item_db.gd → 不变
```
已经干净的单格系统，无需修改
```

## 四、测试计划
1. 启动游戏 → 主菜单 → 行前准备 → 出发 → 史前世界
2. 找到物资箱 → 打开 → 观察搜索过程
3. 双击拾取一个物品
4. 背包内拖拽移动
5. 关闭物资箱 → 重开 → 验证不重复搜索 + 顺序不变
