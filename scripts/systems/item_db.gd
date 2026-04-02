## ItemDB - 物品数据库
extends Node

# 物品类型
enum ItemType { MATERIAL, EQUIPMENT, CONSUMABLE, PET_EGG }

# 稀有度
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

# 物品定义（shape 格式：行x列，对应格子数 1/2/3/4/6/9）
const ITEMS: Dictionary = {
	# 材料（1格 或 2格）
	1: {"id": 1, "name": "远古骨头",   "type": ItemType.MATERIAL,   "rarity": Rarity.COMMON,    "shape": "1x1", "color": "ccbbaa", "max_stack": 99, "price": 10},
	2: {"id": 2, "name": "恐龙鳞片",   "type": ItemType.MATERIAL,   "rarity": Rarity.RARE,      "shape": "1x2", "color": "44aaff", "max_stack": 50, "price": 50},
	3: {"id": 3, "name": "远古琥珀",   "type": ItemType.MATERIAL,   "rarity": Rarity.EPIC,      "shape": "1x1", "color": "ffaa00", "max_stack": 30, "price": 200},
	4: {"id": 4, "name": "霸王龙牙齿", "type": ItemType.MATERIAL,   "rarity": Rarity.LEGENDARY, "shape": "1x3", "color": "ff4444", "max_stack": 10, "price": 1000},
	5: {"id": 5, "name": "史前化石",   "type": ItemType.MATERIAL,   "rarity": Rarity.RARE,      "shape": "2x1", "color": "bbaa88", "max_stack": 20, "price": 80},
	# 装备（4格 或 6格）
	10: {"id": 10, "name": "兽皮护甲", "type": ItemType.EQUIPMENT,  "rarity": Rarity.COMMON,    "shape": "2x2", "color": "aa8844", "defense": 10, "max_stack": 1, "price": 100},
	11: {"id": 11, "name": "恐龙骨甲", "type": ItemType.EQUIPMENT,  "rarity": Rarity.RARE,      "shape": "2x3", "color": "4488ff", "defense": 25, "max_stack": 1, "price": 500},
	12: {"id": 12, "name": "远古护符", "type": ItemType.EQUIPMENT,  "rarity": Rarity.EPIC,      "shape": "1x2", "color": "aa44ff", "effect": "hp_up", "value": 50, "max_stack": 1, "price": 1000},
	13: {"id": 13, "name": "霸王铠甲", "type": ItemType.EQUIPMENT,  "rarity": Rarity.LEGENDARY, "shape": "3x3", "color": "ff8800", "defense": 50, "max_stack": 1, "price": 5000},
	# 消耗品（1格 或 2格）
	20: {"id": 20, "name": "草药",     "type": ItemType.CONSUMABLE, "rarity": Rarity.COMMON,    "shape": "1x1", "color": "44ff44", "heal": 30, "max_stack": 20, "price": 20},
	21: {"id": 21, "name": "治疗药剂", "type": ItemType.CONSUMABLE, "rarity": Rarity.RARE,      "shape": "1x2", "color": "ff4488", "heal": 80, "max_stack": 10, "price": 100},
	22: {"id": 22, "name": "力量药水", "type": ItemType.CONSUMABLE, "rarity": Rarity.EPIC,      "shape": "1x1", "color": "ff4444", "effect": "attack_up", "value": 20, "duration": 60, "max_stack": 5, "price": 300},
}

# 获取物品信息
func get_item(item_id: int) -> Dictionary:
	return ITEMS.get(item_id, {})

# 获取物品名称
func get_item_name(item_id: int) -> String:
	return ITEMS.get(item_id, {}).get("name", "未知物品")

# 获取物品图标
func get_item_icon(item_id: int) -> String:
	return ITEMS.get(item_id, {}).get("icon", "?")

# 获取物品颜色
func get_item_color(item_id: int) -> Color:
	var hex = ITEMS.get(item_id, {}).get("color", "ffffff")
	return Color("#" + hex)

# 是否可堆叠
func is_stackable(item_id: int) -> bool:
	return ITEMS.get(item_id, {}).get("max_stack", 1) > 1

# 获取最大堆叠数
func get_max_stack(item_id: int) -> int:
	return ITEMS.get(item_id, {}).get("max_stack", 1)

# 获取物品稀有度字符串（供 LootUI 使用）
func get_item_rarity_str(item_id: int) -> String:
	var rarity = ITEMS.get(item_id, {}).get("rarity", Rarity.COMMON)
	match rarity:
		Rarity.COMMON: return "common"
		Rarity.RARE: return "rare"
		Rarity.EPIC: return "epic"
		Rarity.LEGENDARY: return "legendary"
	return "common"

# 随机生成战利品（含稀有度字段）
func generate_loot(loot_level: int) -> Array:
	var raw = []
	match loot_level:
		1:
			raw.append({"id": 1, "amount": randi_range(1, 3)})
			if randf() < 0.3:
				raw.append({"id": 20, "amount": 1})
		2:
			raw.append({"id": 1, "amount": randi_range(2, 5)})
			raw.append({"id": 2, "amount": randi_range(1, 2)})
			if randf() < 0.4:
				raw.append({"id": 10, "amount": 1})
		3:
			raw.append({"id": 2, "amount": randi_range(2, 4)})
			raw.append({"id": 3, "amount": 1})
			if randf() < 0.5:
				raw.append({"id": 11, "amount": 1})
			if randf() < 0.3:
				raw.append({"id": 21, "amount": 1})
	# 注入稀有度字段
	for item in raw:
		item["rarity"] = get_item_rarity_str(item["id"])
	return raw
