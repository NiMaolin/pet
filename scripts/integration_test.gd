extends Node

func _ready():
	push_warning("INTEG_TEST: Start")
	GameData.player_health = 9999
	GameData.clear_inventory()
	call_deferred("_run")

func _run():
	await get_tree().create_timer(0.5)
	
	push_warning("INTEG_TEST: 1 Load world")
	var ws = load("res://scenes/world/game_world.tscn")
	var world = ws.instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0)
	push_warning("INTEG_TEST: World=" + world.name)
	
	push_warning("INTEG_TEST: 2 Find loot")
	var spots = get_tree().get_nodes_in_group("loot_spot")
	push_warning("INTEG_TEST: Spots=" + str(spots.size()))
	
	if spots.size() == 0:
		push_warning("INTEG_TEST: FAIL no spots")
		done(false)
		return
	
	var spot = spots[0]
	spot._ensure_generated()
	push_warning("INTEG_TEST: Loot=" + str(spot.loot_items.size()))
	
	push_warning("INTEG_TEST: 3 Open UI")
	world.open_loot_ui(spot.loot_items, spot)
	await get_tree().create_timer(1.0)
	
	var lui = world.get_node_or_null("LootUI")
	if not lui or not lui.visible:
		push_warning("INTEG_TEST: FAIL no UI")
		done(false)
		return
	
	push_warning("INTEG_TEST: 3 OK")
	push_warning("INTEG_TEST: 4 Wait")
	await get_tree().create_timer(10.0)
	push_warning("INTEG_TEST: L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	push_warning("INTEG_TEST: 5 Click")
	var bb = GameData.placed_items.size()
	if lui.loot_slot_nodes.size() > 0:
		var sl = lui.loot_slot_nodes[0]
		if is_instance_valid(sl):
			var p = sl.get_global_rect().get_center()
			push_warning("INTEG_TEST: Pos=" + str(p))
			_send_click(lui, p)
			await get_tree().create_timer(0.1)
			_send_click(lui, p, true)
			await get_tree().create_timer(0.5)
			push_warning("INTEG_TEST: After L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	if GameData.placed_items.size() > bb:
		push_warning("INTEG_TEST: PASS item picked")
	else:
		push_warning("INTEG_TEST: DONE check result")
	
	done(true)

func _send_click(ui: CanvasLayer, pos: Vector2, dbl: bool = false):
	var dn = InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = pos
	dn.double_click = dbl
	ui._input(dn)
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	ui._input(up)

func done(ok: bool):
	push_warning("INTEG_TEST: RESULT=" + ("PASS" if ok else "FAIL"))
	get_tree().quit()
