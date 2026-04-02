## GridPanel - 通用格子面板（背包/物资箱/仓库共用）
## 用法：
##   var panel = GridPanel.new()
##   panel.setup(COLS, ROWS, CELL_SIZE)
##   panel.set_items(items_array)   # items: [{item_id, shape_key, rotated, row, col, ...}]
##   panel.on_double_click = func(item): ...
extends Control

signal item_double_clicked(item: Dictionary)

const CS: int = 40   # 默认格子大小

var cols: int = 10
var rows: int = 6
var cell_size: int = CS

# 已放置物品的节点列表（用于双击命中检测）
var item_slots: Array = []

func setup(p_cols: int, p_rows: int, p_cell_size: int = CS) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size
	custom_minimum_size = Vector2(cols * cell_size, rows * cell_size)

# ── 绘制背景格子 ──────────────────────────────────────────
func draw_background() -> void:
	for child in get_children():
		child.queue_free()
	item_slots.clear()
	for r in range(rows):
		for c in range(cols):
			var cell = ColorRect.new()
			cell.position = Vector2(c * cell_size, r * cell_size)
			cell.size = Vector2(cell_size - 2, cell_size - 2)
			cell.color = Color(0.1, 0.1, 0.15, 1)
			add_child(cell)

# ── 放置一个物品（多格）────────────────────────────────────
func place_item(item: Dictionary) -> Control:
	var item_id   = item.get("item_id", 0)
	var shape_key = item.get("shape_key", "1x1")
	var rotated   = item.get("rotated", false)
	var base_row  = item.get("row", 0)
	var base_col  = item.get("col", 0)
	var cells     = GameData.get_shape_cells(shape_key, rotated)
	var item_color = ItemDB.get_item_color(item_id)
	var rarity_str = ItemDB.get_item_rarity_str(item_id)

	var max_r = 0; var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)

	var container = Control.new()
	container.position = Vector2(base_col * cell_size, base_row * cell_size)
	container.custom_minimum_size = Vector2(max_c * cell_size, max_r * cell_size)
	container.set_meta("grid_item", item)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 每格背景
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2(cell[1] * cell_size + 1, cell[0] * cell_size + 1)
		bg.size = Vector2(cell_size - 2, cell_size - 2)
		bg.color = item_color.darkened(0.25)
		container.add_child(bg)

	# 稀有度边框
	_add_rarity_border(container, cells, rarity_str)

	# 物品名称（铺满）
	var lbl = Label.new()
	lbl.text = ItemDB.get_item_name(item_id)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.position = Vector2(2, 2)
	lbl.size = Vector2(max_c * cell_size - 4, max_r * cell_size - 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	container.add_child(lbl)

	# 稀有度小点（右下角）
	var dot = ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.position = Vector2(max_c * cell_size - 7, max_r * cell_size - 7)
	dot.color = _rarity_color(rarity_str)
	container.add_child(dot)

	add_child(container)
	item_slots.append(container)
	return container

# ── 放置"空占位"格子（已拾取/已使用）────────────────────────
func place_empty(base_row: int, base_col: int, cells: Array) -> void:
	for cell in cells:
		var bg = ColorRect.new()
		bg.position = Vector2((base_col + cell[1]) * cell_size + 1, (base_row + cell[0]) * cell_size + 1)
		bg.size = Vector2(cell_size - 2, cell_size - 2)
		bg.color = Color(0.08, 0.08, 0.1, 1)
		add_child(bg)

# ── 双击命中检测（由父节点的 _input 调用）────────────────────
func check_double_click(mouse_pos: Vector2) -> bool:
	for slot in item_slots:
		if not is_instance_valid(slot): continue
		if slot.get_global_rect().has_point(mouse_pos):
			var item = slot.get_meta("grid_item", null)
			if item:
				item_double_clicked.emit(item)
			return true
	return false

# ── 稀有度边框 ────────────────────────────────────────────
func _add_rarity_border(container: Control, cells: Array, rarity: String) -> void:
	var col = _rarity_color(rarity)
	const T = 2
	var max_r = 0; var max_c = 0
	for cell in cells:
		max_r = max(max_r, cell[0] + 1)
		max_c = max(max_c, cell[1] + 1)
	var w = max_c * cell_size
	var h = max_r * cell_size
	for b in [[Vector2(0,0), Vector2(w,T)], [Vector2(0,h-T), Vector2(w,T)],
			  [Vector2(0,0), Vector2(T,h)], [Vector2(w-T,0), Vector2(T,h)]]:
		var line = ColorRect.new()
		line.position = b[0]; line.size = b[1]; line.color = col
		container.add_child(line)

func _rarity_color(r: String) -> Color:
	match r:
		"common":    return Color(0.55, 0.55, 0.55)
		"uncommon":  return Color(0.2,  0.8,  0.2)
		"rare":      return Color(0.2,  0.45, 1.0)
		"epic":      return Color(0.7,  0.2,  1.0)
		"legendary": return Color(1.0,  0.6,  0.0)
	return Color(0.55, 0.55, 0.55)
