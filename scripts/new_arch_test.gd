extends Node

func _ready() -> void:
	print("=== New Architecture Test ===")
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
	await get_tree().create_timer(2.5).timeout

	var world = get_tree().current_scene
	var player = world.get_node_or_null("Player")
	if not player:
		print("ERROR: No player"); get_tree().quit(); return

	# Test 1: Open loot spot
	var loot_spots = get_tree().get_nodes_in_group("loot_spot")
	print("Loot spots: %d" % loot_spots.size())
	if loot_spots.size() > 0:
		loot_spots[0].interact(player)
		await get_tree().create_timer(3.5).timeout

		var loot_ui = world.get_node_or_null("LootUI")
		if loot_ui and loot_ui.visible:
			print("=== Test 1: Loot UI Open ===")
			# Check loot grid has items
			var box_items = loot_ui.loot_box_items
			print("Box items: %d" % box_items.size())
			# Check player grid is empty
			print("Player items: %d" % GameData.placed_items.size())

			# Test 2: Double-click pick
			print("=== Test 2: Double-click pick ===")
			# Find first pickable slot
			var picked = false
			for slot in loot_ui.loot_slot_nodes:
				if is_instance_valid(slot) and slot.get_meta("pickable", false):
					var item = slot.get_meta("box_item", null)
					if item:
						var before_count = GameData.placed_items.size()
						# Manually call pick
						var placement = GameData.find_placement(item["item_id"])
						if placement["found"]:
							loot_ui._pick_item(item, slot, placement["row"], placement["col"])
							await get_tree().process_frame
							var after_count = GameData.placed_items.size()
							print("Pick: before=%d after=%d %s" % [
								before_count, after_count,
								"OK" if after_count > before_count else "FAIL"])
							picked = true
						break
				if picked: break

			# Test 3: Double-click return
			if picked:
				await get_tree().create_timer(0.5).timeout
				print("=== Test 3: Double-click return ===")
				var return_count = GameData.placed_items.size()
				# Find first player slot
				for slot in loot_ui.player_item_slots:
					if is_instance_valid(slot) and slot.get_meta("returnable", false):
						var placed = slot.get_meta("placed_item", null)
						if placed:
							# Manually call return (row=0, col=0)
							loot_ui._return_item(placed, 0, 0)
							await get_tree().process_frame
							var after_return = GameData.placed_items.size()
							var box_after = loot_ui.loot_box_items.size()
							print("Return: player before=%d after=%d box=%d %s" % [
								return_count, after_return, box_after,
								"OK" if after_return < return_count and box_after > 0 else "FAIL"])
						break

			# Test 4: Check label centering
			print("=== Test 4: Label centering ===")
			for slot in loot_ui.loot_slot_nodes:
				if is_instance_valid(slot) and slot.get_meta("pickable", false):
					for child in slot.get_children():
						if child is Label:
							var item = slot.get_meta("box_item", {})
							var item_id = item.get("item_id", 1)
							var shape_key = item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
							var cells = GameData.get_shape_cells(shape_key, false)
							var max_r = 0; var max_c = 0
							for cell in cells:
								max_r = maxi(max_r, cell[0] + 1)
								max_c = maxi(max_c, cell[1] + 1)
							print("Shape=%s max_r=%d max_c=%d lbl.size=%s lbl.custom_min=%s lbl.valign=%s" % [
								shape_key, max_r, max_c,
								str(child.size), str(child.custom_minimum_size),
								["TOP","CENTER","BOTTOM"][child.vertical_alignment]])
						break
					break
		else:
			print("ERROR: LootUI not visible")

	print("=== Test Complete ===")
	get_tree().quit()
