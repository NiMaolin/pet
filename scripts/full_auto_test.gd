## FullAutoTest - 全自动测试（自动加载单例版）
extends Node

var step: int = 0
var timer: float = 0.0

func _ready() -> void:
	print("=== 全自动测试单例已加载 ===")
	# 等待所有自动加载完成
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_start_test()

func _start_test() -> void:
	print("📍 等待主菜单加载...")
	await get_tree().create_timer(2.0).timeout
	
	# 步骤2: 点击新游戏
	print("\n📍 步骤2: 点击新游戏")
	var main_menu = get_tree().current_scene
	if main_menu and main_menu.has_method("_on_new_game_pressed"):
		main_menu._on_new_game_pressed()
	else:
		print("  ❌ 找不到方法")
		return
	await get_tree().create_timer(2.0).timeout
	
	# 步骤3: 点击开始游戏
	print("📍 步骤3: 点击开始游戏")
	var prep = get_tree().current_scene
	print("  当前场景: %s" % prep.name if prep else "null")
	if prep and prep.has_method("_on_prepare_pressed"):
		prep._on_prepare_pressed()
	else:
		print("  ❌ 找不到方法")
		return
	await get_tree().create_timer(2.0).timeout
	
	# 步骤4: 选择地图
	print("📍 步骤4: 选择地图")
	var map_select = get_tree().current_scene
	print("  当前场景: %s" % map_select.name if map_select else "null")
	if map_select and map_select.has_method("_on_start_pressed"):
		map_select._on_start_pressed()
	else:
		print("  ❌ 找不到方法")
		return
	await get_tree().create_timer(4.0).timeout
	
	# 步骤5: 分析游戏世界
	print("\n" + "=".repeat(50))
	print("📍 步骤5: 分析游戏世界")
	print("=".repeat(50))
	
	var world = get_tree().current_scene
	if not world:
		print("❌ current_scene 为空!")
		return
	
	print("场景: %s" % world.name)
	print("场景文件: %s" % world.scene_file_path)
	
	# 列出所有子节点
	print("\n所有子节点:")
	for child in world.get_children():
		print("  - %s (%s)" % [child.name, child.get_class()])
	
	# 检查玩家
	var player = world.get_node_or_null("Player")
	if player:
		print("\n✅ 玩家位置: %s" % player.global_position)
	else:
		print("\n❌ 玩家未找到")
	
	# 检查物资箱
	var interactables = get_tree().get_nodes_in_group("interactable")
	print("\n物资箱数量: %d" % interactables.size())
	for i in interactables:
		print("  - %s @ %s" % [i.name, i.global_position])
	
	# 检查敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("\n敌人数量: %d" % enemies.size())
	for i in enemies:
		print("  - %s @ %s" % [i.name, i.global_position])
	
	# 检查地图绘制节点
	var map_node = world.get("map_draw_node")
	if map_node:
		print("\n✅ map_draw_node 存在")
	else:
		print("\n❌ map_draw_node 不存在")
	
	# 检查相机
	var cameras = world.find_children("*", "Camera2D")
	print("\n相机数量: %d" % cameras.size())
	
	# 截图
	print("\n📸 正在截图...")
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	var screenshot_path = "user://screenshot_auto.png"
	img.save_png(screenshot_path)
	
	# 复制到项目目录
	var abs_path = ProjectSettings.globalize_path(screenshot_path)
	var dest_path = "D:\\youxi\\soudache\\screenshot_auto.png"
	var dir = DirAccess.open("res://")
	if dir:
		dir.copy(abs_path, dest_path)
		print("✅ 截图已保存: %s" % dest_path)
		
		# 输出图片信息
		var file = FileAccess.open(dest_path, FileAccess.READ)
		if file:
			var file_size = file.get_length()
			print("  文件大小: %d 字节" % file_size)
	
	print("\n" + "=".repeat(50))
	print("✅ 测试完成")
	print("=".repeat(50))