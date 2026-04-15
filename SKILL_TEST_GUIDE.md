# 🧪 技能系统快速测试指南

## 📋 前置条件

1. ✅ Godot 4.6.1 已安装
2. ✅ 项目已打开
3. ✅ 所有脚本已保存

---

## 🎮 测试步骤

### 第一步：在 Godot 编辑器中创建 SkillHUD 场景

由于技能 UI 需要在场景中配置，请按以下步骤操作：

#### 方法 A：手动创建（推荐）

1. **打开 `game_world.tscn` 场景**
   - 在文件系统面板找到 `scenes/world/game_world.tscn`
   - 双击打开

2. **添加 SkillHUD 节点**
   ```
   GameWorld (Node2D)
   ├─ Player
   ├─ LootUI (CanvasLayer)
   ├─ HUD (CanvasLayer)
   └─ 【新增】SkillHUD (CanvasLayer) ← 在这里添加
      └─ SkillPanel (PanelContainer)
         └─ HBox (HBoxContainer)
            ├─ SkillQ (Control)
            │  ├─ Background (ColorRect) - 背景色: #333333
            │  ├─ SkillName (Label) - 文本: "Q"
            │  ├─ CooldownMask (ColorRect) - 颜色: 黑色半透明, 默认隐藏
            │  └─ CooldownLabel (Label) - 字体大小: 16, 颜色: 白色, 居中, 默认隐藏
            ├─ SkillE (Control) - 同上
            └─ SkillR (Control) - 同上
   ```

3. **设置节点属性**
   - **SkillQ/E/R**: 
     - Size: 60x60
     - Mouse Filter: Ignore
   
   - **Background**:
     - Size: 60x60
     - Color: #333333
   
   - **SkillName**:
     - Text: "Q" / "E" / "R"
     - Horizontal Alignment: Center
     - Vertical Alignment: Center
     - Font Size: 20
   
   - **CooldownMask**:
     - Size: 60x60
     - Color: #00000080 (黑色半透明)
     - Visible: ❌ (取消勾选)
   
   - **CooldownLabel**:
     - Font Size: 16
     - Horizontal Alignment: Center
     - Vertical Alignment: Center
     - Visible: ❌ (取消勾选)

4. **保存场景**

---

### 第二步：运行游戏测试

1. **启动游戏** (F5)
2. **进入战斗** 
   - 主菜单 → 新游戏 → 行前准备 → 出发
3. **找到敌人**
4. **测试技能**:
   - 按 **Q** 键 → 应该看到控制台输出技能信息
   - 按 **E** 键 → 应该看到防御提升提示
   - 按 **R** 键 → 应该看到冲锋效果

---

## 🔍 预期结果

### ✅ 成功标志

1. **控制台输出**:
   ```
   ✨ 释放技能: 利爪挥击 (slot_q)
     → 命中: Enemy_1 (35伤害)
   ```

2. **冷却提示**:
   - 再次按下同一技能键
   - 显示: "⚠️ 技能冷却中或无效"

3. **Buff 提示**:
   ```
   ✨ 释放技能: 钢铁护甲 (slot_e)
     → 防御力提升 +10，持续5.0秒
   ```

4. **治疗提示**:
   ```
   ✨ 释放技能: 生命汲取 (slot_r)
     → 生命汲取: 恢复 20 HP
   ```

---

## 🐛 常见问题

### Q1: 按技能键没有反应？

**检查**:
1. 确认输入映射已添加（查看 `project.godot`）
2. 确认玩家角色存活
3. 查看控制台是否有错误

**解决**:
```gdscript
# 在 player.gd 的 _input 函数中添加调试
print("按键检测: skill_1 pressed")
```

---

### Q2: SkillHUD 节点找不到？

**错误信息**:
```
Error: Node not found: SkillHUD
```

**解决**:
- 确保在 `game_world.tscn` 中添加了 SkillHUD 节点
- 或者临时注释掉 game_world.gd 中的 `@onready var skill_hud` 行

---

### Q3: 技能释放了但没有伤害？

**检查**:
1. 确认敌人距离足够近
2. 确认敌人在前方扇形范围内
3. 查看控制台是否有 "命中" 信息

**调试**:
```gdscript
# 在 _execute_melee_skill 中添加
print("检测到 %d 个敌人" % targets.size())
print("距离: %f, 角度: %f" % [dist, dot])
```

---

## 📊 技能数据验证

### Q键 - 利爪挥击
- [ ] 伤害: 35
- [ ] 范围: 70像素
- [ ] 冷却: 2.0秒
- [ ] 角度: ±60度

### E键 - 钢铁护甲
- [ ] 冷却: 8.0秒
- [ ] 持续: 5.0秒
- [ ] 效果: 防御+10

### R键 - 狂暴冲锋
- [ ] 伤害: 50
- [ ] 距离: 150像素
- [ ] 冷却: 15.0秒
- [ ] 眩晕: 附近敌人

---

## 🎯 进阶测试

### 测试冷却系统
1. 释放 Q 技能
2. 立即再次按 Q → 应该被阻止
3. 等待 2 秒
4. 再次按 Q → 应该可以释放

### 测试 Buff 系统
1. 按 E 释放钢铁护甲
2. 让敌人攻击你
3. 观察伤害是否降低（需要实现 buff 实际效果）

### 测试多目标
1. 站在多个敌人中间
2. 释放 AOE 技能（如火焰吐息）
3. 确认所有范围内的敌人都受到伤害

---

## 📝 测试记录模板

```
测试日期: ___________
测试人员: ___________

技能测试结果:
□ Q键技能正常
□ E键技能正常
□ R键技能正常
□ 冷却系统正常
□ Buff/Debuff 提示正常

发现的问题:
1. 
2. 
3. 

控制台错误:
```

---

## 🚀 下一步

测试通过后，可以：
1. 添加技能图标图片
2. 添加粒子特效
3. 添加音效
4. 实现 Buff 实际效果
5. 实现 Enemy Debuff 系统

祝测试顺利！🎮✨
