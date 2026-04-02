extends Node

func _ready() -> void:
	print("=== Simple Real Click Test ===")
	call_deferred("_run")

func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	
	# Force load main menu directly
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(0.5).timeout
	
	var main = get_tree().current_scene
	print("Main menu: %s" % main.name if main else "null")
	
	if not main:
		print("FAIL: Could not load main menu")
		get_tree().quit()
		return
	
	# Find StartGame button
	var start_btn = main.find_child("StartGame", true, false) as Button
	if start_btn:
		print("Found StartGame button, clicking...")
		start_btn.pressed.emit()
		await get_tree().create_timer(1.5).timeout
	
	var scene = get_tree().current_scene
	print("Current scene: %s" % scene.name if scene else "null")
	
	# Check if we reached prep screen
	var prep = scene
	var enter_btn = prep.find_child("EnterGame", true, false) as Button
	if enter_btn:
		print("Found EnterGame button, clicking...")
		enter_btn.pressed.emit()
		await get_tree().create_timer(1.0).timeout
	
	scene = get_tree().current_scene
	print("Current scene: %s" % scene.name if scene else "null")
	
	# Check if we reached map selection
	var map_btn = scene.find_child("StartGame", true, false) as Button
	if map_btn:
		print("Found Map StartGame button, clicking...")
		map_btn.pressed.emit()
		await get_tree().create_timer(2.0).timeout
	
	scene = get_tree().current_scene
	print("Current scene: %s" % scene.name if scene else "null")
	
	if scene and scene.name == "GameWorld":
		# Find loot spot
		var spots = get_tree().get_nodes_in_group("loot_spot")
		print("Loot spots: %d" % spots.size())
		
		if spots.size() > 0:
			var spot = spots[0]
			spot._ensure_generated()
			print("Spot items: %d" % spot.loot_items.size())
			
			# Open loot UI
			var world = scene
			if world.has_method("open_loot_ui"):
				world.open_loot_ui(spot.loot_items, spot)
				await get_tree().create_timer(1.0).timeout
				
				var loot_ui = world.get_node_or_null("LootUI")
				if loot_ui and loot_ui.visible:
					print("Loot UI opened!")
					print("Box items: %d" % loot_ui.loot_box_items.size())
					
					# Wait for search
					await get_tree().create_timer(8.0).timeout
					
					print("After wait - Box: %d, Bag: %d" % [loot_ui.loot_box_items.size(), GameData.placed_items.size()])
					
					# Test double-click
					if loot_ui.loot_slot_nodes.size() > 0:
						var slot = loot_ui.loot_slot_nodes[0]
						var pos = slot.get_global_rect().get_center()
						print("Testing double-click at %s" % str(pos))
						
						# Press
						var ev1 = InputEventMouseButton.new()
						ev1.button_index = MOUSE_BUTTON_LEFT
						ev1.pressed = true
						ev1.position = pos
						loot_ui._input(ev1)
						await get_tree().create_timer(0.05).timeout
						# Release
						var ev2 = InputEventMouseButton.new()
						ev2.button_index = MOUSE_BUTTON_LEFT
						ev2.pressed = false
						ev2.position = pos
						loot_ui._input(ev2)
						await get_tree().create_timer(0.05).timeout
						# Double press
						var ev3 = InputEventMouseButton.new()
						ev3.button_index = MOUSE_BUTTON_LEFT
						ev3.pressed = true
						ev3.position = pos
						ev3.double_click = true
						loot_ui._input(ev3)
						await get_tree().create_timer(0.05).timeout
						# Release
						var ev4 = InputEventMouseButton.new()
						ev4.button_index = MOUSE_BUTTON_LEFT
						ev4.pressed = false
						ev4.position = pos
						loot_ui._input(ev4)
						await get_tree().create_timer(0.5).timeout
						
						print("After double-click: Box: %d, Bag: %d" % [loot_ui.loot_box_items.size(), GameData.placed_items.size()])
	
	print("\n=== Test Complete ===")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()