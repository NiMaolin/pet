extends CanvasLayer

signal closed

const CELL_SIZE: int = 40
const BAG_COLS: int = 10
const BAG_ROWS: int = 6
const LOOT_COLS: int = 6
const LOOT_ROWS: int = 4
const SEARCH_TIME: Dictionary = {"common": 0.8, "uncommon": 1.5, "rare": 3.0, "epic": 5.0, "legendary": 8.0}

var current_spot: Node = null
var loot_box_items: Array = []
var is_searching: bool = false
var search_elapsed: float = 0.0
var search_finish_time: float = 0.0
var search_index: int = 0
var loot_slot_nodes: Array = []
var player_item_slots: Array = []

var is_dragging: bool = false
var drag_item: Dictionary = {}
var drag_source: String = ""
var drag_ghost: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_rotated: bool = false
var drag_instance_id: int = -1
var preview_node: Control = null

var player_grid: Control
var search_bar: ProgressBar
var search_label: Label
var close_btn: Button
var loot_title: Label
var loot_grid: Control

func _ready() -> void:
	print("LOOT_UI: _ready called")
	
	player_grid = $Panel/MarginContainer/VBox/HBox/PlayerSide/GridArea
	search_bar = $Panel/MarginContainer/VBox/SearchBar
	search_label = $Panel/MarginContainer/VBox/SearchLabel
	close_btn = $Panel/MarginContainer/VBox/TitleRow/CloseBtn
	loot_title = $Panel/MarginContainer/VBox/HBox/LootSide/LootTitle
	loot_grid = $Panel/MarginContainer/VBox/HBox/LootSide/ScrollContainer/GridArea
	
	print("LOOT_UI: nodes assigned")
	
	close_btn.pressed.connect(_on_close)
	GameData.inventory_changed.connect(_refresh_player)
	
	print("LOOT_UI: ready done, is_processing=", is_processing())

func _process(delta: float) -> void:
	print("LOOT_UI: _process called, is_searching=", is_searching, " visible=", visible)
	if not is_searching:
		return
	if not visible:
		return
	
	search_elapsed += delta
	search_bar.value = clampf((search_elapsed / search_finish_time) * 100.0, 0.0, 100.0)
	
	if search_elapsed >= search_finish_time:
		is_searching = false
		search_bar.value = 0.0
		_reveal_item(search_index)
		search_index += 1
		_start_search_next()

func open_loot(box_items: Array, spot: Node) -> void:
	print("LOOT_UI: open_loot called")
	current_spot = spot
	loot_box_items = []
	
	for i in range(box_items.size()):
		var raw = box_items[i]
		var item_id = raw.get("item_id", raw.get("id", 1))
		var shape_key = raw.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
		var item = {
			"instance_id": raw.get("instance_id", randi()),
			"item_id": item_id,
			"row": raw.get("row", -1),
			"col": raw.get("col", -1),
			"shape_key": shape_key,
			"searched": raw.get("searched", false),
			"rarity": raw.get("rarity", ItemDB.get_item_rarity_str(item_id)),
		}
		if item["row"] < 0:
			var pos = _find_loot_position(item["shape_key"], loot_box_items)
			item["row"] = pos["row"]
			item["col"] = pos["col"]
		loot_box_items.append(item)
	
	visible = true
	_build_loot_grid()
	_refresh_player()
	_update_title()
	
	search_index = 0
	is_searching = false
	var any_not_searched = loot_box_items.any(func(e): return not e.get("searched", false))
	if any_not_searched:
		search_bar.value = 0
		search_label.text = "Search..."
		_start_search_next()
	else:
		search_bar.value = 100
		search_label.text = "Done"
	
	print("LOOT_UI: open_loot done, is_searching=", is_searching, " visible=", visible)

func _start_search_next() -> void:
	print("LOOT_UI: _start_search_next, index=", search_index, " size=", loot_box_items.size())
	if search_index >= loot_box_items.size():
		_on_all_searched()
		return
	if loot_box_items[search_index].get("searched", false):
		search_index += 1
		_start_search_next()
		return
	
	var entry = loot_box_items[search_index]
	search_elapsed = 0.0
	search_finish_time = SEARCH_TIME.get(entry.get("rarity", "common"), 0.8)
	is_searching = true
	search_label.text = "Searching: %s..." % ItemDB.get_item_name(entry["item_id"])
	print("LOOT_UI: started search for ", entry.get("item_id"), " time=", search_finish_time)

func _reveal_item(idx: int) -> void:
	if idx >= loot_box_items.size():
		return
	loot_box_items[idx]["searched"] = true
	_build_loot_grid()

func _on_all_searched() -> void:
	is_searching = false
	search_bar.value = 100
	search_label.text = "Done"

func _build_loot_grid() -> void:
	loot_slot_nodes.clear()
	for c in loot_grid.get_children():
		c.queue_free()
	
	var max_row = LOOT_ROWS
	for item in loot_box_items:
		var cells = GameData.get_shape_cells(item["shape_key"], false)
		for cell in cells:
			max_row = max(max_row, item["row"] + cell[0] + 1)
	
	loot_grid.custom_minimum_size = Vector2(LOOT_COLS * CELL_SIZE, max_row * CELL_SIZE)
	
	for r in range(max_row):
		for c in range(LOOT_COLS):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15, 1)
			loot_grid.add_child(bg)
	
	for i in range(loot_box_items.size()):
		var item = loot_box_items[i]
		var slot = _make_loot_slot(item)
		loot_grid.add_child(slot)
		loot_slot_nodes.append(slot)

func _find_loot_position(shape_key: String, existing_items: Array) -> Dictionary:
	var cells = GameData.get_shape_cells(shape_key, false)
	var grid_used: Array = []
	for _r in range(LOOT_ROWS + 50):
		var row = []
		for _c in range(LOOT_COLS):
			row.append(false)
		grid_used.append(row)
	
	for item in existing_items:
		if item.get("row", -1) >= 0:
			var c2 = GameData.get_shape_cells(item["shape_key"], false)
			for cell in c2:
				var r = item["row"] + cell[0]
				var c = item["col"] + cell[1]
				if r < grid_used.size() and c < LOOT_COLS:
					grid_used[r][c] = true
	
	for r in range(LOOT_ROWS + 50):
		for c in range(LOOT_COLS):
			if _can_place_on_grid(grid_used, cells, r, c, LOOT_COLS):
				return {"row": r, "col": c}
	return {"row": 0, "col": 0}

func _can_place_on_grid(grid: Array, cells: Array, row: int, col: int, max_col: int) -> bool:
	for cell in cells:
		var r = row + cell[0]
		var c = col + cell[1]
		if r >= grid.size() or c >= max_col:
			return false
		if grid[r][c]:
			return false
	return true

func _make_loot_slot(item: Dictionary) -> Control:
	var item_id = item["item_id"]
	var shape_key = item["shape_key"]
	var cells = GameData.get_shape_cells(shape_key, false)
	var item_color = ItemDB.get_item_color(item_id)
	var rarity = item.get("rarity", "common")
	var searched = item.get("searched", false)
	
	var max_r = 0
	var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	
	var container = Control.new()
	container.position = Vector2(item["col"] * CELL_SIZE, item["row"] * CELL_SIZE)
	container.custom_minimum_size = Vector2(max_c * CELL_SIZE, max_r * CELL_SIZE)
	container.set_meta("loot_item", item)
	
	if not searched:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for cell in cells:
			var bg = ColorRect.new()
			bg.position = Vector2(cell[1] * CELL_SIZE + 1, cell[0] * CELL_SIZE + 1)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.15, 0.15, 0.2, 1)
			container.add_child(bg)
		var lbl = _make_label("?", max_r, max_c)
		lbl.get_child(0).add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		container.add_child(lbl)
		return container
	
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2(cell[1] * CELL_SIZE + 1, cell[0] * CELL_SIZE + 1)
		bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		bg.color = item_color.darkened(0.25)
		container.add_child(bg)
	
	_apply_border(container, cells, rarity)
	var lbl = _make_label(ItemDB.get_item_name(item_id), max_r, max_c)
	container.add_child(lbl)
	
	var dot = ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.position = Vector2(max_c * CELL_SIZE - 7, max_r * CELL_SIZE - 7)
	dot.color = _rarity_color(rarity)
	container.add_child(dot)
	
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.set_meta("pickable", true)
	return container

func _refresh_player() -> void:
	player_item_slots.clear()
	for c in player_grid.get_children():
		c.queue_free()
	
	for r in range(BAG_ROWS):
		for c in range(BAG_COLS):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15, 1)
			player_grid.add_child(bg)
	
	for item in GameData.placed_items:
		var slot = _make_player_slot(item)
		player_grid.add_child(slot)
		player_item_slots.append(slot)

func _make_player_slot(item: Dictionary) -> Control:
	var item_id = item["item_id"]
	var shape_key = item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
	var rotated = item.get("rotated", false)
	var cells = GameData.get_shape_cells(shape_key, rotated)
	var item_color = ItemDB.get_item_color(item_id)
	var rarity = ItemDB.get_item_rarity_str(item_id)
	
	var max_r = 0
	var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	
	var container = Control.new()
	container.position = Vector2(item["col"] * CELL_SIZE, item["row"] * CELL_SIZE)
	container.custom_minimum_size = Vector2(max_c * CELL_SIZE, max_r * CELL_SIZE)
	container.set_meta("bag_item", item)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2(cell[1] * CELL_SIZE + 1, cell[0] * CELL_SIZE + 1)
		bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		bg.color = item_color.darkened(0.25)
		container.add_child(bg)
	
	_apply_border(container, cells, rarity)
	var lbl = _make_label(ItemDB.get_item_name(item_id), max_r, max_c)
	container.add_child(lbl)
	
	var dot = ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.position = Vector2(max_c * CELL_SIZE - 7, max_r * CELL_SIZE - 7)
	dot.color = _rarity_color(rarity)
	container.add_child(dot)
	
	return container

func _try_double_click_pick(mouse_pos: Vector2) -> void:
	for i in range(loot_slot_nodes.size()):
		var slot = loot_slot_nodes[i]
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("loot_item", null)
			if not item or not item.get("searched", false):
				return
			var placement = GameData.find_placement(item["item_id"])
			if placement["found"]:
				_move_item_to_bag(item, placement["row"], placement["col"], placement["rotated"])
			else:
				print("Bag full!")
			return

func _try_double_click_return(mouse_pos: Vector2) -> bool:
	for slot in player_item_slots:
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("bag_item", null)
			if item:
				var placement = _find_loot_position(item.get("shape_key", "1x1"), loot_box_items)
				_move_item_to_loot(item, placement["row"], placement["col"])
				return true
	return false

func _move_item_to_bag(item: Dictionary, row: int, col: int, rotated: bool) -> void:
	var idx = loot_box_items.find(item)
	if idx == -1:
		return
	loot_box_items.remove_at(idx)
	if current_spot and current_spot.has_method("remove_item"):
		current_spot.remove_item(item["instance_id"])
	GameData.place_item(item["item_id"], 1, row, col, rotated)
	print("Pick: %s" % ItemDB.get_item_name(item["item_id"]))
	_build_loot_grid()
	_refresh_player()
	_update_title()

func _move_item_to_loot(item: Dictionary, row: int, col: int) -> void:
	var instance_id = item.get("instance_id", -1)
	if not GameData.remove_item_from_inventory(instance_id):
		return
	var new_item = {
		"instance_id": instance_id,
		"item_id": item["item_id"],
		"row": row,
		"col": col,
		"shape_key": item.get("shape_key", "1x1"),
		"searched": true,
		"rarity": item.get("rarity", "common"),
	}
	loot_box_items.append(new_item)
	if current_spot and current_spot.has_method("add_item"):
		current_spot.add_item(new_item.duplicate())
	print("Return: %s" % ItemDB.get_item_name(item["item_id"]))
	_build_loot_grid()
	_refresh_player()
	_update_title()

func _try_start_drag(mouse_pos: Vector2) -> void:
	for slot in player_item_slots:
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("bag_item", null)
			if item:
				_start_drag(item, "bag", mouse_pos, slot.global_position)
				return
	for slot in loot_slot_nodes:
		if not is_instance_valid(slot):
			continue
		if not slot.get_meta("pickable", false):
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("loot_item", null)
			if item and item.get("searched", false):
				_start_drag(item, "loot", mouse_pos, slot.global_position)
				return

func _start_drag(item: Dictionary, source: String, mouse_pos: Vector2, slot_pos: Vector2) -> void:
	is_dragging = true
	drag_item = item.duplicate()
	drag_source = source
	drag_offset = slot_pos - mouse_pos
	drag_rotated = item.get("rotated", false)
	drag_instance_id = item.get("instance_id", -1)
	
	if drag_ghost:
		drag_ghost.queue_free()
	drag_ghost = _make_ghost(item)
	add_child(drag_ghost)
	drag_ghost.position = mouse_pos + drag_offset
	drag_ghost.z_index = 100
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if source == "bag":
		for slot in player_item_slots:
			if is_instance_valid(slot) and slot.get_meta("bag_item", {}).get("instance_id", -1) == drag_instance_id:
				slot.modulate = Color(1, 1, 1, 0.3)
				break
	else:
		for slot in loot_slot_nodes:
			if is_instance_valid(slot) and slot.get_meta("loot_item", {}).get("instance_id", -1) == drag_instance_id:
				slot.modulate = Color(1, 1, 1, 0.3)
				break

func _make_ghost(item: Dictionary) -> Control:
	var item_id = item["item_id"]
	var shape_key = item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
	var cells = GameData.get_shape_cells(shape_key, drag_rotated)
	var max_r = 0
	var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	
	var ghost = Control.new()
	ghost.custom_minimum_size = Vector2(max_c * CELL_SIZE, max_r * CELL_SIZE)
	ghost.modulate = Color(1, 1, 1, 0.75)
	
	var item_color = ItemDB.get_item_color(item_id)
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2(cell[1] * CELL_SIZE + 1, cell[0] * CELL_SIZE + 1)
		bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		bg.color = item_color
		ghost.add_child(bg)
	
	var lbl = _make_label(ItemDB.get_item_name(item_id), max_r, max_c)
	ghost.add_child(lbl)
	return ghost

func _update_preview(mouse_pos: Vector2) -> void:
	if preview_node:
		preview_node.queue_free()
		preview_node = null
	
	var player_rect = player_grid.get_global_rect()
	var loot_rect = loot_grid.get_global_rect()
	
	if player_rect.has_point(mouse_pos) and drag_source == "loot":
		_show_preview_at(player_rect, mouse_pos, "bag")
	elif loot_rect.has_point(mouse_pos) and drag_source == "bag":
		_show_preview_at(loot_rect, mouse_pos, "loot")

func _show_preview_at(container_rect: Rect2, mouse_pos: Vector2, target: String) -> void:
	var local = mouse_pos - container_rect.position
	var max_c = BAG_COLS if target == "bag" else LOOT_COLS
	var max_r = BAG_ROWS if target == "bag" else (LOOT_ROWS + 50)
	var col = clampi(int(local.x / CELL_SIZE), 0, max_c - 1)
	var row = clampi(int(local.y / CELL_SIZE), 0, max_r - 1)
	
	var shape_key = drag_item.get("shape_key", ItemDB.get_item(drag_item["item_id"]).get("shape", "1x1"))
	var cells = GameData.get_shape_cells(shape_key, drag_rotated)
	var can: bool
	
	if target == "bag":
		can = GameData.can_place_item_excluding(drag_item["item_id"], row, col, drag_rotated, drag_instance_id)
	else:
		can = _can_place_in_loot(row, col, cells, drag_instance_id)
	
	var color = Color(0.2, 1.0, 0.3, 0.45) if can else Color(1.0, 0.2, 0.2, 0.45)
	
	preview_node = Control.new()
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.z_index = 50
	var parent = player_grid if target == "bag" else loot_grid
	parent.add_child(preview_node)
	
	for cell in cells:
		var r = row + cell[0]
		var c = col + cell[1]
		if r < 0 or r >= max_r or c < 0 or c >= max_c:
			continue
		var rect = ColorRect.new()
		rect.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
		rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
		rect.color = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_node.add_child(rect)

func _can_place_in_loot(row: int, col: int, cells: Array, exclude_id: int) -> bool:
	for item in loot_box_items:
		if item.get("instance_id", -1) == exclude_id:
			continue
		var c2 = GameData.get_shape_cells(item["shape_key"], false)
		for cell in c2:
			var r1 = item["row"] + cell[0]
			var c1 = item["col"] + cell[1]
			for cell2 in cells:
				var r2 = row + cell2[0]
				var c2_ = col + cell2[1]
				if r1 == r2 and c1 == c2_:
					return false
	return true

func _end_drag(mouse_pos: Vector2) -> void:
	_clear_preview()
	is_dragging = false
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	
	var player_rect = player_grid.get_global_rect()
	var loot_rect = loot_grid.get_global_rect()
	
	if player_rect.has_point(mouse_pos) and drag_source == "loot":
		var local = mouse_pos - player_rect.position
		var row = clampi(int(local.y / CELL_SIZE), 0, BAG_ROWS - 1)
		var col = clampi(int(local.x / CELL_SIZE), 0, BAG_COLS - 1)
		_move_item_to_bag(drag_item, row, col, drag_rotated)
	elif loot_rect.has_point(mouse_pos) and drag_source == "bag":
		var local = mouse_pos - loot_rect.position
		var row = clampi(int(local.y / CELL_SIZE), 0, LOOT_ROWS + 49)
		var col = clampi(int(local.x / CELL_SIZE), 0, LOOT_COLS - 1)
		_move_item_to_loot(drag_item, row, col)
	else:
		_refresh_player()
		_build_loot_grid()

func _cancel_drag() -> void:
	_clear_preview()
	is_dragging = false
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	_refresh_player()
	_build_loot_grid()

func _clear_preview() -> void:
	if preview_node:
		preview_node.queue_free()
		preview_node = null

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("interact"):
		_cancel_drag()
		_on_close()
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and is_dragging:
			drag_rotated = not drag_rotated
			if drag_ghost:
				drag_ghost.queue_free()
			drag_ghost = _make_ghost(drag_item)
			add_child(drag_ghost)
			drag_ghost.position = get_viewport().get_mouse_position() + drag_offset
			drag_ghost.z_index = 100
			drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					if is_dragging:
						_cancel_drag()
					else:
						if not _try_double_click_return(mb.position):
							_try_double_click_pick(mb.position)
				else:
					if not is_dragging:
						_try_start_drag(mb.position)
			else:
				if is_dragging:
					_end_drag(mb.position)
					get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if is_dragging:
				_cancel_drag()
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_dragging:
		if drag_ghost:
			drag_ghost.position = event.position + drag_offset
		_update_preview(event.position)
		get_viewport().set_input_as_handled()

func _make_label(text: String, max_r: int, max_c: int) -> Control:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	
	if max_r == 1 and max_c == 1:
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.clip_text = true
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var mc = MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 2)
	mc.add_theme_constant_override("margin_top", 2)
	mc.add_theme_constant_override("margin_right", 2)
	mc.add_theme_constant_override("margin_bottom", 2)
	mc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	lbl.custom_minimum_size = Vector2(max_c * CELL_SIZE - 4, max_r * CELL_SIZE - 4)
	lbl.set_deferred("size", Vector2(max_c * CELL_SIZE - 4, max_r * CELL_SIZE - 4))
	
	mc.add_child(lbl)
	return mc

func _apply_border(node: Control, cells: Array, rarity: String) -> void:
	var col = _rarity_color(rarity)
	var max_r = 0
	var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	var w = max_c * CELL_SIZE
	var h = max_r * CELL_SIZE
	for b in [
		[Vector2(0, 0), Vector2(w, 2)],
		[Vector2(0, h - 2), Vector2(w, 2)],
		[Vector2(0, 0), Vector2(2, h)],
		[Vector2(w - 2, 0), Vector2(2, h)]
	]:
		var line = ColorRect.new()
		line.position = b[0]
		line.size = b[1]
		line.color = col
		node.add_child(line)

func _update_title() -> void:
	loot_title.text = "Box (%d items)" % loot_box_items.size()

func _on_close() -> void:
	_cancel_drag()
	visible = false
	closed.emit()

func _rarity_color(r: String) -> Color:
	match r:
		"common":    return Color(0.55, 0.55, 0.55)
		"uncommon":  return Color(0.2, 0.8, 0.2)
		"rare":      return Color(0.2, 0.45, 1.0)
		"epic":      return Color(0.7, 0.2, 1.0)
		"legendary": return Color(1.0, 0.6, 0.0)
	return Color(0.55, 0.55, 0.55)
