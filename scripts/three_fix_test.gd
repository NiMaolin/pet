## ThreeFixTest - 字体/生成/血量测试
extends Node

func _ready() -> void:
	print("=== 三项修复测试 ===")
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
	print("=== 测试1: 怪物不在墙里 ===")
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("敌人数量: %d" % enemies.size())
	for e in enemies:
		# 反算 tile 坐标
		var col = int((e.global_position.x) / 64)
		var row = int((e.global_position.y - 300) / 64)
		var tile = world._get_tile_type(col, row)
		var safe = tile != 1 and tile != 6  # 非墙非建筑
		print("敌人 pos=%s col=%d row=%d tile=%d %s" % [
			str(e.global_position), col, row, tile, "✅" if safe else "❌ 在墙里"])

	print("=== 测试2: 血量扣减+HUD更新 ===")
	var player = world.get_node_or_null("Player")
	var hp_before = GameData.player_health
	print("初始血量: %d" % hp_before)
	player.take_damage(10)
	await get_tree().process_frame
	var hp_after = GameData.player_health
	print("受伤后血量: %d (应减少)" % hp_after)
	var hud_text = world.health_label.text
	print("HUD显示: %s" % hud_text)
	if hp_after < hp_before:
		print("✅ 血量扣减正常")
	else:
		print("❌ 血量未扣减")
	if str(hp_after) in hud_text:
		print("✅ HUD同步正常")
	else:
		print("❌ HUD未同步")

	print("=== 测试3: 字体居中（多格物品）===")
	var loot_spots = get_tree().get_nodes_in_group("loot_spot")
	if loot_spots.size() > 0:
		loot_spots[0].interact(player)
		await get_tree().create_timer(3.5).timeout
		var loot_ui = world.get_node_or_null("LootUI")
		for slot in loot_ui.loot_slot_nodes:
			if not is_instance_valid(slot): continue
			if not slot.get_meta("pickable", false): continue
			for child in slot.get_children():
				if child.has_meta("name_lbl"):
					var item_id = slot.get_meta("loot_entry")["item_id"]
					var shape = ItemDB.get_item(item_id).get("shape", "1x1")
					print("物品=%s shape=%s lbl.size=%s lbl.custom_min=%s" % [
						ItemDB.get_item_name(item_id), shape,
						str(child.size), str(child.custom_minimum_size)])
			break

	print("=== 测试完成 ===")
	get_tree().quit()
