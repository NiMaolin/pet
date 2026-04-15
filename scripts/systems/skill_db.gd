## SkillDB - 技能数据库
extends Node

# 技能类型枚举
enum SkillType {
	MELEE,      # 近战攻击
	RANGED,     # 远程攻击
	BUFF,       # 增益效果
	DEBUFF,     # 减益效果
	HEAL,       # 治疗
	SPECIAL     # 特殊效果（位移、召唤等）
}

# 技能定义
const SKILLS: Dictionary = {
	# === 技能1 (Q键) - 快速技能 ===
	"skill_q_001": {
		"id": "skill_q_001",
		"name": "利爪挥击",
		"icon": "",  # 预留图标路径
		"type": SkillType.MELEE,
		"damage": 35,
		"range": 70,
		"radius": 0,  # 0为单体
		"cooldown": 2.0,
		"cost": 0,
		"duration": 0,
		"effects": [],
		"description": "快速挥动利爪，对前方敌人造成伤害"
	},
	
	"skill_q_002": {
		"id": "skill_q_002",
		"name": "火焰吐息",
		"icon": "",
		"type": SkillType.RANGED,
		"damage": 25,
		"range": 200,
		"radius": 40,  # AOE范围
		"cooldown": 2.5,
		"cost": 0,
		"duration": 0,
		"effects": ["burn"],  # 燃烧效果
		"description": "喷射火焰，对范围内敌人造成伤害并点燃"
	},
	
	# === 技能2 (E键) - 中等冷却 ===
	"skill_e_001": {
		"id": "skill_e_001",
		"name": "钢铁护甲",
		"icon": "",
		"type": SkillType.BUFF,
		"damage": 0,
		"range": 0,
		"radius": 0,
		"cooldown": 8.0,
		"cost": 0,
		"duration": 5.0,  # 持续5秒
		"effects": ["defense_up"],
		"description": "提升防御力，持续5秒"
	},
	
	"skill_e_002": {
		"id": "skill_e_002",
		"name": "毒雾陷阱",
		"icon": "",
		"type": SkillType.DEBUFF,
		"damage": 10,
		"range": 150,
		"radius": 60,
		"cooldown": 10.0,
		"cost": 0,
		"duration": 4.0,
		"effects": ["poison", "slow"],
		"description": "释放毒雾，减速并持续伤害敌人"
	},
	
	# === 技能3 (R键) - 强力技能 ===
	"skill_r_001": {
		"id": "skill_r_001",
		"name": "狂暴冲锋",
		"icon": "",
		"type": SkillType.SPECIAL,
		"damage": 50,
		"range": 150,
		"radius": 0,
		"cooldown": 15.0,
		"cost": 0,
		"duration": 0,
		"effects": ["dash", "stun"],
		"description": "向前冲锋，撞晕路径上的敌人"
	},
	
	"skill_r_002": {
		"id": "skill_r_002",
		"name": "生命汲取",
		"icon": "",
		"type": SkillType.HEAL,
		"damage": 40,
		"range": 100,
		"radius": 80,
		"cooldown": 12.0,
		"cost": 0,
		"duration": 0,
		"effects": ["lifesteal"],
		"description": "吸取周围敌人的生命值"
	},
}

# 获取技能信息
func get_skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})

# 获取技能名称
func get_skill_name(skill_id: String) -> String:
	return SKILLS.get(skill_id, {}).get("name", "未知技能")

# 获取技能类型字符串
func get_skill_type_str(skill_id: String) -> String:
	var skill_type = SKILLS.get(skill_id, {}).get("type", SkillType.MELEE)
	match skill_type:
		SkillType.MELEE: return "melee"
		SkillType.RANGED: return "ranged"
		SkillType.BUFF: return "buff"
		SkillType.DEBUFF: return "debuff"
		SkillType.HEAL: return "heal"
		SkillType.SPECIAL: return "special"
	return "melee"

# 获取默认技能配置（按槽位）
func get_default_skills() -> Dictionary:
	return {
		"slot_q": "skill_q_001",  # Q键默认技能
		"slot_e": "skill_e_001",  # E键默认技能
		"slot_r": "skill_r_001",  # R键默认技能
	}
