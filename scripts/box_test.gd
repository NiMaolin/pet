extends Node

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _find_label_in(node: Node) -> Label:
	if node is Label: return node as Label
	for ch in node.get_children():
		var found = _find_label_in(ch)
		if found: return found
	return null

func _run() -> void:
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
	await get_tree().create_timer(2.5).timeout

	var world = get_tree().current_scene
	var player = world.get_node_or_null("Player")
	if player:
		GameData.player_health = 9999
		GameData.player_max_health = 9999

	var loot_spots = get_tree().get_nodes_in_group("loot_spot")
	if loot_spots.size() > 0:
		loot_spots[0].interact(player)
		await get_tree().create_timer(10.0).timeout
		var loot_ui = world.get_node_or_null("LootUI")
		if loot_ui and loot_ui.visible:
			print("=== LABEL CENTERING TEST ===")
			for slot in loot_ui.loot_slot_nodes:
				if not is_instance_valid(slot): continue
				if not slot.get_meta("pickable", false): continue
				var item = slot.get_meta("box_item", {})
				var item_id = item.get("item_id", 1)
				var name = ItemDB.get_item_name(item_id)
				var sk = item.get("shape_key", "1x1")
				var cells = GameData.get_shape_cells(sk, false)
				var max_r = 0; var max_c = 0
				for cell in cells:
					max_r = max(max_r, cell[0]+1)
					max_c = max(max_c, cell[1]+1)
				var lbl = _find_label_in(slot)
				var slot_size = slot.custom_minimum_size
				var lbl_pos = Vector2(-1, -1)
				var lbl_size = Vector2(-1, -1)
				if lbl:
					# Get label global position, convert to slot local
					var global_pos = lbl.get_global_position()
					lbl_pos = global_pos - slot.get_global_position()
					lbl_size = lbl.size
					# Check centering
					var expected_lbl_w = max_c * 40 - 4
					var expected_lbl_h = max_r * 40 - 4
					# Horizontal center: label center should be at (slot_w / 2)
					var lbl_center_x = lbl_pos.x + lbl_size.x / 2
					var slot_center_x = slot_size.x / 2
					var h_offset = lbl_center_x - slot_center_x
					# Vertical center: label center should be at (slot_h / 2)
					var lbl_center_y = lbl_pos.y + lbl_size.y / 2
					var slot_center_y = slot_size.y / 2
					var v_offset = lbl_center_y - slot_center_y
					var h_ok = absf(h_offset) < 5
					var v_ok = absf(v_offset) < 5
					print("ITEM: %-10s shape=%-4s max_r=%d max_c=%d slot=%s lbl_pos=%s lbl_size=%s h_off=%.1f v_off=%.1f h=%s v=%s" % [
						name, sk, max_r, max_c, str(slot_size), str(lbl_pos), str(lbl_size),
						h_offset, v_offset,
						"OK" if h_ok else "FAIL", "OK" if v_ok else "FAIL"])
				else:
					print("ITEM: %-10s shape=%-4s max_r=%d max_c=%d slot=%s LABEL: not found" % [
						name, sk, max_r, max_c, str(slot_size)])
			print("=== DONE ===")
	print("=== Done ===")
	get_tree().quit()
