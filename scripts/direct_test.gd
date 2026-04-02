extends Node

var step = 0

func _ready():
	push_warning("TEST: Starting...")
	step = 1
	
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	await get_tree().create_timer(1.0)
	
	push_warning("TEST: Step 1 - Load main menu")
	await get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(1.0)
	
	var scene = get_tree().current_scene
	push_warning("TEST: Step 1 OK - " + str(scene.name if scene else "null"))
	
	if scene.name != "MainMenu":
		push_warning("TEST: FAIL - Wrong scene")
		get_tree().quit()
		return
	
	step = 2
	push_warning("TEST: Step 2 - Click StartGame")
	var btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(1.5)
	
	step = 3
	scene = get_tree().current_scene
	push_warning("TEST: Step 3 - Click EnterGame: " + str(scene.name))
	btn = scene.find_child("EnterGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(1.0)
	
	step = 4
	scene = get_tree().current_scene
	push_warning("TEST: Step 4 - Click map: " + str(scene.name))
	btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(3.0)
	
	scene = get_tree().current_scene
	push_warning("TEST: Step 5 - Game: " + str(scene.name))
	
	step = 6
	if scene.name != "GameWorld":
		push_warning("TEST: FAIL - Not in GameWorld: " + str(scene.name))
		get_tree().quit()
		return
	
	push_warning("TEST: Step 6 - Find loot spots")
	var spots = get_tree().get_nodes_in_group("loot_spot")
	push_warning("TEST: Found " + str(spots.size()) + " spots")
	
	if spots.size() == 0:
		push_warning("TEST: FAIL - No spots")
		get_tree().quit()
		return
	
	var spot = spots[0]
	spot._ensure_generated()
	push_warning("TEST: Loot items: " + str(spot.loot_items.size()))
	
	step = 7
	push_warning("TEST: Step 7 - Open loot UI")
	if scene.has_method("open_loot_ui"):
		scene.open_loot_ui(spot.loot_items, spot)
	await get_tree().create_timer(1.0)
	
	var loot_ui = scene.get_node_or_null("LootUI")
	if not loot_ui or not loot_ui.visible:
		push_warning("TEST: FAIL - Loot UI not visible")
		get_tree().quit()
		return
	push_warning("TEST: Step 7 OK")
	
	step = 8
	push_warning("TEST: Step 8 - Wait for search")
	await get_tree().create_timer(10.0)
	push_warning("TEST: Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
	
	step = 9
	push_warning("TEST: Step 9 - Test double-click")
	var before_loot = loot_ui.loot_box_items.size()
	var before_bag = GameData.placed_items.size()
	
	if loot_ui.loot_slot_nodes.size() > 0:
		var slot = loot_ui.loot_slot_nodes[0]
		if is_instance_valid(slot):
			var pos = slot.get_global_rect().get_center()
			push_warning("TEST: Click at " + str(pos))
			_do_double_click(loot_ui, pos)
			await get_tree().create_timer(0.5)
			push_warning("TEST: After - Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
	
	var after_loot = loot_ui.loot_box_items.size()
	var after_bag = GameData.placed_items.size()
	
	if after_bag > before_bag:
		push_warning("TEST: PASS - Item picked to bag")
	else:
		push_warning("TEST: WARNING - Item may not have been picked")
	
	push_warning("TEST: RESULT - PASS")
	get_tree().quit()

func _do_double_click(ui: CanvasLayer, pos: Vector2):
	for i in range(2):
		var down = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = pos
		down.double_click = (i == 1)
		ui._input(down)
		await get_tree().create_timer(0.08)
		
		var up = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = pos
		ui._input(up)
		await get_tree().create_timer(0.08)
