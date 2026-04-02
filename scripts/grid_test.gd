extends Node

const CS: int = 40

func _ready() -> void:
	print("GridTest _ready called")
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("GridTest _run_tests starting")
	await get_tree().create_timer(0.2).timeout
	print("\n=== GridContainerUI Unified Test ===\n")
	
	# Test 1: Label centering calculation
	print("=== Test 1: Label Centering ===")
	_test_label_centering()
	
	# Test 2: Auto placement (top-left priority)
	print("\n=== Test 2: Auto Placement ===")
	_test_auto_placement()
	
	# Test 3: Can place excluding self
	print("\n=== Test 3: Can Place Excluding Self ===")
	_test_can_place_excluding()
	
	# Test 4: Move item
	print("\n=== Test 4: Move Item ===")
	_test_move_item()
	
	print("\n=== All Tests Complete ===")
	get_tree().quit()

func _test_label_centering() -> void:
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
		var margin_offset = Vector2(2, 2)
		
		print("Shape %s: slot=%.0fx%.0f lbl=%.0fx%.0f margin=%.0f,%.0f" % [
			shape, slot_size.x, slot_size.y, lbl_size.x, lbl_size.y,
			margin_offset.x, margin_offset.y
		])
		
		if abs(margin_offset.x - 2.0) < 0.01 and abs(margin_offset.y - 2.0) < 0.01:
			print("  -> PASS: Margin offset correct")
		else:
			print("  -> FAIL: Margin offset wrong")

func _test_auto_placement() -> void:
	# Clear and test
	GameData.clear_inventory()
	
	# Place first item at (0,0)
	var p1 = GameData.find_placement(1)  # 远古骨头 1x1
	print("Placement for 1x1: %s" % str(p1))
	if p1["found"] and p1["row"] == 0 and p1["col"] == 0:
		print("  -> PASS: First 1x1 at (0,0)")
	else:
		print("  -> FAIL: Should be at (0,0)")
	
	GameData.place_item(1, 1, 0, 0, false)
	
	# Place second item - should be at (0,1) for 1x1
	var p2 = GameData.find_placement(1)
	print("Second 1x1 placement: %s" % str(p2))
	if p2["found"] and p2["row"] == 0 and p2["col"] == 1:
		print("  -> PASS: Second 1x1 at (0,1)")
	else:
		print("  -> FAIL: Should be at (0,1)")
	
	# Place a 1x2 item
	var p3 = GameData.find_placement(2)  # 恐龙鳞片 1x2
	print("1x2 placement: %s" % str(p3))
	if p3["found"] and p3["row"] == 0:
		print("  -> PASS: 1x2 on row 0")
	else:
		print("  -> FAIL: Should be on row 0")
	
	# Fill row 0 and check row 1
	GameData.clear_inventory()
	for c in range(10):
		GameData.place_item(1, 1, 0, c, false)
	
	var p4 = GameData.find_placement(1)
	print("When row 0 full: %s" % str(p4))
	if p4["found"] and p4["row"] == 1 and p4["col"] == 0:
		print("  -> PASS: Goes to next row")
	else:
		print("  -> FAIL: Should be at (1,0)")

func _test_can_place_excluding() -> void:
	GameData.clear_inventory()
	
	# Place a 1x2 at (0,0)
	GameData.place_item(2, 1, 0, 0, false)  # 恐龙鳞片
	var inst_id = GameData.placed_items[0]["instance_id"]
	
	# Check if can place at (0,0) excluding self
	var can = GameData.can_place_item_excluding(2, 0, 0, false, inst_id)
	print("Can move 1x2 to same position: %s" % str(can))
	if can:
		print("  -> PASS: Excluding self works")
	else:
		print("  -> FAIL: Should allow same position")
	
	# Check if can place at (0,1) (overlaps)
	var can2 = GameData.can_place_item_excluding(2, 0, 1, false, inst_id)
	print("Can move 1x2 to (0,1): %s" % str(can2))
	if can2:
		print("  -> PASS: Can slide right")
	else:
		print("  -> FAIL: Should be able to slide")

func _test_move_item() -> void:
	GameData.clear_inventory()
	
	# Place and move
	GameData.place_item(1, 1, 0, 0, false)
	var inst_id = GameData.placed_items[0]["instance_id"]
	
	# Move to new position
	var moved = GameData.move_placed_item(inst_id, 2, 3, false)
	print("Move 1x1 from (0,0) to (2,3): %s" % str(moved))
	if moved:
		var item = GameData.placed_items[0]
		if item["row"] == 2 and item["col"] == 3:
			print("  -> PASS: Item moved correctly")
		else:
			print("  -> FAIL: Position wrong: (%d,%d)" % [item["row"], item["col"]])
	else:
		print("  -> FAIL: Move failed")
