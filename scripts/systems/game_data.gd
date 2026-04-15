## GameData - 游戏状态管理（重构版 v3: 纯单格系统）
## 清理了所有多格系统死代码（shape_key/rotated/drag_source等）
extends Node

# ── 信号 ──────────────────────────────────────────────────
signal health_changed(current: int, max_val: int)
signal pet_fused(pet_id: int)
signal pet_unfused
signal inventory_changed
signal warehouse_changed

# ── 玩家属性 ──────────────────────────────────────────────
var player_health: int = 100
var player_max_health: int = 100
var player_attack: int = 15
var player_defense: int = 5

# ── 宠物 ──────────────────────────────────────────────────
var equipped_pet_id: int = 0
var fused_pet_id: int = 0
var collected_pets: Array = []

# ── 技能系统 ──────────────────────────────────────────────
var player_skills: Dictionary = {}  # {"slot_q": "skill_id", "slot_e": "skill_id", "slot_r": "skill_id"}
var skill_cooldowns: Dictionary = {}  # {"slot_q": 0.0, "slot_e": 0.0, "slot_r": 0.0}
var active_effects: Array = []  # 当前激活的buff/debuff效果

# ── 背包（纯单格系统，10列×6行）──────────────────────────
const GRID_COLS: int = 10
const GRID_ROWS: int = 6
var grid: Array = []          # grid[row][col] = instance_id or 0
var placed_items: Array = []  # [{instance_id, item_id, amount, row, col}]

# ── 仓库 ──────────────────────────────────────────────────
var warehouse: Array = []  # [{item_id, amount, row, col}]

# ── 游戏状态 ──────────────────────────────────────────────
var is_in_game: bool = false
var current_map: String = ""
var last_save_slot: int = -1
var play_time: float = 0.0

func _ready() -> void:
	_init_grid()
	_init_skills()

func _process(delta: float) -> void:
	if is_in_game:
		play_time += delta

# ════════════════════════════════════════════════
#  网格初始化
# ════════════════════════════════════════════════
func _init_grid() -> void:
	grid = []
	for r in range(GRID_ROWS):
		var row = []
		for c in range(GRID_COLS):
			row.append(0)
		grid.append(row)
	placed_items.clear()

func rebuild_grid() -> void:
	"""从 placed_items 重建 grid（用于加载存档后恢复）"""
	_init_grid()
	for item in placed_items:
		var r = item.get("row", 0)
		var c = item.get("col", 0)
		var inst_id = item.get("instance_id", 0)
		if r >= 0 and r < GRID_ROWS and c >= 0 and c < GRID_COLS:
			grid[r][c] = inst_id

# ════════════════════════════════════════════════
#  背包操作（v3: 极简化纯单格）
# ════════════════════════════════════════════════

## 判断某位置是否可放置物品
## 单格系统只需要检查：目标格是否为空（或就是自己）
## exclude_instance_id 用于背包内移动时排除自身
func can_place_item(row: int, col: int, exclude_instance_id: int = -1) -> bool:
	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		return false
	
	var occupant = grid[row][col]
	
	if occupant == 0:
		return true  # 空格
	
	# 是自己的原位置 → 允许放回
	if occupant == exclude_instance_id:
		return true
	
	return false  # 被其他物品占用

## 贪心算法找空位（从左上到右下扫描）
func find_placement(exclude_instance_id: int = -1) -> Dictionary:
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if can_place_item(r, c, exclude_instance_id):
				return {"row": r, "col": c, "found": true}
	return {"found": false}

## 放置新物品到指定位置（生成新 instance_id）
func place_item(item_id: int, amount: int, row: int, col: int) -> bool:
	if not can_place_item(row, col):
		return false
	
	var target_instance_id = _generate_instance_id()
	grid[row][col] = target_instance_id
	placed_items.append({
		"instance_id": target_instance_id,
		"item_id": item_id,
		"amount": amount,
		"row": row,
		"col": col,
	})
	inventory_changed.emit()
	return true

## 移动已有物品到新位置（背包内拖拽用）
## exclude_instance_id 让 can_place 排除自身原位
func move_item(instance_id: int, new_row: int, new_col: int) -> bool:
	# 先找到物品当前位置
	var old_row = -1
	var old_col = -1
	for item in placed_items:
		if item["instance_id"] == instance_id:
			old_row = item["row"]
			old_col = item["col"]
			break
	
	if old_row < 0:
		print("[GameData] move_item: instance_id %d not found!" % instance_id)
		return false
	
	# 检查新位置是否可用（排除自身）
	if not can_place_item(new_row, new_col, instance_id):
		return false
	
	# 清除旧位置
	grid[old_row][old_col] = 0
	# 标记新位置
	grid[new_row][new_col] = instance_id
	# 更新数据
	for item in placed_items:
		if item["instance_id"] == instance_id:
			item["row"] = new_row
			item["col"] = new_col
			break
	
	inventory_changed.emit()
	return true

## 自动找空位添加物品（外部快捷入口）
func add_item_to_inventory(item_id: int, amount: int) -> bool:
	var placement = find_placement()
	if not placement["found"]:
		return false
	return place_item(item_id, amount, placement["row"], placement["col"])

## 按 instance_id 移除物品
func remove_item_from_inventory(instance_id: int) -> bool:
	var idx = -1
	for i in range(placed_items.size()):
		if placed_items[i]["instance_id"] == instance_id:
			idx = i
			break
	if idx == -1:
		return false
	
	var item = placed_items[idx]
	grid[item["row"]][item["col"]] = 0
	placed_items.remove_at(idx)
	inventory_changed.emit()
	return true

func get_inventory_item_count() -> int:
	return placed_items.size()

func clear_inventory() -> void:
	_init_grid()
	inventory_changed.emit()

# ════════════════════════════════════════════════
#  仓库操作
# ════════════════════════════════════════════════
func add_to_warehouse(item_id: int, amount: int) -> void:
	warehouse.append({"item_id": item_id, "amount": amount, "row": -1, "col": -1})
	warehouse_changed.emit()

func get_warehouse_item_count() -> int:
	return warehouse.size()

# ════════════════════════════════════════════════
#  宠物系统
# ════════════════════════════════════════════════
func collect_pet(pet_id: int) -> void:
	if pet_id not in collected_pets:
		collected_pets.append(pet_id)

func has_pet(pet_id: int) -> bool:
	return pet_id in collected_pets

func fuse_pet(pet_id: int) -> void:
	if has_pet(pet_id):
		fused_pet_id = pet_id
		pet_fused.emit(pet_id)

func unfuse_pet() -> void:
	fused_pet_id = 0
	pet_unfused.emit()

# ════════════════════════════════════════════════
#  玩家属性
# ════════════════════════════════════════════════
func take_damage(amount: int) -> void:
	var actual = max(1, amount - player_defense)
	player_health = max(0, player_health - actual)
	health_changed.emit(player_health, player_max_health)

func heal(amount: int) -> void:
	player_health = min(player_max_health, player_health + amount)
	health_changed.emit(player_health, player_max_health)

func is_alive() -> bool:
	return player_health > 0

# ════════════════════════════════════════════════
#  存档系统
# ════════════════════════════════════════════════
func save_game(slot: int = 0) -> void:
	var data = {
		"player_health": player_health,
		"player_max_health": player_max_health,
		"player_attack": player_attack,
		"player_defense": player_defense,
		"equipped_pet_id": equipped_pet_id,
		"fused_pet_id": fused_pet_id,
		"collected_pets": collected_pets,
		"placed_items": placed_items,
		"warehouse": warehouse,
		"current_map": current_map,
		"play_time": play_time,
	}
	SaveSystem.save_to_slot(slot, data)
	last_save_slot = slot

func load_game(slot: int = 0) -> bool:
	var data = SaveSystem.load_from_slot(slot)
	if data.is_empty():
		return false
	
	player_health = data.get("player_health", 100)
	player_max_health = data.get("player_max_health", 100)
	player_attack = data.get("player_attack", 15)
	player_defense = data.get("player_defense", 5)
	equipped_pet_id = data.get("equipped_pet_id", 0)
	fused_pet_id = data.get("fused_pet_id", 0)
	collected_pets = data.get("collected_pets", [])
	placed_items = data.get("placed_items", [])
	warehouse = data.get("warehouse", [])
	current_map = data.get("current_map", "")
	play_time = data.get("play_time", 0.0)
	
	rebuild_grid()
	last_save_slot = slot
	return true

func transfer_inventory_to_warehouse() -> void:
	"""撤离成功后，将背包装入仓库"""
	for item in placed_items:
		add_to_warehouse(item["item_id"], item.get("amount", 1))
	clear_inventory()

func _generate_instance_id() -> int:
	var max_id = 0
	for item in placed_items:
		max_id = max(max_id, item.get("instance_id", 0))
	return max_id + 1

# ── 存档数据接口（供 SaveSystem 调用）─────────────────────
func get_save_data() -> Dictionary:
	return {
		"player_health": player_health,
		"player_max_health": player_max_health,
		"player_attack": player_attack,
		"player_defense": player_defense,
		"equipped_pet_id": equipped_pet_id,
		"fused_pet_id": fused_pet_id,
		"collected_pets": collected_pets,
		"placed_items": placed_items,
		"warehouse": warehouse,
		"current_map": current_map,
		"play_time": play_time,
	}

func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	player_health = data.get("player_health", 100)
	player_max_health = data.get("player_max_health", 100)
	player_attack = data.get("player_attack", 15)
	player_defense = data.get("player_defense", 5)
	equipped_pet_id = data.get("equipped_pet_id", 0)
	fused_pet_id = data.get("fused_pet_id", 0)
	collected_pets = data.get("collected_pets", [])
	placed_items = data.get("placed_items", [])
	warehouse = data.get("warehouse", [])
	current_map = data.get("current_map", "")
	play_time = data.get("play_time", 0.0)
	
	rebuild_grid()
	inventory_changed.emit()
	health_changed.emit(player_health, player_max_health)

# ════════════════════════════════════════════════
#  技能系统管理
# ════════════════════════════════════════════════

func _init_skills() -> void:
	"""初始化技能配置"""
	if player_skills.is_empty():
		player_skills = SkillDB.get_default_skills()
		skill_cooldowns = {
			"slot_q": 0.0,
			"slot_e": 0.0,
			"slot_r": 0.0
		}

func get_skill_for_slot(slot: String) -> Dictionary:
	"""获取指定槽位的技能信息"""
	var skill_id = player_skills.get(slot, "")
	if skill_id == "":
		return {}
	return SkillDB.get_skill(skill_id)

func can_use_skill(slot: String) -> bool:
	"""检查技能是否可用（冷却完成）"""
	var cooldown = skill_cooldowns.get(slot, 0.0)
	return cooldown <= 0.0

func use_skill(slot: String) -> bool:
	"""使用技能，返回是否成功"""
	if not can_use_skill(slot):
		return false
	
	var skill = get_skill_for_slot(slot)
	if skill.is_empty():
		return false
	
	skill_cooldowns[slot] = skill.get("cooldown", 0.0)
	return true

func update_skill_cooldowns(delta: float) -> void:
	"""更新所有技能冷却时间"""
	for slot in skill_cooldowns.keys():
		if skill_cooldowns[slot] > 0:
			skill_cooldowns[slot] -= delta
			skill_cooldowns[slot] = max(0.0, skill_cooldowns[slot])

func get_skill_cooldown(slot: String) -> float:
	"""获取技能剩余冷却时间"""
	return skill_cooldowns.get(slot, 0.0)

func get_skill_max_cooldown(slot: String) -> float:
	"""获取技能最大冷却时间"""
	var skill = get_skill_for_slot(slot)
	return skill.get("cooldown", 0.0)

# ════════════════════════════════════════════════
#  效果系统
# ════════════════════════════════════════════════

func add_effect(effect_name: String, duration: float, value: float = 0.0) -> void:
	active_effects.append({
		"name": effect_name,
		"duration": duration,
		"max_duration": duration,
		"value": value,
		"time_remaining": duration
	})

func remove_effect(effect_name: String) -> void:
	for i in range(active_effects.size()):
		if active_effects[i]["name"] == effect_name:
			active_effects.remove_at(i)
			return

func has_effect(effect_name: String) -> bool:
	for effect in active_effects:
		if effect["name"] == effect_name:
			return true
	return false

func update_effects(delta: float) -> void:
	var to_remove = []
	for i in range(active_effects.size()):
		active_effects[i]["time_remaining"] -= delta
		if active_effects[i]["time_remaining"] <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		active_effects.remove_at(to_remove[i])

func get_active_effects() -> Array:
	return active_effects.duplicate()
