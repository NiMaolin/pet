extends SceneTree

func _ready():
	print("=== 双击拾取真实测试 ===")
	await get_tree().create_timer(0.5).timeout
	
	# 进入游戏
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(1.0).timeout
	
	# 新游戏
	var main_menu = get_tree().current_scene
	if main_menu.has_method("_on_new_game_pressed"):
		main_menu._on_new_game_pressed()
	await get_tree().create_timer(1.0).timeout
	
	# 准备界面 → 地图选择 → 游戏
	var prep = get_tree().current_scene
	if prep.has_method("_on_start_pressed"):
		prep._on_start_pressed()
	await get_tree().create_timer(1.0).timeout
	
	var map_select = get_tree().current_scene
	if map_select.has_method("_on_map_selected"):
		map_select._on_map_selected(0)
	await get_tree().create_timer(2.0).timeout
	
	# 现在在游戏世界
	var world = get_tree().current_scene
	var loot_ui = world.get_node("LootUI")
	var player = world.get_node("Player")
	
	# 找第一个物资箱
	var loot_spots = get_tree().get_nodes_in_group("interactable")
	if loot_spots.size() > 0:
		var spot = loot_spots[0]
		print("📦 打开物资箱...")
		spot.interact(player)
		await get_tree().create_timer(0.5).timeout
		
		# 等搜索完成
		await get_tree().create_timer(3.0).timeout
		
		# 获取第一个格子
		var slot = loot_ui.loot_slot_nodes[0]
		print("  slot 节点: %s" % slot)
		print("  mouse_filter: %d (应为0=STOP)" % slot.mouse_filter)
		print("  entry.searched: %s" % loot_ui.loot_entries[0]["searched"])
		
		# 模拟双击事件
		print("📍 模拟双击...")
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.double_click = true
		ev.position = slot.get_global_rect().get_center()
		
		# 发送事件到 slot
		slot.gui_input.emit(ev)
		await get_tree().create_timer(0.5).timeout
		
		print("  拾取后 entry.taken: %s (应为true)" % loot_ui.loot_entries[0]["taken"])
		print("  背包物品数: %d (应为1)" % GameData.placed_items.size())
	
	quit()
