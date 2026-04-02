## PetDB - 宠物数据库
extends Node

# 宠物类型
enum PetType { MELEE, RANGED }

# 稀有度
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

# 技能类型
enum SkillType { MELEE_ATTACK, RANGED_ATTACK, BUFF, DEBUFF, HEAL, SPECIAL }

# 宠物定义
const PETS: Dictionary = {
	# 史前世界宠物
	1: {
		"id": 1,
		"name": "迅猛龙",
		"type": PetType.MELEE,
		"rarity": Rarity.COMMON,
		"icon": "🦖",
		"color": "44ff44",
		"stats": {"hp": 80, "attack": 25, "defense": 15, "speed": 30},
		"skills": [
			{"name": "利爪攻击", "type": SkillType.MELEE_ATTACK, "damage": 30, "cooldown": 1.0},
			{"name": "撕咬", "type": SkillType.MELEE_ATTACK, "damage": 45, "cooldown": 2.5}
		],
		"capture_rate": 0.3
	},
	2: {
		"id": 2,
		"name": "翼龙",
		"type": PetType.RANGED,
		"rarity": Rarity.RARE,
		"icon": "🦅",
		"color": "4488ff",
		"stats": {"hp": 60, "attack": 30, "defense": 10, "speed": 35},
		"skills": [
			{"name": "风刃", "type": SkillType.RANGED_ATTACK, "damage": 25, "range": 300, "cooldown": 0.8},
			{"name": "俯冲", "type": SkillType.MELEE_ATTACK, "damage": 50, "cooldown": 3.0}
		],
		"capture_rate": 0.2
	},
	3: {
		"id": 3,
		"name": "剑齿虎",
		"type": PetType.MELEE,
		"rarity": Rarity.RARE,
		"icon": "🐅",
		"color": "ff8844",
		"stats": {"hp": 100, "attack": 35, "defense": 20, "speed": 25},
		"skills": [
			{"name": "獠牙突刺", "type": SkillType.MELEE_ATTACK, "damage": 40, "cooldown": 1.5},
			{"name": "咆哮", "type": SkillType.BUFF, "effect": "attack_up", "cooldown": 5.0}
		],
		"capture_rate": 0.2
	},
	4: {
		"id": 4,
		"name": "霸王龙",
		"type": PetType.MELEE,
		"rarity": Rarity.LEGENDARY,
		"icon": "🦕",
		"color": "ff4444",
		"stats": {"hp": 150, "attack": 50, "defense": 30, "speed": 15},
		"skills": [
			{"name": "巨颚撕咬", "type": SkillType.MELEE_ATTACK, "damage": 70, "cooldown": 2.0},
			{"name": "地震", "type": SkillType.SPECIAL, "damage": 40, "range": 200, "cooldown": 5.0}
		],
		"capture_rate": 0.05
	},
	5: {
		"id": 5,
		"name": "三角龙",
		"type": PetType.MELEE,
		"rarity": Rarity.EPIC,
		"icon": "🦏",
		"color": "aa88ff",
		"stats": {"hp": 120, "attack": 30, "defense": 40, "speed": 10},
		"skills": [
			{"name": "角撞", "type": SkillType.MELEE_ATTACK, "damage": 45, "cooldown": 1.8},
			{"name": "防御姿态", "type": SkillType.BUFF, "effect": "defense_up", "cooldown": 6.0}
		],
		"capture_rate": 0.1
	},
}

# 获取宠物信息
func get_pet(pet_id: int) -> Dictionary:
	return PETS.get(pet_id, {})

# 获取所有宠物ID
func get_all_pet_ids() -> Array:
	return PETS.keys()

# 按稀有度获取宠物
func get_pets_by_rarity(rarity: Rarity) -> Array:
	var result = []
	for pet_id in PETS:
		if PETS[pet_id]["rarity"] == rarity:
			result.append(pet_id)
	return result

# 随机获取宠物（用于敌人生成）
func get_random_pet_for_enemy(level: int) -> int:
	# 根据等级选择合适稀有度的宠物
	var candidates = []
	if level <= 2:
		candidates = get_pets_by_rarity(Rarity.COMMON)
	elif level <= 4:
		candidates = get_pets_by_rarity(Rarity.COMMON) + get_pets_by_rarity(Rarity.RARE)
	else:
		candidates = PETS.keys()

	if candidates.is_empty():
		return 1
	return candidates[randi() % candidates.size()]
