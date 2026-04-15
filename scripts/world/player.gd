## Player - 玩家控制（精灵表动画版）
extends CharacterBody2D

@export var move_speed: float = 400.0

var is_alive: bool = true
var nearby_interactables: Array[Node] = []
var attack_cooldown: float = 0.0
const ATTACK_CD: float = 0.5
const ATTACK_RANGE: float = 60.0
const ATTACK_DAMAGE: int = 9999

# 动画状态
var anim_state: String = "idle"
var facing_dir: Vector2 = Vector2.DOWN
var is_hurt: bool = false
var hurt_timer: float = 0.0
var is_attacking: bool = false
var attack_anim_timer: float = 0.0
const ATTACK_ANIM_DURATION: float = 0.4

# AnimatedSprite2D
var anim_sprite: AnimatedSprite2D = null

func _ready() -> void:
	add_to_group("player")
	GameData.health_changed.connect(_on_health_changed)
	_setup_animated_sprite()
	_setup_collision()
	print("✅ 玩家已初始化（精灵表动画版）")

func _setup_collision() -> void:
	# 玩家碰撞形状（略小于一个格子，防止卡墙）
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0  # 比半个格子 (16) 小一点
	shape.shape = circle
	add_child(shape)
	print("[Player] Collision: layer=%d, mask=%d, radius=%s" % [collision_layer, collision_mask, circle.radius])

func _setup_animated_sprite() -> void:
	# 移除旧的蓝色 ColorRect（让它不可见）
	var old_rect = get_node_or_null("Sprite")
	if old_rect:
		old_rect.visible = false

	var tex_path = "res://assets/sprites2/player_sheet.png"
	var tex = load(tex_path)
	if not tex:
		push_warning("⚠️ 找不到玩家精灵表: " + tex_path)
		return

	# 创建 SpriteFrames
	var frames = SpriteFrames.new()

	# idle: 第0行，4帧
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 6.0)
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 0 * 48, 48, 48)
		frames.add_frame("idle", atlas)

	# walk: 第1行，4帧
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 10.0)
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 1 * 48, 48, 48)
		frames.add_frame("walk", atlas)

	# attack: 第2行，4帧
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 10.0)
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 2 * 48, 48, 48)
		frames.add_frame("attack", atlas)

	# 创建并添加 AnimatedSprite2D
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = "idle"
	anim_sprite.offset = Vector2(-24, -24)  # 居中对齐碰撞体
	anim_sprite.z_index = 1
	# 连接动画完成信号（攻击动画播完后回到 idle）
	anim_sprite.animation_finished.connect(_on_anim_finished)
	add_child(anim_sprite)
	anim_sprite.play("idle")

func _on_anim_finished() -> void:
	if anim_sprite and anim_sprite.animation == "attack":
		is_attacking = false
		anim_sprite.play("idle")

func _draw() -> void:
	# DEBUG: 绘制玩家碰撞区域（蓝色圆圈，radius=12）
	draw_circle(Vector2.ZERO, 12, Color(0.2, 0.5, 1.0, 0.4), true)  # 填充
	draw_arc(Vector2.ZERO, 12, 0, TAU, 32, Color(0.2, 0.7, 1.0, 0.9), 2.0)  # 边框

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if hurt_timer > 0:
		hurt_timer -= delta
		if hurt_timer <= 0:
			is_hurt = false
	
	# 更新技能冷却和效果
	GameData.update_skill_cooldowns(delta)
	GameData.update_effects(delta)

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 攻击动画期间不打断移动，但动画优先
	if not is_attacking:
		velocity = input_dir * move_speed
		move_and_slide()

		if input_dir.length() > 0.1:
			facing_dir = input_dir.normalized()
			_play_anim("walk")
		else:
			_play_anim("idle")
	else:
		# 攻击时仍可微移
		velocity = input_dir * move_speed * 0.3
		move_and_slide()

	# 根据朝向翻转
	if anim_sprite:
		if facing_dir.x < -0.1:
			anim_sprite.flip_h = true
		elif facing_dir.x > 0.1:
			anim_sprite.flip_h = false

	# 受伤闪烁
	if anim_sprite:
		if is_hurt:
			anim_sprite.modulate = Color(1.5, 0.5, 0.5)
		else:
			anim_sprite.modulate = Color(1, 1, 1)

func _play_anim(anim: String) -> void:
	if anim_sprite and anim_sprite.animation != anim:
		anim_sprite.play(anim)

func _input(event: InputEvent) -> void:
	if not is_alive:
		return
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_melee_attack()
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("fuse_pet"):
		_toggle_fusion()
	# 技能释放
	if event.is_action_pressed("skill_1"):
		_use_skill("slot_q")
	if event.is_action_pressed("skill_2"):
		_use_skill("slot_e")
	if event.is_action_pressed("skill_3"):
		_use_skill("slot_r")

func _melee_attack() -> void:
	if attack_cooldown > 0: return
	attack_cooldown = ATTACK_CD

	# 播放攻击动画
	is_attacking = true
	if anim_sprite:
		anim_sprite.play("attack")

	print("⚔️ 砍刀攻击！")

	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		if not "global_position" in enemy:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= ATTACK_RANGE:
			var dir = (enemy.global_position - global_position).normalized()
			var dot = dir.dot(facing_dir)
			if dot > 0.7:  # 约±45度扇形，更合理的近战范围
				enemy.take_damage(ATTACK_DAMAGE, self)

func _try_interact() -> void:
	var nearby = get_tree().get_nodes_in_group("interactable")
	var closest = null
	var min_dist = INF
	for node in nearby:
		if not "global_position" in node:
			continue
		var d = global_position.distance_to(node.global_position)
		if d < min_dist:
			min_dist = d
			closest = node
	if closest and min_dist < 80:
		if closest.has_method("interact"):
			closest.interact(self)

func _on_health_changed(current: int, max_val: int) -> void:
	pass

func take_damage(amount: int) -> void:
	# 统一使用 GameData 的伤害计算逻辑
	GameData.take_damage(amount)
	is_hurt = true
	hurt_timer = 0.2
	if not GameData.is_alive():
		die()

func die() -> void:
	is_alive = false
	print("💀 玩家死亡")
	GameData.clear_inventory()
	get_tree().current_scene.show_death_screen()

func _toggle_fusion() -> void:
	if GameData.equipped_pet_id == 0:
		return
	if GameData.fused_pet_id != 0:
		GameData.fused_pet_id = 0
		GameData.pet_unfused.emit()
		print("💨 解除合体")
	else:
		GameData.fused_pet_id = GameData.equipped_pet_id
		GameData.pet_fused.emit(GameData.equipped_pet_id)
		print("🔗 合体成功！")

# ════════════════════════════════════════════════
#  技能系统
# ════════════════════════════════════════════════

func _use_skill(slot: String) -> void:
	"""释放技能"""
	if not GameData.use_skill(slot):
		print("⚠️ 技能冷却中或无效")
		return
	
	var skill = GameData.get_skill_for_slot(slot)
	if skill.is_empty():
		return
	
	var skill_type = SkillDB.get_skill_type_str(skill["id"])
	print("✨ 释放技能: %s (%s)" % [skill["name"], slot])
	
	match skill_type:
		"melee":
			_execute_melee_skill(skill)
		"ranged":
			_execute_ranged_skill(skill)
		"buff":
			_execute_buff_skill(skill)
		"debuff":
			_execute_debuff_skill(skill)
		"heal":
			_execute_heal_skill(skill)
		"special":
			_execute_special_skill(skill)

func _execute_melee_skill(skill: Dictionary) -> void:
	"""执行近战技能"""
	var damage = skill.get("damage", 0)
	var range_val = skill.get("range", 70)
	
	# 播放攻击动画
	is_attacking = true
	if anim_sprite:
		anim_sprite.play("attack")
	
	# 检测范围内的敌人
	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		if not "global_position" in enemy:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= range_val:
			var dir = (enemy.global_position - global_position).normalized()
			var dot = dir.dot(facing_dir)
			if dot > 0.5:  # ±60度范围
				enemy.take_damage(damage, self)
				print("  → 命中: %s (%d伤害)" % [enemy.name, damage])

func _execute_ranged_skill(skill: Dictionary) -> void:
	"""执行远程技能（简化版：直接AOE）"""
	var damage = skill.get("damage", 0)
	var range_val = skill.get("range", 200)
	var radius = skill.get("radius", 40)
	
	# 在前方生成一个AOE区域
	var target_pos = global_position + facing_dir * range_val
	
	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		if not "global_position" in enemy:
			continue
		var dist = enemy.global_position.distance_to(target_pos)
		if dist <= radius:
			enemy.take_damage(damage, self)
			print("  → AOE命中: %s (%d伤害)" % [enemy.name, damage])
	
	# TODO: 添加视觉效果（粒子、音效等）

func _execute_buff_skill(skill: Dictionary) -> void:
	"""执行增益技能"""
	var duration = skill.get("duration", 5.0)
	var effects = skill.get("effects", [])
	
	for effect in effects:
		if effect == "defense_up":
			GameData.add_effect("defense_up", duration, 10.0)
			print("  → 防御力提升 +10，持续%.1f秒" % duration)
		# 可以添加更多buff类型

func _execute_debuff_skill(skill: Dictionary) -> void:
	"""执行减益技能（对范围内敌人）"""
	var damage = skill.get("damage", 0)
	var range_val = skill.get("range", 150)
	var radius = skill.get("radius", 60)
	var duration = skill.get("duration", 4.0)
	var effects = skill.get("effects", [])
	
	# 先造成伤害
	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		if not "global_position" in enemy:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= range_val:
			enemy.take_damage(damage, self)
			
			# 施加debuff（需要在enemy.gd中添加效果系统）
			for effect in effects:
				if effect == "poison":
					print("  → 施加中毒效果")
				elif effect == "slow":
					print("  → 施加减速效果")

func _execute_heal_skill(skill: Dictionary) -> void:
	"""执行治疗技能"""
	var damage = skill.get("damage", 0)
	var range_val = skill.get("range", 100)
	var radius = skill.get("radius", 80)
	
	# 对范围内敌人造成伤害并吸血
	var total_damage = 0
	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		if not "global_position" in enemy:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= range_val:
			enemy.take_damage(damage, self)
			total_damage += damage
	
	# 恢复生命值（吸取50%伤害）
	var heal_amount = int(total_damage * 0.5)
	if heal_amount > 0:
		GameData.heal(heal_amount)
		print("  → 生命汲取: 恢复 %d HP" % heal_amount)

func _execute_special_skill(skill: Dictionary) -> void:
	"""执行特殊技能"""
	var effects = skill.get("effects", [])
	
	for effect in effects:
		if effect == "dash":
			# 冲锋效果：向前位移
			var dash_distance = skill.get("range", 150)
			velocity = facing_dir * 1000  # 高速移动
			move_and_slide()
			print("  → 冲锋!")
		elif effect == "stun":
			# 眩晕附近敌人
			var targets = get_tree().get_nodes_in_group("enemies")
			for enemy in targets:
				if not "global_position" in enemy:
					continue
				var dist = global_position.distance_to(enemy.global_position)
				if dist <= 100:
					# TODO: 在enemy.gd中添加stun逻辑
					print("  → 眩晕敌人")
