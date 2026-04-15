## SkillHUD - 技能显示UI
extends CanvasLayer

var skill_q_icon: Control
var skill_e_icon: Control
var skill_r_icon: Control
var skill_q_cd_label: Label
var skill_e_cd_label: Label
var skill_r_cd_label: Label

func _ready() -> void:
	# 获取UI节点引用
	skill_q_icon = $SkillPanel/HBox/SkillQ
	skill_e_icon = $SkillPanel/HBox/SkillE
	skill_r_icon = $SkillPanel/HBox/SkillR
	
	skill_q_cd_label = $SkillPanel/HBox/SkillQ/CooldownLabel
	skill_e_cd_label = $SkillPanel/HBox/SkillE/CooldownLabel
	skill_r_cd_label = $SkillPanel/HBox/SkillR/CooldownLabel
	
	# 初始化技能图标
	_update_skill_icon("slot_q", skill_q_icon)
	_update_skill_icon("slot_e", skill_e_icon)
	_update_skill_icon("slot_r", skill_r_icon)

func _process(delta: float) -> void:
	# 更新冷却显示
	_update_cooldown_display("slot_q", skill_q_cd_label, skill_q_icon)
	_update_cooldown_display("slot_e", skill_e_cd_label, skill_e_icon)
	_update_cooldown_display("slot_r", skill_r_cd_label, skill_r_icon)

func _update_skill_icon(slot: String, icon_node: Control) -> void:
	"""更新技能图标和名称"""
	var skill = GameData.get_skill_for_slot(slot)
	if skill.is_empty():
		return
	
	var label = icon_node.get_node_or_null("SkillName")
	if label:
		label.text = skill.get("name", "")
	
	# TODO: 加载技能图标图片
	# var icon_texture = icon_node.get_node_or_null("IconTexture")
	# if icon_texture and skill.get("icon", "") != "":
	#     icon_texture.texture = load(skill["icon"])

func _update_cooldown_display(slot: String, cd_label: Label, icon_node: Control) -> void:
	"""更新冷却时间显示"""
	var current_cd = GameData.get_skill_cooldown(slot)
	var max_cd = GameData.get_skill_max_cooldown(slot)
	
	if current_cd > 0:
		# 显示剩余冷却时间
		cd_label.text = "%.1f" % current_cd
		cd_label.visible = true
		
		# 灰色遮罩效果
		var mask = icon_node.get_node_or_null("CooldownMask")
		if mask:
			mask.visible = true
			var ratio = current_cd / max_cd
			# 可以通过调整mask的大小或透明度来显示进度
	else:
		# 冷却完成，隐藏显示
		cd_label.visible = false
		var mask = icon_node.get_node_or_null("CooldownMask")
		if mask:
			mask.visible = false
