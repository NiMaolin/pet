## DoubleClickTest - 双击拾取+放回真实测试
extends Node

var test_log: String = ""

func _ready() -> void:
	print("=== 双击拾取真实测试 ===")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_run_test()

func _run_test() -> void:
	await get_tree().create_timer(1.0).timeout
	var main_menu = get_tree().current_scene
	var new_game_btn = main_menu.find_child("NewGame", true, true)
	if new_game_btn: new_game_btn.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout

	var prep = get_tree().current_scene
	var prepare_btn = prep.find_child("Prepare", true, true)
	if prepare_btn: prepare_btn.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout

	var map_select = get_tree().current_scene
	var start_btn = map_select.find_child("Start", true, true)
	if start_btn: start_btn.emit_signal("pressed")
	await get_tree().create_timer(2.0).timeout

	var world = get_tree().current_scene
	test_log += "场景: %s\n" % world.name

	# 找物资箱并交互
	var interactables = get_tree().get_nodes_in_group("interactable")
	test_log += "物资箱数量: %d\n" % interactables.size()
	if interactables.size() == 0:
		test_log += "❌ 没有物资箱\n"
		_finish()
		return

	var spot = interactables[0]
	var player = world.get_node_or_null("Player")
	if player:
		player.global_position = spot.global_position + Vector2(50, 0)
	await get_tree().create_timer(0.3).timeout
	if spot.has_method("interact"):
		spot.call("interact", player)

	# 等待搜索完成
	await get_tree().create_timer(5.0).timeout

	var loot_ui = world.get_node_or_null("LootUI")
	if not loot_ui:
		test_log += "❌ 找不到 LootUI\n"
		_finish()
		return

	test_log += "LootUI 可见: %s\n" % loot_ui.visible
	var loot_slot_nodes = loot_ui.get("loot_slot_nodes")
	test_log += "物资箱格子数: %d\n" % loot_slot_nodes.size()

	# 检查格子尺寸（多格物品应该 > 40px）
	for i in range(loot_slot_nodes.size()):
		var slot = loot_slot_nodes[i]
		if is_instance_valid(slot):
			var entry = loot_ui.get("loot_entries")[i]
			var shape = ItemDB.get_item(entry["item_id"]).get("shape", "1x1")
			var rect = slot.get_global_rect()
			test_log += "  格子[%d] %s shape=%s size=%s\n" % [i, ItemDB.get_item_name(entry["item_id"]), shape, rect.size]

	# 双击拾取第一个格子
	if loot_slot_nodes.size() > 0:
		var slot = loot_slot_nodes[0]
		if is_instance_valid(slot) and slot.get_meta("pickable", false):
			var ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.double_click = true
			ev.position = slot.get_global_rect().get_center()
			loot_ui._input(ev)
			await get_tree().create_timer(0.5).timeout
			test_log += "拾取后背包物品数: %d\n" % GameData.placed_items.size()

			# 截图1：拾取后
			var img = get_viewport().get_texture().get_image()
			img.save_png("D:\\youxi\\soudache\\test_pick.png")
			test_log += "✅ 截图1已保存 (拾取后)\n"

			# 双击放回
			await get_tree().create_timer(0.3).timeout
			var player_slots = loot_ui.get("player_item_slots")
			test_log += "背包格子数: %d\n" % player_slots.size()
			if player_slots.size() > 0:
				var ps = player_slots[0]
				if is_instance_valid(ps):
					var ps_shape = ItemDB.get_item(ps.get_meta("placed_item")["item_id"]).get("shape","1x1")
					test_log += "  背包格子[0] shape=%s size=%s\n" % [ps_shape, ps.get_global_rect().size]
					var ev2 = InputEventMouseButton.new()
					ev2.button_index = MOUSE_BUTTON_LEFT
					ev2.pressed = true
					ev2.double_click = true
					ev2.position = ps.get_global_rect().get_center()
					loot_ui._input(ev2)
					await get_tree().create_timer(0.5).timeout
					test_log += "放回后背包物品数: %d\n" % GameData.placed_items.size()

					# 检查放回后物资箱格子尺寸
					var new_slots = loot_ui.get("loot_slot_nodes")
					test_log += "放回后物资箱格子数: %d\n" % new_slots.size()
					for i in range(new_slots.size()):
						var ns = new_slots[i]
						if is_instance_valid(ns):
							var ne = loot_ui.get("loot_entries")[i]
							var nshape = ItemDB.get_item(ne["item_id"]).get("shape", "1x1")
							test_log += "  放回格子[%d] shape=%s size=%s\n" % [i, nshape, ns.get_global_rect().size]

					# 截图2：放回后
					var img2 = get_viewport().get_texture().get_image()
					img2.save_png("D:\\youxi\\soudache\\test_return.png")
					test_log += "✅ 截图2已保存 (放回后)\n"

	_finish()

func _finish() -> void:
	var file = FileAccess.open("D:\\youxi\\soudache\\pick_return_report.txt", FileAccess.WRITE)
	file.store_string(test_log)
	file.close()
	print("\n=== 测试完成 ===")
	print(test_log)
	get_tree().quit()
