## WarehouseUI - 仓库界面（每件物品独立，支持拖拽精确放置+预览）
extends CanvasLayer

signal closed

const CELL_SIZE: int = 40
const COLS: int = 10
const ROWS: int = 20   # 仓库最大行数

# 仓库格子占用表（用于碰撞检测）
var wh_grid: Array = []   # wh_grid[row][col] = item_idx+1 or 0
var item_positions: Array = []  # [{item, row, col, cells}]

# 拖拽状态
var drag_item: Dictionary = {}
var drag_idx: int = -1
var drag_ghost: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_rotated: bool = false
var is_dragging: bool = false
var item_slots: Array = []
var preview_node: Control = null

@onready var grid_container: Control = $Panel/Margin/VBox/ScrollContainer/GridArea
@onready var close_btn: Button       = $Panel/Margin/VBox/TitleRow/CloseBtn
@onready var empty_label: Label      = $Panel/Margin/VBox/EmptyLabel

func _ready() -> void:
	close_btn.pressed.connect(_on_close)

func open_warehouse() -> void:
	visible = true
	_refresh()

func _refresh() -> void:
	item_slots.clear()
	item_positions.clear()
	_init_wh_grid()
	for c in grid_container.get_children():
		c.queue_free()

	var items = GameData.warehouse
	empty_label.visible = items.is_empty()
	if items.is_empty():
		return

	# 贪心排列
	for i in range(items.size()):
		var item = items[i]
		var item_id = item["item_id"]
		var shape_key = item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
		var cells = GameData.get_shape_cells(shape_key, false)
		var placed = false
		for r in range(ROWS):
			for c in range(COLS):
				if _wh_can_place(cells, r, c, -1):
					_wh_mark(cells, r, c, i + 1)
					item_positions.append({"item": item, "idx": i, "row": r, "col": c, "cells": cells})
					placed = true; break
			if placed: break

	# 计算总行数
	var max_row = 3
	for p in item_positions:
		for cell in p["cells"]:
			max_row = max(max_row, p["row"] + cell[0] + 1)

	grid_container.custom_minimum_size = Vector2(COLS * CELL_SIZE, max_row * CELL_SIZE)

	# 背景格子
	for r in range(max_row):
		for c in range(COLS):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15, 1)
			grid_container.add_child(bg)

	# 放置物品
	for p in item_positions:
		var slot = _make_item_slot(p["item"], p["row"], p["col"], p["cells"])
		grid_container.add_child(slot)
		item_slots.append(slot)

func _init_wh_grid() -> void:
	wh_grid = []
	for _r in range(ROWS):
		var row = []
		for _c in range(COLS): row.append(0)
		wh_grid.append(row)

func _wh_can_place(cells: Array, row: int, col: int, exclude_val: int) -> bool:
	for cell in cells:
		var r = row + cell[0]; var c = col + cell[1]
		if r < 0 or r >= ROWS or c < 0 or c >= COLS: return false
		var v = wh_grid[r][c]
		if v != 0 and v != exclude_val: return false
	return true

func _wh_mark(cells: Array, row: int, col: int, val: int) -> void:
	for cell in cells:
		wh_grid[row + cell[0]][col + cell[1]] = val

func _wh_clear(cells: Array, row: int, col: int) -> void:
	for cell in cells:
		wh_grid[row + cell[0]][col + cell[1]] = 0

func _make_item_slot(item: Dictionary, base_row: int, base_col: int, cells: Array) -> Control:
	const CS = CELL_SIZE
	var item_id = item["item_id"]
	var item_color = ItemDB.get_item_color(item_id)
	var rarity_str = ItemDB.get_item_rarity_str(item_id)
	var max_r = 0; var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1); max_c = max(max_c, cell[1] + 1)
	var container = Control.new()
	container.position = Vector2(base_col * CS, base_row * CS)
	container.custom_minimum_size = Vector2(max_c * CS, max_r * CS)
	container.set_meta("wh_item", item)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = ItemDB.get_item_name(item_id)
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2(cell[1] * CS + 1, cell[0] * CS + 1)
		bg.size = Vector2(CS - 2, CS - 2)
		bg.color = item_color.darkened(0.25)
		container.add_child(bg)
	_apply_rarity_border(container, cells, rarity_str)
	var lbl_container = _make_label(ItemDB.get_item_name(item_id), max_r, max_c)
	container.add_child(lbl_container)
	var dot = ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.position = Vector2(max_c * CS - 7, max_r * CS - 7)
	dot.color = _rarity_color(rarity_str)
	container.add_child(dot)
	return container

func _apply_rarity_border(container: Control, cells: Array, rarity: String) -> void:
	var col = _rarity_color(rarity)
	const T = 2
	var max_r = 0; var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1); max_c = max(max_c, cell[1] + 1)
	var w = max_c * CELL_SIZE; var h = max_r * CELL_SIZE
	for b in [[Vector2(0,0),Vector2(w,T)],[Vector2(0,h-T),Vector2(w,T)],
			  [Vector2(0,0),Vector2(T,h)],[Vector2(w-T,0),Vector2(T,h)]]:
		var line = ColorRect.new()
		line.position = b[0]; line.size = b[1]; line.color = col
		container.add_child(line)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_drag(); _on_close(); return
		if event.keycode == KEY_R and is_dragging:
			drag_rotated = not drag_rotated
			if drag_ghost: drag_ghost.queue_free()
			drag_ghost = _make_ghost(drag_item)
			add_child(drag_ghost)
			drag_ghost.z_index = 100
			drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drag_ghost.position = get_viewport().get_mouse_position() + drag_offset
			get_viewport().set_input_as_handled(); return

	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not mb.double_click:
				_try_start_drag(mb.position)
			elif not mb.pressed and is_dragging:
				_end_drag(mb.position)
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and is_dragging:
			_cancel_drag(); get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		if drag_ghost: drag_ghost.position = event.position + drag_offset
		_update_preview(event.position)
		get_viewport().set_input_as_handled()

func _try_start_drag(mouse_pos: Vector2) -> void:
	for i in range(item_slots.size()):
		var slot = item_slots[i]
		if not is_instance_valid(slot): continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("wh_item", null)
			if item:
				drag_item = item
				drag_idx = i
				drag_rotated = false
				drag_offset = slot.global_position - mouse_pos
				is_dragging = true
				drag_ghost = _make_ghost(item)
				add_child(drag_ghost)
				drag_ghost.position = mouse_pos + drag_offset
				drag_ghost.z_index = 100
				drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.modulate = Color(1, 1, 1, 0.2)
				# 从 wh_grid 中清除自身占用
				if drag_idx < item_positions.size():
					var p = item_positions[drag_idx]
					_wh_clear(p["cells"], p["row"], p["col"])
			return

func _make_ghost(item: Dictionary) -> Control:
	var item_id = item["item_id"]
	var shape_key = item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
	var cells = GameData.get_shape_cells(shape_key, drag_rotated)
	var max_r = 0; var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1); max_c = max(max_c, cell[1] + 1)
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
	var lbl = Label.new()
	lbl.text = ItemDB.get_item_name(item_id)
	lbl.position = Vector2(2, 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if max_r == 1 and max_c == 1:
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.clip_text = true
	else:
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ghost.add_child(lbl)
	lbl.set_deferred("size", Vector2(max_c * CELL_SIZE - 4, max_r * CELL_SIZE - 4))
	return ghost

func _update_preview(mouse_pos: Vector2) -> void:
	if preview_node:
		preview_node.queue_free()
		preview_node = null
	var grid_rect = grid_container.get_global_rect()
	if not grid_rect.has_point(mouse_pos): return
	var item_id = drag_item["item_id"]
	var shape_key = drag_item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
	var cells = GameData.get_shape_cells(shape_key, drag_rotated)
	var local_pos = mouse_pos - grid_container.global_position
	var target_row = clampi(int(local_pos.y / CELL_SIZE), 0, ROWS - 1)
	var target_col = clampi(int(local_pos.x / CELL_SIZE), 0, COLS - 1)
	var can_place = _wh_can_place(cells, target_row, target_col, -1)
	var preview_color = Color(0.2, 1.0, 0.3, 0.45) if can_place else Color(1.0, 0.2, 0.2, 0.45)
	preview_node = Control.new()
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.z_index = 50
	grid_container.add_child(preview_node)
	for cell in cells:
		var r = target_row + cell[0]; var c = target_col + cell[1]
		if r < 0 or r >= ROWS or c < 0 or c >= COLS: continue
		var rect = ColorRect.new()
		rect.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
		rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
		rect.color = preview_color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_node.add_child(rect)

func _end_drag(mouse_pos: Vector2) -> void:
	if preview_node: preview_node.queue_free(); preview_node = null
	is_dragging = false
	if drag_ghost: drag_ghost.queue_free(); drag_ghost = null

	var grid_rect = grid_container.get_global_rect()
	var orig_slot = item_slots[drag_idx] if drag_idx < item_slots.size() else null

	if grid_rect.has_point(mouse_pos):
		var local_pos = mouse_pos - grid_container.global_position
		var target_row = clampi(int(local_pos.y / CELL_SIZE), 0, ROWS - 1)
		var target_col = clampi(int(local_pos.x / CELL_SIZE), 0, COLS - 1)
		var item_id = drag_item["item_id"]
		var shape_key = drag_item.get("shape_key", ItemDB.get_item(item_id).get("shape", "1x1"))
		var cells = GameData.get_shape_cells(shape_key, drag_rotated)
		if _wh_can_place(cells, target_row, target_col, -1):
			# 放置成功：更新 wh_grid 和 item_positions
			_wh_mark(cells, target_row, target_col, drag_idx + 1)
			if drag_idx < item_positions.size():
				item_positions[drag_idx]["row"] = target_row
				item_positions[drag_idx]["col"] = target_col
				item_positions[drag_idx]["cells"] = cells
			drag_item["shape_key"] = shape_key  # 保存旋转后的 shape
			_refresh()
			drag_idx = -1
			return
		else:
			# 放置失败：恢复原位
			if drag_idx < item_positions.size():
				var p = item_positions[drag_idx]
				_wh_mark(p["cells"], p["row"], p["col"], drag_idx + 1)
	else:
		# 落在格子外：恢复原位
		if drag_idx < item_positions.size():
			var p = item_positions[drag_idx]
			_wh_mark(p["cells"], p["row"], p["col"], drag_idx + 1)

	if is_instance_valid(orig_slot):
		orig_slot.modulate = Color(1, 1, 1, 1)
	drag_idx = -1

func _cancel_drag() -> void:
	if preview_node: preview_node.queue_free(); preview_node = null
	is_dragging = false
	if drag_ghost: drag_ghost.queue_free(); drag_ghost = null
	# 恢复原位
	if drag_idx >= 0 and drag_idx < item_positions.size():
		var p = item_positions[drag_idx]
		_wh_mark(p["cells"], p["row"], p["col"], drag_idx + 1)
	if drag_idx >= 0 and drag_idx < item_slots.size():
		var s = item_slots[drag_idx]
		if is_instance_valid(s): s.modulate = Color(1, 1, 1, 1)
	drag_idx = -1

func _on_close() -> void:
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

func _make_label(text: String, max_r: int, max_c: int) -> Control:
	const CS = CELL_SIZE
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
	
	lbl.custom_minimum_size = Vector2(max_c * CS - 4, max_r * CS - 4)
	lbl.set_deferred("size", Vector2(max_c * CS - 4, max_r * CS - 4))
	
	mc.add_child(lbl)
	return mc
