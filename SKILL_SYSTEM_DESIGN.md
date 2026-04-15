# 🎮 技能系统设计文档

**版本**: v1.0  
**日期**: 2026-04-02  
**状态**: ✅ 基础框架已完成

---

## 📋 系统概述

实现了完整的技能系统，包括：
- ✅ 3个技能槽位（Q/E/R键）
- ✅ 6种技能类型
- ✅ 冷却时间管理
- ✅ Buff/Debuff 效果系统
- ✅ 技能UI显示

---

## 🎯 键位配置

| 按键 | 功能 | 说明 |
|------|------|------|
| **Q** | 技能1 | 快速技能，短冷却（2-3秒） |
| **E** | 技能2 | 中等技能，中冷却（8-10秒） |
| **R** | 技能3 | 强力技能，长冷却（12-15秒） |
| WASD | 移动 | 不与技能冲突 |

---

## 🗂️ 文件结构

```
scripts/
├── systems/
│   ├── skill_db.gd          # 技能数据库（新增）
│   └── game_data.gd         # 添加技能状态管理
├── world/
│   └── player.gd            # 添加技能释放逻辑
└── ui/
    └── skill_hud.gd         # 技能UI显示（新增）
```

---

## 🔧 核心组件

### 1. SkillDB - 技能数据库

**位置**: `scripts/systems/skill_db.gd`

**功能**:
- 存储所有技能定义
- 提供技能查询接口
- 管理默认技能配置

**技能数据结构**:
```gdscript
{
    "id": "skill_q_001",
    "name": "利爪挥击",
    "type": SkillType.MELEE,
    "damage": 35,
    "range": 70,
    "radius": 0,
    "cooldown": 2.0,
    "cost": 0,
    "duration": 0,
    "effects": [],
    "description": "技能描述"
}
```

**已定义技能**:

#### Q键技能（快速）
- `skill_q_001`: 利爪挥击（近战单体）
- `skill_q_002`: 火焰吐息（远程AOE+燃烧）

#### E键技能（中等）
- `skill_e_001`: 钢铁护甲（自身防御buff）
- `skill_e_002`: 毒雾陷阱（范围debuff）

#### R键技能（强力）
- `skill_r_001`: 狂暴冲锋（位移+眩晕）
- `skill_r_002`: 生命汲取（吸血治疗）

---

### 2. GameData - 技能状态管理

**新增变量**:
```gdscript
var player_skills: Dictionary      # 技能槽位配置
var skill_cooldowns: Dictionary    # 冷却时间
var active_effects: Array          # 激活的buff/debuff
```

**核心函数**:

| 函数 | 功能 |
|------|------|
| `_init_skills()` | 初始化技能配置 |
| `get_skill_for_slot(slot)` | 获取槽位技能信息 |
| `can_use_skill(slot)` | 检查是否可用 |
| `use_skill(slot)` | 使用技能（设置冷却） |
| `update_skill_cooldowns(delta)` | 更新冷却时间 |
| `add_effect(name, duration, value)` | 添加buff/debuff |
| `update_effects(delta)` | 更新效果持续时间 |

---

### 3. Player - 技能释放逻辑

**新增输入处理**:
```gdscript
if event.is_action_pressed("skill_1"):  # Q键
    _use_skill("slot_q")
if event.is_action_pressed("skill_2"):  # E键
    _use_skill("slot_e")
if event.is_action_pressed("skill_3"):  # R键
    _use_skill("slot_r")
```

**技能执行函数**:

| 函数 | 技能类型 | 说明 |
|------|---------|------|
| `_execute_melee_skill()` | 近战 | 扇形范围伤害 |
| `_execute_ranged_skill()` | 远程 | AOE范围伤害 |
| `_execute_buff_skill()` | 增益 | 施加buff效果 |
| `_execute_debuff_skill()` | 减益 | 对敌人施加debuff |
| `_execute_heal_skill()` | 治疗 | 吸血恢复生命 |
| `_execute_special_skill()` | 特殊 | 位移、眩晕等 |

---

### 4. SkillHUD - 技能UI

**位置**: `scripts/ui/skill_hud.gd`

**功能**:
- 显示3个技能图标
- 显示技能名称
- 实时显示冷却时间
- 冷却遮罩效果

**UI结构**（需要在场景中创建）:
```
SkillHUD (CanvasLayer)
└─ SkillPanel (PanelContainer)
   └─ HBox (HBoxContainer)
      ├─ SkillQ (Control)
      │  ├─ CooldownMask (ColorRect)
      │  └─ CooldownLabel (Label)
      ├─ SkillE (Control)
      │  ├─ CooldownMask (ColorRect)
      │  └─ CooldownLabel (Label)
      └─ SkillR (Control)
         ├─ CooldownMask (ColorRect)
         └─ CooldownLabel (Label)
```

---

## 🎨 技能类型详解

### 1. MELEE - 近战攻击
- **特点**: 短距离、扇形范围
- **示例**: 利爪挥击
- **实现**: 检测前方±60度范围内的敌人

### 2. RANGED - 远程攻击
- **特点**: 长距离、AOE范围
- **示例**: 火焰吐息
- **实现**: 在目标位置生成AOE区域

### 3. BUFF - 增益效果
- **特点**: 提升自身属性
- **示例**: 钢铁护甲（+10防御）
- **实现**: 添加到 `active_effects` 数组

### 4. DEBUFF - 减益效果
- **特点**: 削弱敌人
- **示例**: 毒雾陷阱（中毒+减速）
- **实现**: 对范围内敌人施加效果

### 5. HEAL - 治疗
- **特点**: 恢复生命值
- **示例**: 生命汲取（吸血）
- **实现**: 造成伤害后按比例恢复

### 6. SPECIAL - 特殊效果
- **特点**: 位移、控制等
- **示例**: 狂暴冲锋（位移+眩晕）
- **实现**: 修改速度或施加控制效果

---

## 📊 当前实现的技能

### Q键技能

#### 利爪挥击 (skill_q_001)
- **类型**: 近战单体
- **伤害**: 35
- **范围**: 70像素
- **冷却**: 2.0秒
- **效果**: 对前方±60度敌人造成伤害

#### 火焰吐息 (skill_q_002)
- **类型**: 远程AOE
- **伤害**: 25
- **范围**: 200像素
- **半径**: 40像素
- **冷却**: 2.5秒
- **效果**: 点燃敌人（TODO: 持续伤害）

---

### E键技能

#### 钢铁护甲 (skill_e_001)
- **类型**: 自身Buff
- **冷却**: 8.0秒
- **持续**: 5.0秒
- **效果**: 防御力 +10

#### 毒雾陷阱 (skill_e_002)
- **类型**: 范围Debuff
- **伤害**: 10
- **范围**: 150像素
- **半径**: 60像素
- **冷却**: 10.0秒
- **持续**: 4.0秒
- **效果**: 中毒 + 减速

---

### R键技能

#### 狂暴冲锋 (skill_r_001)
- **类型**: 位移+控制
- **伤害**: 50
- **距离**: 150像素
- **冷却**: 15.0秒
- **效果**: 向前冲锋，眩晕附近敌人

#### 生命汲取 (skill_r_002)
- **类型**: 吸血治疗
- **伤害**: 40
- **范围**: 100像素
- **半径**: 80像素
- **冷却**: 12.0秒
- **效果**: 吸取50%伤害转化为生命

---

## 🔍 测试方法

### 1. 启动游戏
```bash
# 在 Godot 编辑器中按 F5 运行
```

### 2. 测试技能释放
- 进入战斗场景
- 按 **Q** 键：释放利爪挥击
- 按 **E** 键：释放钢铁护甲
- 按 **R** 键：释放狂暴冲锋

### 3. 观察控制台输出
应该看到类似：
```
✨ 释放技能: 利爪挥击 (slot_q)
  → 命中: Enemy_1 (35伤害)
  → 命中: Enemy_2 (35伤害)
```

### 4. 检查冷却
- 释放技能后，再次按下应显示 "⚠️ 技能冷却中或无效"
- 等待冷却完成后可以再次释放

---

## 🚀 后续扩展

### P0 - 必须实现
1. **技能图标资源** - 为每个技能设计图标
2. **视觉效果** - 粒子特效、动画
3. **音效** - 技能释放音效
4. **Enemy 效果系统** - 实现中毒、减速、眩晕

### P1 - 重要功能
1. **技能升级** - 提升技能等级增强效果
2. **技能切换** - 允许玩家更换技能
3. **能量系统** - 添加法力值/能量消耗
4. **连招系统** - 技能组合触发额外效果

### P2 - 优化体验
1. **技能提示** - 鼠标悬停显示技能详情
2. **快捷键自定义** - 允许修改键位
3. **技能特效定制** - 宠物合体后的技能变化
4. **成就系统** - 技能使用统计

---

## 📝 注意事项

### ⚠️ 已知限制

1. **视觉效果缺失**
   - 技能释放没有粒子特效
   - 需要添加视觉反馈

2. **Buff 未实际生效**
   - `defense_up` 只是记录，未在伤害计算中使用
   - 需要在 `GameData.take_damage()` 中检查效果

3. **Debuff 未实现**
   - Enemy 没有效果系统
   - 需要在 `enemy.gd` 中添加

4. **冲锋不够平滑**
   - 当前是直接设置 velocity
   - 建议使用 Tween 实现平滑位移

### 💡 改进建议

1. **添加技能特效节点**
   ```gdscript
   # 在 player.gd 中
   func _create_skill_effect(skill: Dictionary, position: Vector2):
       var effect = preload("res://scenes/effects/skill_effect.tscn").instantiate()
       effect.position = position
       get_tree().current_scene.add_child(effect)
   ```

2. **实现 Buff 实际效果**
   ```gdscript
   # 在 GameData.take_damage() 中
   func take_damage(amount: int) -> void:
       var defense = player_defense
       if has_effect("defense_up"):
           defense += 10  # 或其他值
       var actual = max(1, amount - defense)
       # ...
   ```

3. **Enemy 效果系统**
   ```gdscript
   # 在 enemy.gd 中添加
   var active_effects: Array = []
   
   func apply_debuff(effect_name: String, duration: float):
       active_effects.append({
           "name": effect_name,
           "duration": duration,
           "time_remaining": duration
       })
   ```

---

## 🎯 总结

✅ **已完成**:
- 技能数据库和管理系统
- 3个技能槽位（Q/E/R）
- 6种技能类型框架
- 冷却时间管理
- Buff/Debuff 基础系统
- 技能UI脚本

⏳ **待完成**:
- 技能图标和视觉效果
- Buff/Debuff 实际生效
- Enemy 效果系统
- 音效和粒子特效

**下一步**: 测试当前功能，然后添加视觉效果和音效！
