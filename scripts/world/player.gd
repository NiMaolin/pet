## Player - 玩家控制（水墨风格贴图版）
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
var anim_timer: float = 0.0
var anim_frame: int = 0
var facing_dir: Vector2 = Vector2.DOWN
var is_hurt: bool = false
var hurt_timer: float = 0.0

# 水墨贴图
var sprite: Sprite2D = null
var sprite_texture: CompressedTexture2D = null

func _ready() -> void:
	add_to_group("player")
	GameData.health_changed.connect(_on_health_changed)
	
	# 加载水墨风格玩家贴图
	sprite = Sprite2D.new()
	sprite.z_index = 1
	add_child(sprite)
	
	# 加载贴图
	var tex_path = "res://assets/ink/player.png"
	var tex = load(tex_path)
	if tex:
		sprite.texture = tex
		sprite.centered = false
		print("✅ 玩家已初始化（水墨风格）")
	else:
		print("⚠️ 未找到玩家贴图: " + tex_path)
	
	print("✅ 玩家已初始化")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if hurt_timer > 0:
		hurt_timer -= delta
		if hurt_timer <= 0:
			is_hurt = false

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * move_speed
	move_and_slide()

	if input_dir.length() > 0.1:
		facing_dir = input_dir.normalized()
		anim_state = "walk"
	else:
		anim_state = "idle"

	anim_timer += delta
	var frame_time = 0.12 if anim_state == "walk" else 0.4
	if anim_timer >= frame_time:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4
	
	# 根据朝向翻转
	if facing_dir.x < -0.1:
		sprite.flip_h = true
	elif facing_dir.x > 0.1:
		sprite.flip_h = false
	
	# 受伤闪烁
	if is_hurt and sprite:
		sprite.modulate = Color(1.5, 0.5, 0.5)
	else:
		sprite.modulate = Color(1, 1, 1)

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

func _melee_attack() -> void:
	if attack_cooldown > 0: return
	attack_cooldown = ATTACK_CD
	
	print("⚔️ 砍刀攻击！")
	
	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		if not "global_position" in enemy:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= ATTACK_RANGE:
			var dir = (enemy.global_position - global_position).normalized()
			var dot = dir.dot(facing_dir)
			if dot > 0.3:
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
	var actual = max(1, amount - GameData.player_defense)
	GameData.player_health -= actual
	GameData.health_changed.emit(GameData.player_health, GameData.player_max_health)
	is_hurt = true
	hurt_timer = 0.2
	if GameData.player_health <= 0:
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
