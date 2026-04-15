## WarehouseUI - 仓库界面（简化单格系统）
extends CanvasLayer

signal closed

const CELL_SIZE: int = 40
const COLS: int = 10
const ROWS: int = 20

var wh_items: Array = []  # [{item_id, amount, row, col}]

var is_dragging: bool = false
var drag_item: Dictionary = {}
var drag_ghost: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var preview_node: Control = null

var grid_container: Control
var close_btn: Button
var empty_label: Label

func _ready() -> void:
	grid_container = $Panel/Margin/VBox/ScrollContainer/GridArea
	close_btn = $Panel/Margin/VBox/TitleRow/CloseBtn
	empty_label = $Panel/Margin/VBox/EmptyLabel
	close_btn.pressed.connect(_on_close)

func open_warehouse() -> void:
	visible = true
	_refresh()

func _refresh() -> void:
	for c in grid_container.get_children(): c.queue_free()
	
	wh_items = []
	for i in range(GameData.warehouse.size()):
		var item = GameData.warehouse[i]
		wh_items.append({
			"idx": i,
			"item_id": item["item_id"],
			"amount": item.get("amount", 1),
			"row": item.get("row", -1),
			"col": item.get("col", -1),
		})
	
	_assign_positions()
	
	empty_label.visible = wh_items.is_empty()
	if wh_items.is_empty():
		grid_container.custom_minimum_size = Vector2(COLS * CELL_SIZE, 3 * CELL_SIZE)
		return
	
	var max_row = 3
	for item in wh_items:
		max_row = max(max_row, item["row"] + 1)
	
	grid_container.custom_minimum_size = Vector2(COLS * CELL_SIZE, max_row * CELL_SIZE)
	
	# 背景格子
	for r in range(max_row):
		for c in range(COLS):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15)
			grid_container.add_child(bg)
	
	# 物品
	for item in wh_items:
		var slot = _make_slot(item)
		slot.position = Vector2(item["col"] * CELL_SIZE, item["row"] * CELL_SIZE)
		grid_container.add_child(slot)

func _assign_positions() -> void:
	var used: Array = []
	for _r in range(ROWS):
		var row = []
		for _c in range(COLS): row.append(false)
		used.append(row)
	
	# 先标记已有位置
	for item in wh_items:
		if item["row"] >= 0 and item["row"] < ROWS and item["col"] >= 0 and item["col"] < COLS:
			if not used[item["row"]][item["col"]]:
				used[item["row"]][item["col"]] = true
			else:
				item["row"] = -1
	
	# 为无位置物品分配
	for item in wh_items:
		if item["row"] < 0:
			for r in range(ROWS):
				var found = false
				for c in range(COLS):
					if not used[r][c]:
						item["row"] = r
						item["col"] = c
						used[r][c] = true
						found = true
						break
				if found: break

func _make_slot(item: Dictionary) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.set_meta("wh_item", item)
	
	var item_id = item["item_id"]
	var item_color = ItemDB.get_item_color(item_id)
	var rarity = ItemDB.get_item_rarity_str(item_id)
	
	var bg = ColorRect.new()
	bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	bg.color = item_color.darkened(0.25)
	container.add_child(bg)
	
	# 边框
	var border_col = _rarity_color(rarity)
	for b in [[Vector2(0,0),Vector2(CELL_SIZE,2)], [Vector2(0,CELL_SIZE-2),Vector2(CELL_SIZE,2)],
			  [Vector2(0,0),Vector2(2,CELL_SIZE)], [Vector2(CELL_SIZE-2,0),Vector2(2,CELL_SIZE)]]:
		var line = ColorRect.new()
		line.position = b[0]
		line.size = b[1]
		line.color = border_col
		container.add_child(line)
	
	# 文字
	var lbl = Label.new()
	lbl.text = ItemDB.get_item_name(item_id)
	lbl.position = Vector2(2, 2)
	lbl.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	lbl.clip_text = true
	container.add_child(lbl)
	
	# 数量
	if item["amount"] > 1:
		var amt = Label.new()
		amt.text = str(item["amount"])
		amt.position = Vector2(CELL_SIZE - 14, CELL_SIZE - 14)
		amt.add_theme_font_size_override("font_size", 8)
		amt.add_theme_color_override("font_color", Color(1, 1, 0))
		container.add_child(amt)
	
	return container

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
		_on_close()
		return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not mb.double_click:
				_try_start_drag(mb.position)
			elif not mb.pressed and is_dragging:
				_end_drag(mb.position)
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and is_dragging:
			_cancel_drag()
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_dragging:
		if drag_ghost: drag_ghost.position = event.position + drag_offset
		_update_preview(event.position)
		get_viewport().set_input_as_handled()

func _try_start_drag(mouse_pos: Vector2) -> void:
	for child in grid_container.get_children():
		if child.has_meta("wh_item") and child.get_global_rect().has_point(mouse_pos):
			var item = child.get_meta("wh_item")
			_start_drag(item, mouse_pos, child.global_position)
			return

func _start_drag(item: Dictionary, mouse_pos: Vector2, slot_pos: Vector2) -> void:
	is_dragging = true
	drag_item = item.duplicate()
	drag_offset = slot_pos - mouse_pos
	
	if drag_ghost: drag_ghost.queue_free()
	drag_ghost = _make_ghost(item)
	add_child(drag_ghost)
	drag_ghost.z_index = 100
	drag_ghost.position = mouse_pos + drag_offset
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_ghost(item: Dictionary) -> Control:
	var ghost = Control.new()
	ghost.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	ghost.modulate = Color(1, 1, 1, 0.75)
	
	var item_color = ItemDB.get_item_color(item["item_id"])
	var bg = ColorRect.new()
	bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	bg.color = item_color
	ghost.add_child(bg)
	
	var lbl = Label.new()
	lbl.text = ItemDB.get_item_name(item["item_id"])
	lbl.size = Vector2(CELL_SIZE, CELL_SIZE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	ghost.add_child(lbl)
	
	return ghost

func _update_preview(mouse_pos: Vector2) -> void:
	if preview_node:
		preview_node.queue_free()
		preview_node = null
	
	var grid_rect = grid_container.get_global_rect()
	if not grid_rect.has_point(mouse_pos): return
	
	var local = mouse_pos - grid_container.global_position
	var col = clampi(int(local.x / CELL_SIZE), 0, COLS - 1)
	var row = clampi(int(local.y / CELL_SIZE), 0, ROWS - 1)
	
	var can = _can_place(row, col)
	var color = Color(0.2, 1.0, 0.3, 0.45) if can else Color(1.0, 0.2, 0.2, 0.45)
	
	preview_node = Control.new()
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.z_index = 50
	grid_container.add_child(preview_node)
	
	var rect = ColorRect.new()
	rect.position = Vector2(col * CELL_SIZE, row * CELL_SIZE)
	rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.add_child(rect)

func _can_place(row: int, col: int) -> bool:
	for item in wh_items:
		if item["row"] == row and item["col"] == col:
			if item["idx"] != drag_item.get("idx", -1):
				return false
	return true

func _end_drag(mouse_pos: Vector2) -> void:
	_clear_preview()
	is_dragging = false
	if drag_ghost: drag_ghost.queue_free(); drag_ghost = null
	
	var grid_rect = grid_container.get_global_rect()
	if not grid_rect.has_point(mouse_pos): return
	
	var local = mouse_pos - grid_container.global_position
	var col = clampi(int(local.x / CELL_SIZE), 0, COLS - 1)
	var row = clampi(int(local.y / CELL_SIZE), 0, ROWS - 1)
	
	if not _can_place(row, col):
		return
	
	# 更新位置
	var idx = drag_item.get("idx", -1)
	if idx >= 0 and idx < GameData.warehouse.size():
		GameData.warehouse[idx]["row"] = row
		GameData.warehouse[idx]["col"] = col
		_refresh()

func _cancel_drag() -> void:
	_clear_preview()
	is_dragging = false
	if drag_ghost: drag_ghost.queue_free(); drag_ghost = null

func _clear_preview() -> void:
	if preview_node:
		preview_node.queue_free()
		preview_node = null

func _on_close() -> void:
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
