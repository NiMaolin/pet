extends Node

# Integration test for drag/drop between loot box and bag

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_run_tests()

func _run_tests() -> void:
	print("\n=== Requirement 51 Integration Test ===\n")
	
	# Setup
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	# Load world scene directly
	var world = preload("res://scenes/world/game_world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(1.0).timeout
	
	print("World loaded: %s" % world.name)
	
	# Find loot spots
	var spots = get_tree().get_nodes_in_group("loot_spot")
	print("Loot spots found: %d" % spots.size())
	
	if spots.is_empty():
		print("FAIL: No loot spots")
		get_tree().quit()
		return
	
	var spot = spots[0]
	print("Testing with spot: %s (level %d)" % [spot.name, spot.loot_level])
	
	# Open loot UI
	spot._ensure_generated()
	print("Spot items: %d" % spot.loot_items.size())
	
	if spot.loot_items.is_empty():
		print("FAIL: No items in spot")
		get_tree().quit()
		return
	
	# Simulate opening loot UI
	world.open_loot_ui(spot.loot_items, spot)
	await get_tree().create_timer(0.5).timeout
	
	var loot_ui = world.get_node_or_null("LootUI")
	if not loot_ui or not loot_ui.visible:
		print("FAIL: Loot UI not visible")
		get_tree().quit()
		return
	
	print("PASS: Loot UI opened")
	
	# Get initial state
	var box_count = loot_ui.loot_box_items.size()
	var bag_count = GameData.placed_items.size()
	print("Initial - Box: %d, Bag: %d" % [box_count, bag_count])
	
	# Test pick item (loot box -> bag)
	print("\n=== Test Pick Item ===")
	if box_count > 0:
		var first_item = loot_ui.loot_box_items[0]
		var item_id = first_item["item_id"]
		var item_name = ItemDB.get_item_name(item_id)
		print("Picking: %s" % item_name)
		
		# Find slot and placement
		var slot = loot_ui._find_loot_slot(first_item)
		var placement = GameData.find_placement(item_id)
		
		if placement["found"]:
			loot_ui._pick_item(first_item, slot, placement["row"], placement["col"])
			await get_tree().create_timer(0.3).timeout
			
			var new_box = loot_ui.loot_box_items.size()
			var new_bag = GameData.placed_items.size()
			print("After pick - Box: %d, Bag: %d" % [new_box, new_bag])
			
			if new_bag == bag_count + 1 and new_box == box_count - 1:
				print("PASS: Item picked to bag")
			else:
				print("FAIL: Pick failed")
		else:
			print("SKIP: No space in bag")
	
	# Test return item (bag -> loot box)
	print("\n=== Test Return Item ===")
	if GameData.placed_items.size() > 0:
		var placed = GameData.placed_items.back()
		var item_id = placed["item_id"]
		print("Returning: %s" % ItemDB.get_item_name(item_id))
		
		loot_ui._return_item(placed, 0, 0)
		await get_tree().create_timer(0.3).timeout
		
		var after_box = loot_ui.loot_box_items.size()
		var after_bag = GameData.placed_items.size()
		print("After return - Box: %d, Bag: %d" % [after_box, after_bag])
		
		if after_bag == bag_count and after_box == box_count:
			print("PASS: Item returned to box")
		else:
			print("FAIL: Return failed")
	else:
		print("SKIP: No items in bag to return")
	
	# Test label centering
	print("\n=== Test Label Centering ===")
	_check_label_centering(loot_ui)
	
	# Close and cleanup
	loot_ui._on_close()
	await get_tree().create_timer(0.3).timeout
	
	print("\n=== Integration Test Complete ===")
	get_tree().quit()

func _check_label_centering(loot_ui: CanvasLayer) -> void:
	# Check player bag labels
	for slot in loot_ui.player_item_slots:
		if not is_instance_valid(slot):
			continue
		_check_slot_label(slot, "bag")
	
	# Check loot box labels
	for slot in loot_ui.loot_slot_nodes:
		if not is_instance_valid(slot):
			continue
		_check_slot_label(slot, "loot")

func _check_slot_label(slot: Control, source: String) -> void:
	var item_data = slot.get_meta("placed_item" if source == "bag" else "box_item", null)
	if not item_data:
		return
	
	var item_id = item_data["item_id"]
	var name = ItemDB.get_item_name(item_id)
	var shape_key = item_data.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
	var cells = GameData.get_shape_cells(shape_key, item_data.get("rotated", false))
	
	var max_r = 0
	var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	
	var expected_size = Vector2(max_c * 40 - 4, max_r * 40 - 4)
	var slot_size = slot.custom_minimum_size
	
	# Find label
	for child in slot.get_children():
		if child is MarginContainer:
			for mc in child.get_children():
				if mc is Label:
					var lbl = mc as Label
					var lbl_size = lbl.size
					print("Item %-12s: slot=%.0fx%.0f lbl=%.0fx%.0f expected=%.0fx%.0f" % [
						name, slot_size.x, slot_size.y, lbl_size.x, lbl_size.y,
						expected_size.x, expected_size.y
					])
					if abs(lbl_size.x - expected_size.x) < 1 and abs(lbl_size.y - expected_size.y) < 1:
						print("  -> PASS: Label size correct")
					else:
						print("  -> FAIL: Label size mismatch")
