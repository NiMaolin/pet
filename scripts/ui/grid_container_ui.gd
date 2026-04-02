## GridContainerUI - Unified grid container for bags, loot boxes, and warehouses
## All containers share the same logic, same class
extends CanvasLayer

class_name GridContainerUI

signal closed

const CELL_SIZE: int = 40

# Grid configuration (set by caller)
var grid_cols: int = 10
var grid_rows: int = 6
var max_rows: int = 100  # For scrolling containers

# Data
var items: Array = []  # [{instance_id, item_id, row, col, shape_key, rotated, ...}]
var grid: Array = []   # grid[row][col] = instance_id or 0

# Drag state
var is_dragging: bool = false
var drag_item: Dictionary = {}
var drag_ghost: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_rotated: bool = false
var preview_node: Control = null
var item_slots: Array = []

@onready var grid_area: Control = $Panel/MarginContainer/VBox/GridArea
@onready var close_btn: Button = $Panel/MarginContainer/VBox/TitleRow/CloseBtn

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close)

func _init_grid() -> void:
	grid = []
	for _r in range(max_rows):
		var row = []
		for _c in range(grid_cols):
			row.append(0)
		grid.append(row)

func open(items_data: Array, cols: int = 10, rows: int = 6) -> void:
	grid_cols = cols
	grid_rows = rows
	items = items_data.duplicate(true)
	_init_grid()
	_refresh()
	visible = true

func _refresh() -> void:
	item_slots.clear()
	_init_grid()
	
	for c in grid_area.get_children():
		c.queue_free()
	
	# Mark occupied cells
	for item in items:
		var shape_key = item.get("shape_key", _get_item_shape(item["item_id"]))
		var cells = GameData.get_shape_cells(shape_key, item.get("rotated", false))
		for cell in cells:
			var r = item["row"] + cell[0]
			var c = item["col"] + cell[1]
			if r < max_rows and c < grid_cols:
				grid[r][c] = item["instance_id"]
	
	# Calculate displayed rows
	var max_row = grid_rows
	for item in items:
		var shape_key = item.get("shape_key", _get_item_shape(item["item_id"]))
		var cells = GameData.get_shape_cells(shape_key, item.get("rotated", false))
		for cell in cells:
			max_row = max(max_row, item["row"] + cell[0] + 1)
	
	grid_area.custom_minimum_size = Vector2(grid_cols * CELL_SIZE, max_row * CELL_SIZE)
	
	# Draw background
	for r in range(max_row):
		for c in range(grid_cols):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15, 1)
			grid_area.add_child(bg)
	
	# Draw items
	for item in items:
		var slot = _make_item_slot(item)
		grid_area.add_child(slot)
		item_slots.append(slot)

func _get_item_shape(item_id: int) -> String:
	return ItemDB.get_item(item_id).get("shape", "1x1")

func _make_item_slot(item: Dictionary) -> Control:
	var item_id = item["item_id"]
	var shape_key = item.get("shape_key", _get_item_shape(item_id))
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
	container.set_meta("grid_item", item)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Background cells
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2(cell[1] * CELL_SIZE + 1, cell[0] * CELL_SIZE + 1)
		bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		bg.color = item_color.darkened(0.25)
		container.add_child(bg)
	
	# Border
	_apply_border(container, cells, rarity)
	
	# Label (centered via MarginContainer)
	var lbl_container = _make_label(ItemDB.get_item_name(item_id), max_r, max_c)
	container.add_child(lbl_container)
	
	# Rarity dot
	var dot = ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.position = Vector2(max_c * CELL_SIZE - 7, max_r * CELL_SIZE - 7)
	dot.color = _rarity_color(rarity)
	container.add_child(dot)
	
	return container

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

func _apply_border(container: Control, cells: Array, rarity: String) -> void:
	var col = _rarity_color(rarity)
	var max_r = 0
	var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	var w = max_c * CELL_SIZE
	var h = max_r * CELL_SIZE
	for b in [[Vector2(0,0),Vector2(w,2)],[Vector2(0,h-2),Vector2(w,2)],
			  [Vector2(0,0),Vector2(2,h)],[Vector2(w-2,0),Vector2(2,h)]]:
		var line = ColorRect.new()
		line.position = b[0]
		line.size = b[1]
		line.color = col
		container.add_child(line)

# ========== PLACEMENT LOGIC ==========

func _can_place_at(item_id: int, cells: Array, row: int, col: int, exclude_id: int = -1) -> bool:
	for cell in cells:
		var r = row + cell[0]
		var c = col + cell[1]
		if r < 0 or r >= max_rows or c < 0 or c >= grid_cols:
			return false
		if grid[r][c] != 0 and grid[r][c] != exclude_id:
			return false
	return true

func _find_auto_placement(item_id: int) -> Dictionary:
	var shape_key = _get_item_shape(item_id)
	for rotated in [false, true]:
		var cells = GameData.get_shape_cells(shape_key, rotated)
		for r in range(max_rows):
			for c in range(grid_cols):
				if _can_place_at(item_id, cells, r, c, -1):
					return {"found": true, "row": r, "col": c, "rotated": rotated}
	return {"found": false}

# ========== DOUBLE-CLICK: Auto placement (top-left priority) ==========

func _try_double_click(mouse_pos: Vector2) -> bool:
	for slot in item_slots:
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("grid_item", null)
			if item:
				# Find placement in target container
				var placement = _find_auto_placement(item["item_id"])
				if placement["found"]:
					# Move item
					_move_item(item, placement["row"], placement["col"], placement["rotated"])
					return true
				else:
					print("No space!")
				return true
	return false

func _move_item(item: Dictionary, new_row: int, new_col: int, new_rotated: bool) -> bool:
	var instance_id = item["instance_id"]
	var shape_key = item.get("shape_key", _get_item_shape(item["item_id"]))
	var new_cells = GameData.get_shape_cells(shape_key, new_rotated)
	
	# Check if can place (excluding self)
	if not _can_place_at(item["item_id"], new_cells, new_row, new_col, instance_id):
		return false
	
	# Clear old position
	var old_cells = GameData.get_shape_cells(shape_key, item.get("rotated", false))
	for cell in old_cells:
		var r = item["row"] + cell[0]
		var c = item["col"] + cell[1]
		if r < max_rows and c < grid_cols:
			grid[r][c] = 0
	
	# Mark new position
	for cell in new_cells:
		var r = new_row + cell[0]
		var c = new_col + cell[1]
		if r < max_rows and c < grid_cols:
			grid[r][c] = instance_id
	
	# Update item data
	var idx = items.find_custom(func(i): return i["instance_id"] == instance_id)
	if idx >= 0:
		items[idx]["row"] = new_row
		items[idx]["col"] = new_col
		items[idx]["rotated"] = new_rotated
	
	_refresh()
	return true

# ========== DRAG: Player-defined placement ==========

func _try_start_drag(mouse_pos: Vector2) -> void:
	for slot in item_slots:
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("grid_item", null)
			if item:
				_start_drag(item, slot, mouse_pos)
				return

func _start_drag(item: Dictionary, slot: Control, mouse_pos: Vector2) -> void:
	is_dragging = true
	drag_item = item.duplicate()
	drag_rotated = item.get("rotated", false)
	drag_offset = slot.global_position - mouse_pos
	
	# Clear from grid temporarily
	var shape_key = item.get("shape_key", _get_item_shape(item["item_id"]))
	var cells = GameData.get_shape_cells(shape_key, drag_rotated)
	for cell in cells:
		var r = item["row"] + cell[0]
		var c = item["col"] + cell[1]
		if r < max_rows and c < grid_cols:
			grid[r][c] = 0
	
	# Create ghost
	if drag_ghost:
		drag_ghost.queue_free()
	drag_ghost = _make_ghost(item)
	add_child(drag_ghost)
	drag_ghost.position = mouse_pos + drag_offset
	drag_ghost.z_index = 100
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	slot.modulate = Color(1, 1, 1, 0.2)

func _make_ghost(item: Dictionary) -> Control:
	var item_id = item["item_id"]
	var shape_key = item.get("shape_key", _get_item_shape(item_id))
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
	
	var grid_rect = grid_area.get_global_rect()
	if not grid_rect.has_point(mouse_pos):
		return
	
	var shape_key = drag_item.get("shape_key", _get_item_shape(drag_item["item_id"]))
	var cells = GameData.get_shape_cells(shape_key, drag_rotated)
	var local_pos = mouse_pos - grid_area.global_position
	var target_row = clampi(int(local_pos.y / CELL_SIZE), 0, max_rows - 1)
	var target_col = clampi(int(local_pos.x / CELL_SIZE), 0, grid_cols - 1)
	
	var can_place = _can_place_at(drag_item["item_id"], cells, target_row, target_col, drag_item["instance_id"])
	var preview_color = Color(0.2, 1.0, 0.3, 0.45) if can_place else Color(1.0, 0.2, 0.2, 0.45)
	
	preview_node = Control.new()
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.z_index = 50
	grid_area.add_child(preview_node)
	
	for cell in cells:
		var r = target_row + cell[0]
		var c = target_col + cell[1]
		if r < 0 or r >= max_rows or c < 0 or c >= grid_cols:
			continue
		var rect = ColorRect.new()
		rect.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
		rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
		rect.color = preview_color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_node.add_child(rect)

func _end_drag(mouse_pos: Vector2) -> void:
	_clear_preview()
	is_dragging = false
	
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	
	var grid_rect = grid_area.get_global_rect()
	
	if grid_rect.has_point(mouse_pos):
		var local_pos = mouse_pos - grid_area.global_position
		var target_row = clampi(int(local_pos.y / CELL_SIZE), 0, max_rows - 1)
		var target_col = clampi(int(local_pos.x / CELL_SIZE), 0, grid_cols - 1)
		
		var shape_key = drag_item.get("shape_key", _get_item_shape(drag_item["item_id"]))
		var cells = GameData.get_shape_cells(shape_key, drag_rotated)
		
		if _can_place_at(drag_item["item_id"], cells, target_row, target_col, drag_item["instance_id"]):
			# Place at target position
			_move_item(drag_item, target_row, target_col, drag_rotated)
		else:
			# Failed: restore to original position
			_restore_drag_item()
	else:
		# Dropped outside: restore
		_restore_drag_item()

func _restore_drag_item() -> void:
	var shape_key = drag_item.get("shape_key", _get_item_shape(drag_item["item_id"]))
	var cells = GameData.get_shape_cells(shape_key, drag_item.get("rotated", false))
	for cell in cells:
		var r = drag_item["row"] + cell[0]
		var c = drag_item["col"] + cell[1]
		if r < max_rows and c < grid_cols:
			grid[r][c] = drag_item["instance_id"]
	_refresh()

func _cancel_drag() -> void:
	_clear_preview()
	is_dragging = false
	
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	
	_restore_drag_item()

func _clear_preview() -> void:
	if preview_node:
		preview_node.queue_free()
		preview_node = null

# ========== INPUT HANDLING ==========

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
						_try_double_click(mb.position)
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

func _on_close() -> void:
	_cancel_drag()
	visible = false
	closed.emit()

func _rarity_color(r: String) -> Color:
	match r:
		"common":    return Color(0.55, 0.55, 0.55)
		"uncommon":  return Color(0.2,  0.8,  0.2)
		"rare":      return Color(0.2,  0.45, 1.0)
		"epic":      return Color(0.7,  0.2,  1.0)
		"legendary": return Color(1.0,  0.6,  0.0)
	return Color(0.55, 0.55, 0.55)
