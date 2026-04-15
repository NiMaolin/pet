## Enemy - 敌人AI（精灵表动画版）
extends CharacterBody2D

@export var move_speed: float = 80.0
@export var detection_range: float = 200.0
@export var attack_range: float = 45.0

var is_alive: bool = true
var health: int = 50
var max_health: int = 50
var attack_power: int = 15
var defense: int = 5

var pet_id: int = 0
var enemy_type: String = "velociraptor"
var target: Node2D = null
var attack_cooldown: float = 0.0
var stun_timer: float = 0.0

# 巡逻
var patrol_timer: float = 0.0
var patrol_direction: Vector2 = Vector2.ZERO
var patrol_wait_time: float = 0.0
var home_position: Vector2 = Vector2.ZERO

# 动画
var anim_state: String = "idle"
var is_hurt_flash: bool = false
var is_attacking_anim: bool = false
var hp_bar: ColorRect = null
var anim_sprite: AnimatedSprite2D = null

func _ready() -> void:
	add_to_group("enemies")

	if has_meta("pet_id"):
		pet_id = get_meta("pet_id")
	if has_meta("enemy_type"):
		enemy_type = get_meta("enemy_type")

	if pet_id == 0:
		pet_id = PetDB.get_random_pet_for_enemy(1)

	var pet = PetDB.get_pet(pet_id)
	if not pet.is_empty():
		max_health = pet["stats"]["hp"]
		health = max_health
		attack_power = pet["stats"]["attack"]
		defense = pet["stats"]["defense"]
		print("生成敌人: %s (HP: %d, 攻击: %d)" % [pet["name"], health, attack_power])

	home_position = global_position
	_start_patrol()
	_setup_animated_sprite()
	_create_hp_bar()

func _setup_animated_sprite() -> void:
	# 根据敌人类型选择精灵表
	var tex_path = "res://assets/sprites2/enemy_" + enemy_type + "_sheet.png"
	var tex = load(tex_path)
	if not tex:
		tex = load("res://assets/sprites2/enemy_velociraptor_sheet.png")
	if not tex:
		push_warning("⚠️ 找不到敌人精灵表: " + tex_path)
		return

	var frames = SpriteFrames.new()

	# idle: 行0
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 5.0)
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 0, 48, 48)
		frames.add_frame("idle", atlas)

	# walk: 行1
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 9.0)
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 48, 48, 48)
		frames.add_frame("walk", atlas)

	# attack: 行2
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 9.0)
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 96, 48, 48)
		frames.add_frame("attack", atlas)

	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = "idle"
	anim_sprite.offset = Vector2(-24, -24)
	anim_sprite.z_index = 1
	anim_sprite.animation_finished.connect(_on_anim_finished)
	add_child(anim_sprite)
	anim_sprite.play("idle")

func _on_anim_finished() -> void:
	if anim_sprite and anim_sprite.animation == "attack":
		is_attacking_anim = false
		anim_sprite.play("idle")

func _create_hp_bar() -> void:
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.position = Vector2(-15, -32)
	bar_bg.size = Vector2(30, 4)
	add_child(bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.color = Color(0.2, 0.9, 0.2)
	hp_bar.position = Vector2(-15, -32)
	hp_bar.size = Vector2(30, 4)
	add_child(hp_bar)

func _update_hp_bar() -> void:
	if hp_bar:
		var ratio = float(health) / float(max_health)
		hp_bar.size.x = 30.0 * ratio
		hp_bar.color = Color(1.0 - ratio, ratio * 0.9, 0.1)

func _play_anim(anim: String) -> void:
	if anim_sprite and not is_attacking_anim and anim_sprite.animation != anim:
		anim_sprite.play(anim)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if attack_cooldown > 0:
		attack_cooldown -= delta

	if stun_timer > 0:
		stun_timer -= delta
		_play_anim("idle")
		return

	if target == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]

	if target == null:
		_play_anim("idle")
		return

	var distance = global_position.distance_to(target.global_position)

	if distance < attack_range and attack_cooldown <= 0:
		_do_attack()
		velocity = Vector2.ZERO
	elif distance < detection_range:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		_play_anim("walk")
		if anim_sprite:
			anim_sprite.flip_h = direction.x < 0
	else:
		_do_patrol(delta)

	# 受伤闪烁
	if anim_sprite:
		anim_sprite.modulate = Color(1.5, 0.5, 0.5) if is_hurt_flash else Color(1, 1, 1)

func _start_patrol() -> void:
	patrol_wait_time = randf_range(1.0, 3.0)
	patrol_timer = 0.0
	patrol_direction = Vector2.ZERO

func _do_patrol(delta: float) -> void:
	var dist_from_home = global_position.distance_to(home_position)
	var max_patrol_dist = 150.0

	if dist_from_home > max_patrol_dist:
		patrol_direction = (home_position - global_position).normalized()
		velocity = patrol_direction * move_speed * 0.5
		move_and_slide()
		_play_anim("walk")
		if anim_sprite:
			anim_sprite.flip_h = patrol_direction.x < 0
		return

	if patrol_wait_time > 0:
		patrol_wait_time -= delta
		_play_anim("idle")
		velocity = Vector2.ZERO
		return

	patrol_timer += delta
	if patrol_timer > randf_range(2.0, 4.0):
		if randf() > 0.4:
			patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		else:
			patrol_direction = Vector2.ZERO
		patrol_timer = 0.0
		patrol_wait_time = randf_range(1.0, 2.5)

	if patrol_direction != Vector2.ZERO:
		velocity = patrol_direction * move_speed * 0.5
		move_and_slide()
		_play_anim("walk")
		if anim_sprite:
			anim_sprite.flip_h = patrol_direction.x < 0
	else:
		_play_anim("idle")

func _do_attack() -> void:
	if target and target.has_method("take_damage"):
		target.call("take_damage", attack_power)
		attack_cooldown = 1.5
		# 播放攻击动画
		is_attacking_anim = true
		if anim_sprite:
			anim_sprite.play("attack")

func take_damage(amount: int, attacker: Node) -> void:
	var actual = max(1, amount - defense)
	health -= actual
	_update_hp_bar()

	stun_timer = 0.3
	is_hurt_flash = true

	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and is_alive:
		is_hurt_flash = false

	print("敌人受到 %d 伤害，剩余 HP: %d/%d" % [actual, health, max_health])

	if health <= 0:
		die(attacker)

func die(killer: Node) -> void:
	is_alive = false
	print("敌人被击败！→ 变成盒子")

	var pet = PetDB.get_pet(pet_id)
	var capture_rate = pet.get("capture_rate", 0.2)
	if randf() < capture_rate:
		GameData.collect_pet(pet_id)
		print("✅ 收服宠物: %s!" % pet["name"])
	elif randf() < 0.3:
		print("🥚 掉落宠物蛋: %s" % pet["name"])

	var loot = ItemDB.generate_loot(randi_range(1, 3))
	# 为掉落物添加 instance_id
	for i in range(loot.size()):
		loot[i]["instance_id"] = _generate_loot_instance_id(i)
		loot[i]["row"] = i % 6  # 物资箱 6 列
		loot[i]["col"] = i / 6
		loot[i]["searched"] = false
	var box = _become_loot_box(loot)
	# 先把箱子挂到场景根节点，避免随 enemy 一起被删除
	get_tree().current_scene.add_child(box)

	queue_free()

func _become_loot_box(loot: Array) -> Area2D:
	var box = Area2D.new()
	box.global_position = global_position
	box.add_to_group("interactable")
	box.script = preload("res://scripts/world/loot_box.gd")
	box.set_meta("loot_items", loot)
	# 标记为怪物箱，loot_box.gd 会使用对应图片
	box.set_meta("box_type", "enemy")
	
	# 怪物死亡箱：破旧暗木箱风格
	var visual_node = Sprite2D.new()
	var tex = load("res://assets/ink/loot_box_enemy.png")
	if not tex:
		tex = load("res://assets/ink/loot_level1.png")
	if tex:
		visual_node.texture = tex
		visual_node.centered = true
		visual_node.scale = Vector2(1.0, 1.0)
	box.add_child(visual_node)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	box.add_child(shape)

	print("box spawned, items: %d" % loot.size())
	return box

func _generate_loot_instance_id(offset: int) -> int:
	"""为掉落物生成唯一的 instance_id"""
	var base_id = Time.get_ticks_msec() % 100000
	return base_id * 100 + offset
