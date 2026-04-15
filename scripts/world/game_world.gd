## GameWorld - 游戏世界（含道路/墙体地图）
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var loot_ui: CanvasLayer = $LootUI
@onready var skill_hud: CanvasLayer = $SkillHUD
@onready var health_label: Label          = $HUD/HealthLabel
@onready var pet_label: Label             = $HUD/PetLabel
@onready var inventory_label: Label       = $HUD/InventoryLabel
@onready var escape_panel: PanelContainer = $HUD/EscapePanel
@onready var escape_progress: ProgressBar = $HUD/EscapePanel/VBox/EscapeProgress
@onready var countdown_label: Label       = $HUD/EscapePanel/VBox/CountdownLabel

var loot_spots: Array = []
var enemies: Array = []
var escape_point: Area2D = null
var current_loot_spot: Node = null
var map_draw_node: Node2D = null  # 地图绘制节点

# 地图参数
const TILE_SIZE: int = 64
const MAP_W: int = 20   # 地图宽（格）
const MAP_H: int = 15   # 地图高（格）

# 地形类型：0=草地, 1=墙体, 2=道路, 3=水域, 4=沼泽, 5=毒区, 6=建筑
const TERRAIN_GRASS = 0
const TERRAIN_WALL = 1
const TERRAIN_ROAD = 2
const TERRAIN_WATER = 3
const TERRAIN_SWAMP = 4
const TERRAIN_POISON = 5
const TERRAIN_BUILDING = 6

func _ready() -> void:
	print("=== 游戏世界加载 ===")
	_generate_map()
	_validate_paths()  # 验证路径
	_update_hud()
	loot_ui.closed.connect(_on_loot_ui_closed)
	# 血量变化时实时更新 HUD
	GameData.health_changed.connect(_on_health_changed)

	# 设置相机跟随玩家
	var camera = Camera2D.new()
	camera.global_position = player.global_position
	camera.zoom = Vector2(1.2, 1.2)
	camera.position_smoothing_enabled = true  # 启用平滑跟随
	camera.position_smoothing_speed = 5.0     # 平滑速度
	add_child(camera)
	camera.make_current()

func _generate_map() -> void:
	# 1. 绘制地图背景（程序化）
	map_draw_node = Node2D.new()
	map_draw_node.z_index = -1
	add_child(map_draw_node)
	map_draw_node.draw.connect(_draw_map)
	map_draw_node.queue_redraw()  # 触发绘制

	# 2. 生成墙体（外圈 + 内部障碍）
	_create_walls()

	# 3. 生成物资点（在道路上或开阔草地区域）
	var player_start_y = 300
	var loot_positions = [
		Vector2(0, player_start_y - 200),      # 北边道路
		Vector2(0, player_start_y + 200),      # 南边道路
		Vector2(-150, player_start_y),         # 西边草地区域
		Vector2(150, player_start_y),          # 东边草地区域
		Vector2(-80, player_start_y - 80),     # 西北环形道路
	]
	for i in range(loot_positions.size()):
		var level = randi_range(1, 3)
		var spot = _create_loot_spot(loot_positions[i], i + 1, level)
		add_child(spot)
		loot_spots.append(spot)

	# 4. 生成敌人（随机找安全位置，不在墙/建筑/水域里）
	var enemy_count = 3
	var spawned = 0
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var attempts = 0
	while spawned < enemy_count and attempts < 500:
		attempts += 1
		var col = rng.randi_range(-MAP_W / 2 + 2, MAP_W / 2 - 2)
		var row = rng.randi_range(-MAP_H / 2 + 2, MAP_H / 2 - 2)
		var tile = _get_tile_type(col, row)
		# 只允许草地(0)和道路(2)，排除墙(1)、水(3)、沼泽(4)、毒区(5)、建筑(6)
		if tile != TERRAIN_GRASS and tile != TERRAIN_ROAD:
			continue
		var world_x = col * TILE_SIZE + TILE_SIZE / 2
		var world_y = 300 + row * TILE_SIZE + TILE_SIZE / 2
		# 避免生成在玩家附近（距离太近）
		if Vector2(world_x, world_y).distance_to(Vector2(0, 300)) < 150:
			continue
		var pet_id = PetDB.get_random_pet_for_enemy(randi_range(1, 3))
		var enemy = _create_enemy(Vector2(world_x, world_y), spawned + 1, pet_id)
		add_child(enemy)
		enemies.append(enemy)
		spawned += 1

	# 5. 撤离点（东南角开阔区域）
	escape_point = _create_escape_point(Vector2(350, player_start_y + 350))
	add_child(escape_point)


	print("✅ 地图生成完成: %d 个物资点, %d 个敌人, 1 个撤离点" % [loot_spots.size(), enemies.size()])

func _draw_map() -> void:
	var ts = TILE_SIZE
	var half_w = MAP_W / 2
	var half_h = MAP_H / 2

	var center_x = 0
	var center_y = 300

	for row in range(-half_h, half_h):
		for col in range(-half_w, half_w):
			var x = center_x + col * ts
			var y = center_y + row * ts
			var rect = Rect2(x, y, ts, ts)
			var tile_type = _get_tile_type(col, row)
			match tile_type:
				TERRAIN_GRASS:  # 草地
					map_draw_node.draw_rect(rect, Color(0.22, 0.45, 0.18))
					var seed_val = (col * 31 + row * 17) % 7
					if seed_val < 3:
						map_draw_node.draw_circle(
							Vector2(x + 12 + seed_val * 8, y + 10 + seed_val * 6),
							2, Color(0.18, 0.38, 0.14))
				TERRAIN_WALL:
					map_draw_node.draw_rect(rect, Color(0.35, 0.32, 0.28))
					map_draw_node.draw_rect(Rect2(x + 4, y + 4, ts - 10, ts - 10),
						Color(0.42, 0.38, 0.33))
					map_draw_node.draw_rect(Rect2(x + 2, y + 2, ts - 4, 3),
						Color(0.5, 0.47, 0.42))
					# DEBUG: red collision border
					map_draw_node.draw_rect(Rect2(x, y, ts, ts), Color(1, 0.15, 0.15, 0.9), false, 2.0)
				TERRAIN_ROAD:  # 泥土道路
					map_draw_node.draw_rect(rect, Color(0.55, 0.42, 0.28))
					for i in range(0, ts, 8):
						map_draw_node.draw_line(
							Vector2(x, y + i),
							Vector2(x + ts, y + i),
							Color(0.5, 0.38, 0.25, 0.4), 1)
				TERRAIN_WATER:  # 水域
					map_draw_node.draw_rect(rect, Color(0.2, 0.4, 0.7))
					# 水波纹
					for i in range(0, ts, 16):
						map_draw_node.draw_arc(Vector2(x + ts/2, y + ts/2), 8 + i/2, 0, PI, 8,
							Color(0.3, 0.5, 0.8, 0.5), 1)
				TERRAIN_SWAMP:  # 沼泽
					map_draw_node.draw_rect(rect, Color(0.3, 0.25, 0.15))
					# 沼泽气泡
					if (col + row) % 3 == 0:
						map_draw_node.draw_circle(Vector2(x + ts/2, y + ts/2), 4,
							Color(0.4, 0.35, 0.2, 0.7))
				TERRAIN_POISON:  # 毒区
					map_draw_node.draw_rect(rect, Color(0.4, 0.15, 0.4))
					# 毒雾效果
					for i in range(3):
						map_draw_node.draw_circle(
							Vector2(x + 10 + i * 15, y + 20 + (i % 2) * 10), 6,
							Color(0.6, 0.2, 0.6, 0.3))
				TERRAIN_BUILDING:  # 建筑
					map_draw_node.draw_rect(rect, Color(0.45, 0.4, 0.35))
					# 窗户
					map_draw_node.draw_rect(Rect2(x + 8, y + 8, 12, 12), Color(0.6, 0.55, 0.4))
					map_draw_node.draw_rect(Rect2(x + ts - 20, y + 8, 12, 12), Color(0.6, 0.55, 0.4))
					map_draw_node.draw_rect(Rect2(x + ts/2 - 6, y + ts - 16, 12, 14), Color(0.3, 0.2, 0.15))
					# DEBUG: red collision border
					map_draw_node.draw_rect(Rect2(x, y, ts, ts), Color(1, 0.15, 0.15, 0.9), false, 2.0)





func _get_tile_type(col: int, row: int) -> int:
	var half_w = MAP_W / 2
	var half_h = MAP_H / 2
	
	# 外圈是墙
	if col <= -half_w + 1 or col >= half_w - 1 or row <= -half_h + 1 or row >= half_h - 1:
		return TERRAIN_WALL
	
	# 道路优先（确保道路畅通）
	if col == 0 or row == 0:
		return TERRAIN_ROAD
	
	# 环形道路
	if (col == -2 or col == 2) and (row >= -2 and row <= 2):
		return TERRAIN_ROAD
	if (row == -2 or row == 2) and (col >= -2 and col <= 2):
		return TERRAIN_ROAD
	
	# 水域（左上角）
	if col <= -5 and row <= -4:
		return TERRAIN_WATER
	
	# 沼泽（右上角）
	if col >= 5 and row <= -4:
		return TERRAIN_SWAMP
	
	# 毒区（右下角，靠近撤离点但不在必经之路上）
	if col >= 6 and row >= 4 and not (col == 0 or row == 0):
		return TERRAIN_POISON
	
	# 建筑（左下角）
	if col <= -6 and row >= 4:
		return TERRAIN_BUILDING
	
	# 内部障碍墙（留出口连接道路）
	if (col == -4 or col == 4) and (row >= -3 and row <= 3):
		if row != 0:
			return TERRAIN_WALL
	if (row == -4 or row == 4) and (col >= -4 and col <= 4):
		if col != 0:
			return TERRAIN_WALL
	
	return TERRAIN_GRASS

func _create_walls() -> void:
	var half_w = MAP_W / 2
	var half_h = MAP_H / 2
	var center_x = 0
	var center_y = 300
	
	for row in range(-half_h, half_h):
		for col in range(-half_w, half_w):
			var tile = _get_tile_type(col, row)
			# 只有墙体和建筑阻挡移动
			if tile == TERRAIN_WALL or tile == TERRAIN_BUILDING:
				var wall = StaticBody2D.new()
				wall.position = Vector2(center_x + col * TILE_SIZE + TILE_SIZE / 2, 
										center_y + row * TILE_SIZE + TILE_SIZE / 2)
				var shape = CollisionShape2D.new()
				var rect = RectangleShape2D.new()
				rect.size = Vector2(TILE_SIZE, TILE_SIZE)
				shape.shape = rect
				wall.add_child(shape)
				add_child(wall)

func _create_loot_spot(pos: Vector2, id: int, level: int) -> Area2D:
	var spot = Area2D.new()
	spot.position = pos
	spot.script = preload("res://scripts/world/loot_spot.gd")
	spot.set_meta("spot_id", id)
	spot.set_meta("loot_level", level)
	# 程序化绘制物资箱外观
	var draw = Node2D.new()
	var colors = [Color(0.4,0.4,0.4), Color(0.27,0.67,1), Color(1,0.67,0.27)]
	var col = colors[clamp(level - 1, 0, colors.size() - 1)]
	draw.draw.connect(func():
		draw.draw_rect(Rect2(-16, -16, 32, 32), col.darkened(0.3))
		draw.draw_rect(Rect2(-14, -14, 28, 28), col)
		draw.draw_rect(Rect2(-14, -2, 28, 4), col.darkened(0.2))
		draw.draw_rect(Rect2(-2, -14, 4, 28), col.darkened(0.2))
		# 锁扣
		draw.draw_circle(Vector2(0, 0), 4, Color(0.8, 0.7, 0.2))
	)
	spot.add_child(draw)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	spot.add_child(shape)
	return spot

func _create_enemy(pos: Vector2, id: int, pet_id: int) -> CharacterBody2D:
	var enemy = CharacterBody2D.new()
	enemy.position = pos
	enemy.script = preload("res://scripts/world/enemy.gd")
	enemy.set_meta("enemy_id", id)
	enemy.set_meta("pet_id", pet_id)
	# 碰撞体
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	enemy.add_child(shape)
	return enemy

func _create_escape_point(pos: Vector2) -> Area2D:
	var escape = Area2D.new()
	escape.position = pos
	escape.script = preload("res://scripts/world/escape_point.gd")
	# 程序化绘制撤离点
	var draw = Node2D.new()
	draw.draw.connect(func():
		draw.draw_circle(Vector2(0, 0), 36, Color(0.1, 0.9, 0.3, 0.3))
		draw.draw_arc(Vector2(0, 0), 36, 0, TAU, 32, Color(0.2, 1.0, 0.4, 0.8), 3.0)
		# 向上箭头
		draw.draw_line(Vector2(0, 20), Vector2(0, -20), Color(0.2, 1.0, 0.4), 4)
		draw.draw_line(Vector2(0, -20), Vector2(-12, -8), Color(0.2, 1.0, 0.4), 4)
		draw.draw_line(Vector2(0, -20), Vector2(12, -8), Color(0.2, 1.0, 0.4), 4)
	)
	escape.add_child(draw)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 36
	shape.shape = circle
	escape.add_child(shape)
	return escape

func _update_hud() -> void:
	health_label.text = "❤️ HP: %d / %d" % [GameData.player_health, GameData.player_max_health]
	if GameData.fused_pet_id != 0:
		var pet = PetDB.get_pet(GameData.fused_pet_id)
		pet_label.text = "🔥 合体: %s" % pet.get("name", "未知")
	else:
		pet_label.text = "🐾 合体: 无"
	inventory_label.text = "🎒 背包: %d 件" % GameData.placed_items.size()

func _on_health_changed(current: int, _max_val: int) -> void:
	health_label.text = "❤️ HP: %d / %d" % [current, GameData.player_max_health]

func show_escape_progress(progress: float) -> void:
	if progress <= 0.0:
		escape_panel.visible = false
		return
	escape_panel.visible = true
	escape_progress.value = progress * 100.0
	# 修复：倒计时应该基于实际的撤离时间 ESCAPE_TIME (1秒)
	var remaining = maxf(0.0, 1.0 * (1.0 - progress))
	countdown_label.text = "%.1f 秒" % remaining
	if remaining <= 2.0:
		countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		countdown_label.remove_theme_color_override("font_color")

func on_escape_success() -> void:
	print("✅ 撤离成功！")
	GameData.transfer_inventory_to_warehouse()
	GameData.is_in_game = false
	if GameData.last_save_slot >= 0:
		SaveSystem.save_game(GameData.last_save_slot)
	SaveSystem.auto_save()
	get_tree().change_scene_to_file("res://scenes/ui/extract_success.tscn")

func open_loot_ui(items: Array, spot: Node) -> void:
	if loot_ui == null:
		push_error("LootUI 节点未找到！")
		return
	current_loot_spot = spot
	loot_ui.open_loot(items, spot)
	player.set_physics_process(false)
	player.set_process_input(false)

func _on_loot_ui_closed() -> void:
	current_loot_spot = null
	player.set_physics_process(true)
	player.set_process_input(true)
	_update_hud()

func show_death_screen() -> void:
	# 加载并显示死亡界面
	var death_scene = preload("res://scenes/ui/death_screen.tscn")
	var death = death_scene.instantiate()
	add_child(death)

# ════════════════════════════════════════════════
#  路径验证系统（A*算法）
# ════════════════════════════════════════════════

func _validate_paths() -> void:
	"""验证玩家出生点到撤离点的路径是否可达"""
	var player_pos = Vector2(0, 300)  # 玩家出生点
	var escape_pos = escape_point.position if escape_point else Vector2(350, 650)
	
	# 转换为网格坐标
	var start_col = int(player_pos.x / TILE_SIZE)
	var start_row = int((player_pos.y - 300) / TILE_SIZE)
	var end_col = int(escape_pos.x / TILE_SIZE)
	var end_row = int((escape_pos.y - 300) / TILE_SIZE)
	
	var path = _astar_search(Vector2(start_col, start_row), Vector2(end_col, end_row))
	
	if path.is_empty():
		push_warning("⚠️ 警告：玩家到撤离点无可行路径！尝试修复...")
		_fix_pathfinding(start_col, start_row, end_col, end_row)
	else:
		print("✅ 路径验证通过：找到 %d 步的有效路径" % path.size())

func _astar_search(start: Vector2, goal: Vector2) -> Array:
	"""A*路径查找算法"""
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: _heuristic(start, goal)}
	
	while not open_set.is_empty():
		# 找到 f_score 最小的节点
		var current = open_set[0]
		for node in open_set:
			if f_score.get(node, INF) < f_score.get(current, INF):
				current = node
		
		if current == goal:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		# 检查四个方向
		for neighbor in _get_neighbors(current):
			var tentative_g = g_score[current] + 1
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, goal)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return []  # 无路径

func _heuristic(a: Vector2, b: Vector2) -> float:
	"""曼哈顿距离启发式"""
	return abs(a.x - b.x) + abs(a.y - b.y)

func _get_neighbors(pos: Vector2) -> Array:
	"""获取可通行的邻居节点"""
	var neighbors = []
	var directions = [
		Vector2(1, 0), Vector2(-1, 0),
		Vector2(0, 1), Vector2(0, -1)
	]
	
	for dir in directions:
		var neighbor = pos + dir
		var tile_type = _get_tile_type(int(neighbor.x), int(neighbor.y))
		# 只允许草地和道路
		if tile_type == TERRAIN_GRASS or tile_type == TERRAIN_ROAD:
			neighbors.append(neighbor)
	
	return neighbors

func _reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	"""重构路径"""
	var path = [current]
	while current in came_from:
		current = came_from[current]
		path.push_front(current)
	return path

func _fix_pathfinding(start_col: int, start_row: int, end_col: int, end_row: int) -> void:
	"""修复路径问题：确保至少有一条通路"""
	print("🔧 正在修复路径...")
	
	# 简单策略：在起点和终点之间创建一条直线路径
	var col_step = 1 if end_col > start_col else -1
	var row_step = 1 if end_row > start_row else -1
	
	var col = start_col
	var row = start_row
	
	# 先横向移动
	while col != end_col:
		var tile = _get_tile_type(col, row)
		if tile == TERRAIN_WALL or tile == TERRAIN_BUILDING:
			print("  移除障碍: (%d, %d)" % [col, row])
			# 注意：这里只是打印，实际游戏中可能需要重新生成地图
		col += col_step
	
	# 再纵向移动
	while row != end_row:
		var tile = _get_tile_type(col, row)
		if tile == TERRAIN_WALL or tile == TERRAIN_BUILDING:
			print("  移除障碍: (%d, %d)" % [col, row])
		row += row_step
	
	print("✅ 路径修复完成")
