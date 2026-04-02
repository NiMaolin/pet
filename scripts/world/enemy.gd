## Enemy - 敌人AI（水墨风格贴图版）
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
var enemy_type: String = "velociraptor"  # 敌人类型
var target: Node2D = null
var attack_cooldown: float = 0.0
var stun_timer: float = 0.0

# 巡逻相关
var patrol_timer: float = 0.0
var patrol_direction: Vector2 = Vector2.ZERO
var patrol_wait_time: float = 0.0
var home_position: Vector2 = Vector2.ZERO

# 动画状态
var anim_state: String = "idle"
var anim_timer: float = 0.0
var anim_frame: int = 0
var is_hurt_flash: bool = false
var hp_bar: ColorRect = null

# 水墨贴图
var sprite: Sprite2D = null

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

	# 创建水墨风格贴图精灵
	sprite = Sprite2D.new()
	sprite.z_index = 1
	add_child(sprite)
	
	# 根据敌人类型加载对应贴图
	var tex_path = "res://assets/ink/enemy_" + enemy_type + ".png"
	var tex = load(tex_path)
	if tex:
		sprite.texture = tex
		sprite.centered = false
		print("  贴图: " + tex_path)
	else:
		# 默认贴图
		tex = load("res://assets/ink/enemy_velociraptor.png")
		if tex:
			sprite.texture = tex
			sprite.centered = false
			print("  使用默认贴图")
	
	# 生成血条
	_create_hp_bar()

func _create_hp_bar() -> void:
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.position = Vector2(-15, -45)
	bar_bg.size = Vector2(30, 4)
	add_child(bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.color = Color(0.2, 0.9, 0.2)
	hp_bar.position = Vector2(-15, -45)
	hp_bar.size = Vector2(30, 4)
	add_child(hp_bar)

func _update_hp_bar() -> void:
	if hp_bar:
		var ratio = float(health) / float(max_health)
		hp_bar.size.x = 30.0 * ratio
		hp_bar.color = Color(1.0 - ratio, ratio * 0.9, 0.1)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if attack_cooldown > 0:
		attack_cooldown -= delta

	if stun_timer > 0:
		stun_timer -= delta
		anim_state = "idle"
		return

	if target == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]

	if target == null:
		anim_state = "idle"
		return

	var distance = global_position.distance_to(target.global_position)

	if distance < attack_range and attack_cooldown <= 0:
		_do_attack()
		anim_state = "idle"
		velocity = Vector2.ZERO
	elif distance < detection_range:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		anim_state = "walk"
		# 翻转朝向
		if direction.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	else:
		_do_patrol(delta)

	anim_timer += delta
	var frame_time = 0.15 if anim_state == "walk" else 0.5
	if anim_timer >= frame_time:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4
	
	# 受伤闪烁
	if is_hurt_flash and sprite:
		sprite.modulate = Color(1.5, 0.5, 0.5)
	else:
		sprite.modulate = Color(1, 1, 1)

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
		anim_state = "walk"
		if patrol_direction.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		return
	
	if patrol_wait_time > 0:
		patrol_wait_time -= delta
		anim_state = "idle"
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
		anim_state = "walk"
		if patrol_direction.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	else:
		anim_state = "idle"

func _do_attack() -> void:
	if target and target.has_method("take_damage"):
		target.call("take_damage", attack_power)
		attack_cooldown = 1.5

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
	_become_loot_box(loot)

	queue_free()

func _become_loot_box(loot: Array) -> void:
	var box = Area2D.new()
	box.global_position = global_position
	box.add_to_group("interactable")
	box.script = preload("res://scripts/world/loot_box.gd")
	box.set_meta("loot_items", loot)

	# 盒子外观（水墨风格物资箱）
	var visual_node = Sprite2D.new()
	var tex = load("res://assets/ink/loot_level1.png")
	if tex:
		visual_node.texture = tex
		visual_node.centered = false
	box.add_child(visual_node)

	# 碰撞
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	box.add_child(shape)

	get_tree().current_scene.add_child(box)
	print("📦 盒子已生成，物品数: %d" % loot.size())
