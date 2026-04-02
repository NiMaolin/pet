## FixTest - 验证三项修复
extends Node

func _ready() -> void:
	print("=== 修复验证测试 ===")
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	# 进入游戏世界
	var scene = get_tree().current_scene
	var btn = scene.find_child("NewGame", true, true)
	if btn: btn.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout
	scene = get_tree().current_scene
	var prepare = scene.find_child("Prepare", true, true)
	if prepare: prepare.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout
	scene = get_tree().current_scene
	var start = scene.find_child("Start", true, true)
	if start: start.emit_signal("pressed")
	await get_tree().create_timer(2.0).timeout

	var world = get_tree().current_scene
	var loot_spots = get_tree().get_nodes_in_group("loot_spot")
	if loot_spots.is_empty():
		print("❌ 没有物资箱"); get_tree().quit(); return

	var player = world.get_node_or_null("Player")
	loot_spots[0].interact(player)
	await get_tree().create_timer(3.5).timeout  # 等搜索

	var loot_ui = world.get_node_or_null("LootUI")
	print("=== 测试1: 拖拽自由放置 ===")
	var dragged = false
	for slot in loot_ui.loot_slot_nodes:
		if not is_instance_valid(slot): continue
		if not slot.get_meta("pickable", false): continue
		var entry = slot.get_meta("loot_entry", null)
		if entry and not entry.get("taken", false):
			# 拖拽到背包第3行第5列
			loot_ui._start_drag(entry, "loot", slot.global_position, slot.global_position)
			await get_tree().process_frame
			var player_rect = loot_ui.player_grid_container.get_global_rect()
			# 目标：第3行第5列
			var drop_pos = player_rect.position + Vector2(5 * 40 + 5, 3 * 40 + 5)
			loot_ui._end_drag(drop_pos)
			await get_tree().create_timer(0.3).timeout
			if GameData.placed_items.size() > 0:
				var pi = GameData.placed_items[0]
				print("✅ 放置位置: row=%d col=%d (目标row=3 col=5)" % [pi["row"], pi["col"]])
			else:
				print("❌ 拖拽放置失败")
			dragged = true
			break
	if not dragged:
		print("⚠️ 没有可拖拽物品")

	print("=== 测试2: 单格字体（reveal后）===")
	# 检查物资箱格子的 name_lbl
	for slot in loot_ui.loot_slot_nodes:
		if not is_instance_valid(slot): continue
		if not slot.get_meta("pickable", false): continue
		for child in slot.get_children():
			if child.has_meta("name_lbl"):
				var fs = child.get_theme_font_size("font_size")
				var clip = child.clip_text
				print("name_lbl font_size=%d clip_text=%s autowrap=%d" % [fs, clip, child.autowrap_mode])
				break
		break

	print("=== 测试3: 仓库独立物品 ===")
	# 撤离，物品进仓库
	var escape_nodes = get_tree().get_nodes_in_group("escape_point")
	if player and escape_nodes.size() > 0:
		player.global_position = escape_nodes[0].global_position
		await get_tree().create_timer(2.0).timeout
		print("撤离后场景: %s" % get_tree().current_scene.name)
		print("仓库物品数: %d" % GameData.warehouse.size())
		print("仓库类型: %s" % typeof(GameData.warehouse))
		if GameData.warehouse.size() > 0:
			print("仓库第一件: %s" % str(GameData.warehouse[0]))

	var f = FileAccess.open("D:\\youxi\\soudache\\fix_report.txt", FileAccess.WRITE)
	f.store_string("修复验证完成\n")
	f.close()
	print("=== 测试完成 ===")
	get_tree().quit()
