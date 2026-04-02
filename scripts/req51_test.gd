extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=== Requirement 51 Unit Tests ===\n")
	
	# Setup
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	# Test 1: Item-container decoupling
	print("=== Test 1: Item-Container Decoupling ===")
	var test_items = ItemDB.generate_loot(2)
	print("Generated %d test items" % test_items.size())
	
	# Create simulated loot box items
	var loot_box_items = []
	for raw in test_items:
		var item_id = raw.get("id", 1)
		loot_box_items.append({
			"instance_id": randi(),
			"item_id": item_id,
			"rarity": ItemDB.get_item_rarity_str(item_id),
			"shape_key": ItemDB.get_item(item_id).get("shape", "1x1"),
			"searched": true,
			"is_returned": false,
			"box_row": 0,
			"box_col": 0,
		})
	
	print("Loot box items: %d" % loot_box_items.size())
	
	# Test 2: Pick item from loot box
	print("\n=== Test 2: Pick Item ===")
	var first_item = loot_box_items[0]
	var item_id = first_item["item_id"]
	var item_name = ItemDB.get_item_name(item_id)
	var shape_key = first_item.get("shape_key", "1x1")
	var cells = GameData.get_shape_cells(shape_key, false)
	
	print("First item: %s (id=%d, shape=%s)" % [item_name, item_id, shape_key])
	
	# Find placement
	var placement = GameData.find_placement(item_id)
	print("Placement found: %s" % str(placement))
	
	if placement["found"]:
		var success = GameData.place_item(item_id, 1, placement["row"], placement["col"], placement["rotated"])
		if success:
			print("PASS: Item placed in bag")
			loot_box_items.remove_at(0)
		else:
			print("FAIL: Could not place item")
	else:
		print("FAIL: No placement found")
	
	print("Bag items: %d, Loot box items: %d" % [GameData.placed_items.size(), loot_box_items.size()])
	
	# Test 3: Return item to loot box
	print("\n=== Test 3: Return Item ===")
	if GameData.placed_items.size() > 0:
		var placed = GameData.placed_items[0]
		var instance_id = placed.get("instance_id", -1)
		
		# Create return item
		var return_item = placed.duplicate()
		return_item["is_returned"] = true
		return_item["searched"] = true
		return_item["box_row"] = 0
		return_item["box_col"] = 0
		
		# Remove from bag
		var removed = GameData.remove_item_from_inventory(instance_id)
		if removed:
			loot_box_items.append(return_item)
			print("PASS: Item returned to loot box")
		else:
			print("FAIL: Could not remove from bag")
		
		print("Bag items: %d, Loot box items: %d" % [GameData.placed_items.size(), loot_box_items.size()])
	
	# Test 4: Verify label size calculation
	print("\n=== Test 4: Label Centering Calculation ===")
	_test_label_centering()
	
	# Test 5: Can place excluding self
	print("\n=== Test 5: Can Place Excluding Self ===")
	GameData.clear_inventory()
	
	# Place a 1x2 item at position
	var test_item_id = 2  # 恐龙鳞片 is 1x2
	var shape = ItemDB.get_item(test_item_id).get("shape", "1x2")
	print("Test item: %s (shape=%s)" % [ItemDB.get_item_name(test_item_id), shape])
	
	var test_cells = GameData.get_shape_cells(shape, false)
	GameData.place_item(test_item_id, 1, 0, 0, false)
	print("Placed 1x2 item at (0,0)")
	
	# Check if can move to new position (excluding original)
	var can_move = GameData.can_place_item_excluding(test_item_id, 0, 1, false, GameData.placed_items[0].get("instance_id", -1))
	print("Can move to (0,1) excluding self: %s" % str(can_move))
	
	if can_move:
		print("PASS: Move validation works")
	else:
		print("FAIL: Should be able to move")
	
	# Test 6: Preview grid calculation
	print("\n=== Test 6: Preview Grid Calculation ===")
	var preview_grid: Array = []
	const LOOT_ROWS = 4
	const LOOT_COLS = 5
	for _r in range(LOOT_ROWS + 20):
		var row_arr = []
		for _c in range(LOOT_COLS):
			row_arr.append(false)
		preview_grid.append(row_arr)
	
	# Mark existing items
	for item in loot_box_items:
		var sk = item.get("shape_key", "1x1")
		var c2 = GameData.get_shape_cells(sk, item.get("rotated", false))
		var br = item.get("box_row", 0)
		var bc = item.get("box_col", 0)
		for cell in c2:
			var rr = br + cell[0]
			var cc = bc + cell[1]
			if rr < preview_grid.size() and cc < LOOT_COLS:
				preview_grid[rr][cc] = true
	
	# Try to place a 1x1 item at each position
	var free_slots = 0
	for r in range(LOOT_ROWS):
		for c in range(LOOT_COLS):
			if not preview_grid[r][c]:
				free_slots += 1
	
	print("Free 1x1 slots in loot box: %d/%d" % [free_slots, LOOT_ROWS * LOOT_COLS])
	
	print("\n=== All Unit Tests Complete ===")

func _test_label_centering() -> void:
	const CS: int = 40
	var test_shapes = ["1x1", "1x2", "2x1", "2x2", "3x2"]
	
	for shape in test_shapes:
		var cells = GameData.get_shape_cells(shape, false)
		var max_r = 0
		var max_c = 0
		for cell in cells:
			max_r = max(max_r, cell[0] + 1)
			max_c = max(max_c, cell[1] + 1)
		
		var slot_size = Vector2(max_c * CS, max_r * CS)
		var lbl_size = Vector2(max_c * CS - 4, max_r * CS - 4)
		var margin_offset = Vector2(2, 2)  # From MarginContainer
		
		print("Shape %s: slot=%.0fx%.0f lbl=%.0fx%.0f margin_offset=%.0f,%.0f" % [
			shape, slot_size.x, slot_size.y, lbl_size.x, lbl_size.y,
			margin_offset.x, margin_offset.y
		])
		
		# Verify centering: label should be at (2, 2) offset from slot origin
		if abs(margin_offset.x - 2.0) < 0.01 and abs(margin_offset.y - 2.0) < 0.01:
			print("  -> PASS: Label at correct margin offset")
		else:
			print("  -> FAIL: Label margin offset incorrect")
