## AssetGenerator - 程序化生成游戏素材（PNG）
extends Node

func generate_all_assets() -> void:
	print("🎨 开始生成游戏素材...")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")
	if not dir.dir_exists("assets/sprites"):
		dir.make_dir("assets/sprites")
	if not dir.dir_exists("assets/tiles"):
		dir.make_dir("assets/tiles")
	
	_generate_player_sprite()
	_generate_enemy_sprites()
	_generate_loot_box_sprite()
	_generate_terrain_tiles()
	_generate_wall_tile()
	_generate_road_tile()
	
	print("✅ 素材生成完成！")

# ── 玩家角色 sprite sheet（4 帧行走动画）────────────────
func _generate_player_sprite() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # 透明背景
	
	# 4 帧行走动画（每帧 16×16）
	for frame in range(4):
		var x_offset = frame * 16
		_draw_player_frame(img, x_offset, 0, frame)
	
	img.save_png("res://assets/sprites/player.png")
	print("  ✅ player.png")

func _draw_player_frame(img: Image, x: int, y: int, frame: int) -> void:
	var skin = Color(0.95, 0.82, 0.65)
	var body = Color(0.25, 0.55, 1.0)
	var hair = Color(0.3, 0.2, 0.1)
	var leg = body.darkened(0.3)
	
	var leg_off = int(sin(frame * PI / 2.0) * 2.0)
	
	# 身体（矩形）
	for py in range(6, 12):
		for px in range(6, 10):
			img.set_pixel(x + px, y + py, body)
	
	# 头部（圆形近似）
	for py in range(0, 6):
		for px in range(6, 10):
			if (px - 8) * (px - 8) + (py - 3) * (py - 3) <= 9:
				img.set_pixel(x + px, y + py, skin)
	
	# 眼睛
	img.set_pixel(x + 7, y + 3, Color(0.1, 0.1, 0.1))
	img.set_pixel(x + 9, y + 3, Color(0.1, 0.1, 0.1))
	
	# 腿部
	for py in range(12, 14 + leg_off):
		img.set_pixel(x + 6, y + py, leg)
	for py in range(12, 14 - leg_off):
		img.set_pixel(x + 8, y + py, leg)

# ── 敌人 sprite sheet（3 种敌人 × 4 帧）────────────────
func _generate_enemy_sprites() -> void:
	var img = Image.create(48, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var enemy_colors = [
		Color(1, 0.3, 0.3),
		Color(0.3, 1, 0.3),
		Color(0.3, 0.3, 1),
	]
	
	for enemy_idx in range(3):
		for frame in range(4):
			var x_offset = frame * 12
			var y_offset = enemy_idx * 16
			_draw_enemy_frame(img, x_offset, y_offset, frame, enemy_colors[enemy_idx])
	
	img.save_png("res://assets/sprites/enemies.png")
	print("  ✅ enemies.png")

func _draw_enemy_frame(img: Image, x: int, y: int, frame: int, col: Color) -> void:
	var dark = col.darkened(0.3)
	var bob = int(sin(frame * PI / 2.0) * 1.0)
	
	# 身体（圆形）
	for py in range(4, 12):
		for px in range(2, 10):
			if (px - 6) * (px - 6) + (py - 8 + bob) * (py - 8 + bob) <= 16:
				img.set_pixel(x + px, y + py, col)
	
	# 头部
	for py in range(0, 6):
		for px in range(3, 9):
			if (px - 6) * (px - 6) + (py - 3) * (py - 3) <= 9:
				img.set_pixel(x + px, y + py, col)
	
	# 眼睛
	img.set_pixel(x + 4, y + 3, Color(1, 0.1, 0.1))
	img.set_pixel(x + 8, y + 3, Color(1, 0.1, 0.1))
	
	# 腿部
	var leg_off = int(sin(frame * PI / 2.0) * 1.5)
	img.set_pixel(x + 4, y + 12 + leg_off, dark)
	img.set_pixel(x + 8, y + 12 - leg_off, dark)

# ── 物资箱 sprite────────────────────────────────────────
func _generate_loot_box_sprite() -> void:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var box_col = Color(0.6, 0.4, 0.2)
	var dark = box_col.darkened(0.3)
	var lock = Color(0.8, 0.7, 0.2)
	
	# 箱子外壳
	for py in range(4, 28):
		for px in range(4, 28):
			img.set_pixel(px, py, box_col)
	
	# 箱子边框
	for px in range(4, 28):
		img.set_pixel(px, 4, dark)
		img.set_pixel(px, 27, dark)
	for py in range(4, 28):
		img.set_pixel(4, py, dark)
		img.set_pixel(27, py, dark)
	
	# 箱子盖子分割线
	for px in range(4, 28):
		img.set_pixel(px, 14, dark)
	
	# 锁扣
	for py in range(12, 20):
		for px in range(14, 18):
			if (px - 16) * (px - 16) + (py - 16) * (py - 16) <= 9:
				img.set_pixel(px, py, lock)
	
	img.save_png("res://assets/sprites/loot_box.png")
	print("  ✅ loot_box.png")

# ── 地形 tile（草地）────────────────────────────────────
func _generate_terrain_tiles() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var grass = Color(0.22, 0.45, 0.18)
	var dark_grass = Color(0.18, 0.38, 0.14)
	
	img.fill(grass)
	
	# 随机草地纹理
	for i in range(20):
		var seed_val = (i * 31) % 64
		var px = seed_val
		var py = (seed_val * 17) % 64
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx = px + dx
				var ny = py + dy
				if nx >= 0 and nx < 64 and ny >= 0 and ny < 64:
					img.set_pixel(nx, ny, dark_grass)
	
	img.save_png("res://assets/tiles/grass.png")
	print("  ✅ grass.png")

# ── 地形 tile（墙体/石头）────────────────────────────────
func _generate_wall_tile() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var stone = Color(0.35, 0.32, 0.28)
	var light = Color(0.42, 0.38, 0.33)
	var highlight = Color(0.5, 0.47, 0.42)
	
	img.fill(stone)
	
	# 石头纹理（内框）
	for py in range(8, 56):
		for px in range(8, 56):
			img.set_pixel(px, py, light)
	
	# 高光（上边）
	for px in range(8, 56):
		img.set_pixel(px, 8, highlight)
		img.set_pixel(px, 9, highlight)
	
	img.save_png("res://assets/tiles/wall.png")
	print("  ✅ wall.png")

# ── 地形 tile（道路）────────────────────────────────────
func _generate_road_tile() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var road = Color(0.55, 0.42, 0.28)
	var dark = Color(0.5, 0.38, 0.25)
	
	img.fill(road)
	
	# 道路纹理（横向条纹）
	for py in range(0, 64, 8):
		for px in range(64):
			img.set_pixel(px, py, dark)
			img.set_pixel(px, py + 1, dark)
	
	img.save_png("res://assets/tiles/road.png")
	print("  ✅ road.png")

func _ready() -> void:
	# 只在素材不存在时生成
	if not FileAccess.file_exists("res://assets/sprites/player.png"):
		generate_all_assets()
	else:
		print("✅ 素材已存在，跳过生成")
