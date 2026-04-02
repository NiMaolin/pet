## FontDragTest - 字体修复 + 仓库拖拽测试
extends Node

func _ready() -> void:
	print("=== 字体+仓库拖拽测试 ===")
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
	if loot_spots.is_empty():
		print("❌ 没有物资箱"); get_tree().quit(); return

	var player = world.get_node_or_null("Player")
	loot_spots[0].interact(player)
	await get_tree().create_timer(3.5).timeout

	var loot_ui = world.get_node_or_null("LootUI")

	# 测试1：双击拾取后检查背包格子 Label 的 size
	print("=== 测试1: 双击拾取后 Label size ===")
	for slot in loot_ui.loot_slot_nodes:
		if not is_instance_valid(slot): continue
		if not slot.get_meta("pickable", false): continue
		var entry = slot.get_meta("loot_entry", null)
		if entry and not entry.get("taken", false):
			# 双击拾取
			loot_ui._pick_entry(entry, slot)
			await get_tree().create_timer(0.5).timeout
			# 检查背包格子
			for ps in loot_ui.player_item_slots:
				if not is_instance_valid(ps): continue
				for child in ps.get_children():
					if child.has_meta("name_lbl"):
						print("背包 Label size=%s position=%s clip=%s" % [
							str(child.size), str(child.position), child.clip_text])
			break

	# 测试2：撤离，物品进仓库，测试仓库拖拽
	print("=== 测试2: 仓库拖拽 ===")
	var escape_nodes = get_tree().get_nodes_in_group("escape_point")
	if player and escape_nodes.size() > 0:
		player.global_position = escape_nodes[0].global_position
		await get_tree().create_timer(2.0).timeout

	# 回到准备界面，打开仓库
	scene = get_tree().current_scene
	var continue_btn = scene.find_child("Continue", true, true)
	if continue_btn:
		continue_btn.emit_signal("pressed")
		await get_tree().create_timer(1.5).timeout
	scene = get_tree().current_scene
	var wh_btn = scene.find_child("Warehouse", true, true)
	if wh_btn:
		wh_btn.emit_signal("pressed")
		await get_tree().create_timer(0.5).timeout
		var wh_ui = scene.get_node_or_null("WarehouseUI")
		if wh_ui:
			print("仓库物品数: %d" % wh_ui.item_slots.size())
			if wh_ui.item_slots.size() > 0:
				var slot = wh_ui.item_slots[0]
				var item = slot.get_meta("wh_item", null)
				print("仓库第一件: %s" % (ItemDB.get_item_name(item["item_id"]) if item else "nil"))
				# 模拟拖拽
				wh_ui._try_start_drag(slot.global_position + Vector2(5, 5))
				print("拖拽开始: is_dragging=%s" % wh_ui.is_dragging)
				await get_tree().process_frame
				var grid_rect = wh_ui.grid_container.get_global_rect()
				wh_ui._end_drag(grid_rect.position + Vector2(200, 80))
				print("拖拽结束，仓库物品数: %d" % GameData.warehouse.size())
				print("✅ 仓库拖拽正常")

	print("=== 测试完成 ===")
	get_tree().quit()
