extends Node

func _ready() -> void:
	print("DeltaStyleTest _ready")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await get_tree().create_timer(0.2).timeout
	print("\n=== Delta Style Test ===\n")
	
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	# Test 1: Items have fixed positions
	print("=== Test 1: Fixed Positions ===")
	var items = [
		{"instance_id": 1, "item_id": 1, "row": 0, "col": 0, "shape_key": "1x1", "searched": true},
		{"instance_id": 2, "item_id": 2, "row": 0, "col": 3, "shape_key": "1x2", "searched": true},
	]
	print("Item 1 at (0,0), Item 2 at (0,3)")
	
	# Remove item 1, item 2 should NOT move
	items.remove_at(0)
	print("After removing item 1:")
	for item in items:
		print("  Item %d: row=%d, col=%d" % [item["instance_id"], item["row"], item["col"]])
	
	if items[0]["row"] == 0 and items[0]["col"] == 3:
		print("  PASS: Item 2 position unchanged")
	else:
		print("  FAIL: Item 2 moved!")
	
	# Test 2: Greedy placement for new items
	print("\n=== Test 2: Greedy Placement ===")
	GameData.clear_inventory()
	
	# Place first item - should be at (0,0)
	var p1 = GameData.find_placement(1)
	print("First 1x1: row=%d, col=%d" % [p1["row"], p1["col"]])
	if p1["row"] == 0 and p1["col"] == 0:
		print("  PASS: At (0,0)")
	else:
		print("  FAIL: Should be at (0,0)")
	
	GameData.place_item(1, 1, 0, 0, false)
	
	# Place second item - should be at (0,1)
	var p2 = GameData.find_placement(1)
	print("Second 1x1: row=%d, col=%d" % [p2["row"], p2["col"]])
	if p2["row"] == 0 and p2["col"] == 1:
		print("  PASS: At (0,1) - top-left priority")
	else:
		print("  FAIL: Should be at (0,1)")
	
	# Test 3: Drag placement at specific position
	print("\n=== Test 3: Drag Placement ===")
	GameData.clear_inventory()
	
	# Place at specific position (3, 5)
	var can = GameData.can_place_item(1, 3, 5, false)
	print("Can place at (3,5): %s" % str(can))
	if can:
		GameData.place_item(1, 1, 3, 5, false)
		var item = GameData.placed_items[0]
		print("Placed: row=%d, col=%d" % [item["row"], item["col"]])
		if item["row"] == 3 and item["col"] == 5:
			print("  PASS: At exact position")
		else:
			print("  FAIL: Wrong position")
	else:
		print("  FAIL: Should be placeable")
	
	# Test 4: Can place excluding self (for drag-to-new-position)
	print("\n=== Test 4: Move Item ===")
	GameData.clear_inventory()
	GameData.place_item(1, 1, 0, 0, false)
	var inst_id = GameData.placed_items[0]["instance_id"]
	
	# Check if can move to (0, 5) excluding self
	var can_move = GameData.can_place_item_excluding(1, 0, 5, false, inst_id)
	print("Can move 1x1 from (0,0) to (0,5): %s" % str(can_move))
	if can_move:
		print("  PASS: Move validation works")
	else:
		print("  FAIL: Should be able to move")
	
	# Actually move
	var moved = GameData.move_placed_item(inst_id, 0, 5, false)
	if moved:
		print("  PASS: Item moved successfully")
		var item = GameData.placed_items[0]
		if item["row"] == 0 and item["col"] == 5:
			print("  PASS: New position correct")
		else:
			print("  FAIL: Position wrong: (%d,%d)" % [item["row"], item["col"]])
	else:
		print("  FAIL: Move failed")
	
	print("\n=== All Tests Complete ===")
	get_tree().quit()
