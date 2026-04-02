## PreviewTest - 预览+精确放置测试
extends Node

func _ready() -> void:
	print("=== 预览拖拽测试 ===")
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
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
	if loot_spots.is_empty(): print("❌ 没有物资箱"); get_tree().quit(); return
	var player = world.get_node_or_null("Player")
	loot_spots[0].interact(player)
	await get_tree().create_timer(3.5).timeout

	var loot_ui = world.get_node_or_null("LootUI")
	print("=== 测试1: 拖拽精确放置（空位=成功）===")
	for slot in loot_ui.loot_slot_nodes:
		if not is_instance_valid(slot): continue
		if not slot.get_meta("pickable", false): continue
		var entry = slot.get_meta("loot_entry", null)
		if entry and not entry.get("taken", false):
			loot_ui._start_drag(entry, "loot", slot.global_position, slot.global_position)
			await get_tree().process_frame
			# 模拟移动到背包空位
			var player_rect = loot_ui.player_grid_container.get_global_rect()
			var target = player_rect.position + Vector2(20, 20)
			loot_ui._update_preview(target)
			print("预览节点存在: %s" % (loot_ui.preview_node != null))
			loot_ui._end_drag(target)
			await get_tree().create_timer(0.3).timeout
			print("放置后背包数: %d" % GameData.placed_items.size())
			break

	print("=== 测试2: 拖拽到已占用位置（应失败）===")
	if GameData.placed_items.size() > 0:
		for slot in loot_ui.loot_slot_nodes:
			if not is_instance_valid(slot): continue
			if not slot.get_meta("pickable", false): continue
			var entry = slot.get_meta("loot_entry", null)
			if entry and not entry.get("taken", false):
				loot_ui._start_drag(entry, "loot", slot.global_position, slot.global_position)
				await get_tree().process_frame
				# 拖到已有物品的位置
				var existing = loot_ui.player_item_slots[0]
				var occupied_pos = existing.global_position + Vector2(5, 5)
				loot_ui._update_preview(occupied_pos)
				print("预览节点存在: %s" % (loot_ui.preview_node != null))
				loot_ui._end_drag(occupied_pos)
				await get_tree().create_timer(0.3).timeout
				print("放置失败后背包数（应不变）: %d" % GameData.placed_items.size())
				break

	print("=== 测试3: 背包内拖拽移动 ===")
	if GameData.placed_items.size() > 0:
		var item = GameData.placed_items[0]
		print("原位置: row=%d col=%d" % [item["row"], item["col"]])
		for slot in loot_ui.player_item_slots:
			if not is_instance_valid(slot): continue
			if slot.get_meta("placed_item", null) == item:
				loot_ui._start_drag(item, "player", slot.global_position, slot.global_position)
				await get_tree().process_frame
				var player_rect = loot_ui.player_grid_container.get_global_rect()
				var new_pos = player_rect.position + Vector2(5 * 40 + 5, 4 * 40 + 5)
				loot_ui._end_drag(new_pos)
				await get_tree().create_timer(0.3).timeout
				if GameData.placed_items.size() > 0:
					var moved = GameData.placed_items[0]
					print("新位置: row=%d col=%d" % [moved["row"], moved["col"]])
				break

	print("=== 测试完成 ===")
	get_tree().quit()
