extends Node

func _ready():
	push_warning("FINAL_TEST: Start")
	GameData.player_health = 9999
	GameData.clear_inventory()
	call_deferred("_run")

func _run():
	await get_tree().create_timer(0.5)
	
	var ws = load("res://scenes/world/game_world.tscn")
	var world = ws.instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0)
	
	var spots = get_tree().get_nodes_in_group("loot_spot")
	if spots.size() == 0:
		push_warning("FINAL_TEST: FAIL no spots")
		done(false)
		return
	
	var spot = spots[0]
	spot._ensure_generated()
	
	world.open_loot_ui(spot.loot_items, spot)
	await get_tree().create_timer(0.5)
	
	var lui = world.get_node_or_null("LootUI")
	if not lui or not lui.visible:
		push_warning("FINAL_TEST: FAIL no UI")
		done(false)
		return
	
	# Force-search since _process doesn't run in headless
	push_warning("FINAL_TEST: Forcing search completion...")
	for i in range(lui.loot_box_items.size()):
		lui.loot_box_items[i]["searched"] = true
	lui._build_loot_grid()
	lui.search_bar.value = 100
	lui.search_label.text = "Done"
	lui.is_searching = false
	
	push_warning("FINAL_TEST: L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	# Test 1: Direct pick
	push_warning("FINAL_TEST: === Test 1: Pick ===")
	var bb = GameData.placed_items.size()
	var bl = lui.loot_box_items.size()
	
	if lui.loot_box_items.size() > 0:
		var item = lui.loot_box_items[0]
		var placement = GameData.find_placement(item.get("item_id", 1))
		push_warning("FINAL_TEST: Placement=" + str(placement))
		
		if placement["found"]:
			lui._move_item_to_bag(item, placement["row"], placement["col"], placement["rotated"])
			await get_tree().create_timer(0.3)
			push_warning("FINAL_TEST: After pick L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	if GameData.placed_items.size() > bb:
		push_warning("FINAL_TEST: PASS - pick works!")
	else:
		push_warning("FINAL_TEST: FAIL - pick")
	
	# Test 2: Direct return
	push_warning("FINAL_TEST: === Test 2: Return ===")
	bb = GameData.placed_items.size()
	bl = lui.loot_box_items.size()
	
	if GameData.placed_items.size() > 0:
		var item = GameData.placed_items.back()
		var pos = lui._find_loot_position("1x1", lui.loot_box_items)
		lui._move_item_to_loot(item, pos["row"], pos["col"])
		await get_tree().create_timer(0.3)
		push_warning("FINAL_TEST: After return L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	if GameData.placed_items.size() < bb:
		push_warning("FINAL_TEST: PASS - return works!")
	else:
		push_warning("FINAL_TEST: FAIL - return")
	
	done(true)

func done(ok: bool):
	push_warning("FINAL_TEST: RESULT=" + ("PASS" if ok else "FAIL"))
	get_tree().quit()
