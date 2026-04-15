## LootUI - 物资箱界面（重构版 v3: 纯单格系统）
## 仿三角洲行动简化版：
##   ✅ 搜索状态持久化：已搜过的物品再次打开不会重新搜索
##   ✅ 物品位置固定：生成时确定位置，永不改变
##   ✅ 完整拖拽：背包↔物资箱双向、背包内移动
##   ✅ 双击快拾：双击物资箱物品自动入包
extends CanvasLayer

signal closed

const CELL_SIZE: int = 40
const BAG_COLS: int = 10
const BAG_ROWS: int = 6
const LOOT_COLS: int = 6

# 搜索时间（秒）- 按稀有度不同
const SEARCH_TIME: Dictionary = {
	"common": 0.5,
	"uncommon": 1.0,
	"rare": 2.0,
	"epic": 3.0,
	"legendary": 5.0,
}

# ── 数据引用 ──────────────────────────────────────
var current_spot: Node = null          # 当前操作的 LootSpot/LootBox 引用
var loot_items: Array = []             # 直接引用物资源的 items 数组（同一引用！）
var is_searching: bool = false
var search_elapsed: float = 0.0
var search_finish_time: float = 0.0
var search_index: int = 0              # 当前搜索到第几个

# ── 拖拽状态 ──────────────────────────────────────
var is_dragging: bool = false
var drag_item: Dictionary = {}
var drag_source: String = ""           # "loot" 或 "bag"
var drag_ghost: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var preview_node: Control = null
var drag_source_slot: Control = null   # 记录原始槽位节点，用于半透明效果

# ── UI 节点引用 ───────────────────────────────────
var player_grid: Control
var search_bar: ProgressBar
var search_label: Label
var close_btn: Button
var loot_title: Label
var loot_grid: Control
var loot_scroll: ScrollContainer

# ── 初始化 ────────────────────────────────────────

func _ready() -> void:
	player_grid = $Panel/MarginContainer/VBox/HBox/PlayerSide/GridArea
	search_bar = $Panel/MarginContainer/VBox/SearchBar
	search_label = $Panel/MarginContainer/VBox/SearchLabel
	close_btn = $Panel/MarginContainer/VBox/TitleRow/CloseBtn
	loot_title = $Panel/MarginContainer/VBox/HBox/LootSide/LootTitle
	loot_grid = $Panel/MarginContainer/VBox/HBox/LootSide/ScrollContainer/GridArea
	loot_scroll = $Panel/MarginContainer/VBox/HBox/LootSide/ScrollContainer
	
	close_btn.pressed.connect(_on_close)
	GameData.inventory_changed.connect(_refresh_bag)


## ════════════════════════════════════════════════
##  打开物资箱
## ════════════════════════════════════════════════

func open_loot(box_items: Array, spot: Node) -> void:
	current_spot = spot
	
	# 关键：直接引用（不复制），确保 searched 状态共享
	# LootSpot.sync_items() / LootBox 的数据会修改同一数组对象
	loot_items = box_items
	
	visible = true
	_refresh_loot()
	_refresh_bag()
	_update_title()
	
	# 搜索状态检查 - 跳过已搜索的物品
	_setup_search_state()


## ════════════════════════════════════════════════
##  搜索系统（核心：不重复搜索！）
## ════════════════════════════════════════════════

func _setup_search_state() -> void:
	"""初始化或恢复搜索状态"""
	is_searching = false
	search_elapsed = 0.0
	
	# 找到第一个未搜索的物品索引
	search_index = _find_first_unsearched_index()
	
	var unsearched_count = _count_unsearched()
	if unsearched_count > 0:
		# 还有未搜索的物品 → 开始搜索
		search_bar.value = _get_search_progress_percent()
		search_label.text = "搜索中... (%d/%d 已搜)" % [loot_items.size() - unsearched_count, loot_items.size()]
		call_deferred("_start_search_next")
	else:
		# 全部已搜过 → 直接完成状态
		search_bar.value = 100
		search_label.text = "已完成搜索"

func _find_first_unsearched_index() -> int:
	"""找到第一个未搜索物品的索引，按原始顺序"""
	for i in range(loot_items.size()):
		if not loot_items[i].get("searched", false):
			return i
	return loot_items.size()  # 全部已搜索

func _count_unsearched() -> int:
	var count = 0
	for item in loot_items:
		if not item.get("searched", false):
			count += 1
	return count

func _get_search_progress_percent() -> float:
	if loot_items.is_empty():
		return 100.0
	var searched = loot_items.size() - _count_unsearched()
	return (float(searched) / float(loot_items.size())) * 100.0

func _start_search_next() -> void:
	"""开始搜索下一个未搜索物品"""
	# 跳过已搜索的
	while search_index < loot_items.size() and loot_items[search_index].get("searched", false):
		search_index += 1
	
	if search_index >= loot_items.size():
		_on_all_searched()
		return
	
	var entry = loot_items[search_index]
	search_elapsed = 0.0
	search_finish_time = SEARCH_TIME.get(entry.get("rarity", "common"), 0.5)
	is_searching = true
	var item_name = ItemDB.get_item_name(entry["item_id"])
	search_label.text = "搜索: %s... (%d/%d)" % [item_name, search_index + 1, loot_items.size()]

func _process(delta: float) -> void:
	if not is_searching or not visible:
		return
	
	search_elapsed += delta
	search_bar.value = clampf((search_elapsed / search_finish_time) * 100.0, 0.0, 100.0)
	
	if search_elapsed >= search_finish_time:
		is_searching = false
		search_bar.value = 0.0
		
		# 标记为已搜索（直接修改引用的数据，物资源也受影响）
		loot_items[search_index]["searched"] = true
		
		# 同步回物资源（保险起见）
		if current_spot and current_spot.has_method("sync_items"):
			current_spot.sync_items(loot_items)
		
		_refresh_loot()
		
		# 搜下一个
		search_index += 1
		_start_search_next()

func _on_all_searched() -> void:
	is_searching = false
	search_bar.value = 100
	search_label.text = "完成"
	print("[LootUI] 全部物品搜索完毕 (%d 件)" % loot_items.size())


## ════════════════════════════════════════════════
##  刷新显示（关键：保持原始顺序！不排序不改位置！）
## ════════════════════════════════════════════════

func _refresh_loot() -> void:
	"""刷新物资箱显示 - 保持生成时的固定顺序和位置"""
	for c in loot_grid.get_children():
		c.queue_free()
	
	if loot_items.is_empty():
		loot_grid.custom_minimum_size = Vector2(LOOT_COLS * CELL_SIZE, CELL_SIZE)
		return
	
	# 计算需要的网格大小（基于最大row值）
	var max_row = 3
	for item in loot_items:
		if item.get("row", 0) >= 0:
			max_row = max(max_row, item["row"] + 1)
	
	loot_grid.custom_minimum_size = Vector2(LOOT_COLS * CELL_SIZE, max_row * CELL_SIZE)
	
	# 绘制背景格子
	for r in range(max_row):
		for c in range(LOOT_COLS):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15)
			loot_grid.add_child(bg)
	
	# 绘制物品 - 按原始数组顺序（绝不排序！），用 row/col 定位
	for item in loot_items:
		if item.get("row", -1) < 0:
			continue  # 跳过已被拾取的物品
		var slot = _make_item_slot(item, "loot")
		slot.position = Vector2(item["col"] * CELL_SIZE, item["row"] * CELL_SIZE)
		loot_grid.add_child(slot)

func _refresh_bag() -> void:
	"""刷新背包显示"""
	for c in player_grid.get_children():
		c.queue_free()
	
	# 背景格子
	for r in range(BAG_ROWS):
		for c in range(BAG_COLS):
			var bg = ColorRect.new()
			bg.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			bg.color = Color(0.1, 0.1, 0.15)
			player_grid.add_child(bg)
	
	# 物品 - 按 placed_items 数组顺序显示（保持稳定）
	for item in GameData.placed_items:
		var slot = _make_item_slot(item, "bag")
		slot.position = Vector2(item["col"] * CELL_SIZE, item["row"] * CELL_SIZE)
		player_grid.add_child(slot)


## ════════════════════════════════════════════════
##  物品槽位绘制（纯单格版）
## ════════════════════════════════════════════════

func _make_item_slot(item: Dictionary, source: String) -> Control:
	"""创建一个物品槽位节点（纯单格，40x40）"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.set_meta("item", item)
	container.set_meta("source", source)
	
	var item_id = item["item_id"]
	var is_searched = item.get("searched", true) if source == "loot" else true
	var rarity = item.get("rarity", ItemDB.get_item_rarity_str(item_id))
	
	if not is_searched:
		# 未搜索：显示问号占位符
		var bg = ColorRect.new()
		bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		bg.color = Color(0.15, 0.15, 0.2)
		container.add_child(bg)
		
		var lbl = Label.new()
		lbl.text = "?"
		lbl.size = Vector2(CELL_SIZE, CELL_SIZE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		container.add_child(lbl)
	else:
		# 已搜索 / 背包：显示实际物品
		var item_color = ItemDB.get_item_color(item_id)
		
		# 背景
		var bg = ColorRect.new()
		bg.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		bg.color = item_color.darkened(0.25)
		container.add_child(bg)
		
		# 稀有度边框
		var border_col = _rarity_color(rarity)
		for b in [
			[Vector2(0, 0), Vector2(CELL_SIZE, 2)],
			[Vector2(0, CELL_SIZE - 2), Vector2(CELL_SIZE, 2)],
			[Vector2(0, 0), Vector2(2, CELL_SIZE)],
			[Vector2(CELL_SIZE - 2, 0), Vector2(2, CELL_SIZE)]
		]:
			var line = ColorRect.new()
			line.position = b[0]
			line.size = b[1]
			line.color = border_col
			container.add_child(line)
		
		# 物品名称
		var lbl = Label.new()
		lbl.text = ItemDB.get_item_name(item_id)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		lbl.clip_text = true
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		
		var lbl_mc = MarginContainer.new()
		lbl_mc.add_theme_constant_override("margin_left", 2)
		lbl_mc.add_theme_constant_override("margin_top", 2)
		lbl_mc.add_theme_constant_override("margin_right", 2)
		lbl_mc.add_theme_constant_override("margin_bottom", 2)
		lbl_mc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lbl_mc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		lbl.custom_minimum_size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
		lbl.set_deferred("size", Vector2(CELL_SIZE - 4, CELL_SIZE - 4))
		lbl_mc.add_child(lbl)
		container.add_child(lbl_mc)
		
		# 稀有度小点
		var dot = ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.position = Vector2(CELL_SIZE - 6, CELL_SIZE - 6)
		dot.color = border_col
		container.add_child(dot)
	
	# 数量标签（堆叠物品显示数量）- 仅背包
	var amount = item.get("amount", 1)
	if amount > 1 and source == "bag":
		var amt_lbl = Label.new()
		amt_lbl.text = str(amount)
		amt_lbl.position = Vector2(CELL_SIZE - 14, CELL_SIZE - 14)
		amt_lbl.add_theme_font_size_override("font_size", 8)
		amt_lbl.add_theme_color_override("font_color", Color(1, 1, 0))
		container.add_child(amt_lbl)
	
	return container


## ════════════════════════════════════════════════
##  拖拽系统（纯单格，4种情况统一处理）
## ════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# ESC / Interact 关闭
	if event.is_action_pressed("interact"):
		_cancel_drag()
		_on_close()
		return
	
	# 鼠标事件
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
				# 释放鼠标
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

func _try_start_drag(mouse_pos: Vector2) -> void:
	"""尝试开始拖拽 - 先检查背包，再检查物资箱"""
	# 先检查背包区域
	for child in player_grid.get_children():
		if child.has_meta("item") and child.get_global_rect().has_point(mouse_pos):
			var item = child.get_meta("item")
			_start_drag(item, "bag", mouse_pos, child.global_position, child)
			return
	
	# 再检查物资箱区域
	for child in loot_grid.get_children():
		if child.has_meta("item") and child.get_global_rect().has_point(mouse_pos):
			var item = child.get_meta("item")
			# 只能拖拽已搜索的物品
			if item.get("searched", true):
				_start_drag(item, "loot", mouse_pos, child.global_position, child)
			return

func _start_drag(item: Dictionary, source: String, mouse_pos: Vector2, slot_pos: Vector2, slot_node: Control) -> void:
	"""开始拖拽操作"""
	is_dragging = true
	drag_item = item.duplicate()  # 复制一份用于拖拽
	drag_source = source
	drag_source_slot = slot_node
	drag_offset = slot_pos - mouse_pos
	
	# 创建幽灵节点
	if drag_ghost:
		drag_ghost.queue_free()
	drag_ghost = _make_drag_ghost(item)
	add_child(drag_ghost)
	drag_ghost.z_index = 100
	drag_ghost.position = mouse_pos + drag_offset
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 原始槽位半透明
	if is_instance_valid(drag_source_slot):
		drag_source_slot.modulate = Color(1, 1, 1, 0.25)

func _make_drag_ghost(item: Dictionary) -> Control:
	"""创建拖拽幽灵节点"""
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
	"""更新拖拽预览高亮（纯单格版本，简单！）"""
	if preview_node:
		preview_node.queue_free()
		preview_node = null
	
	var player_rect = player_grid.get_global_rect()
	var loot_rect = loot_grid.get_global_rect()
	
	var target: String = ""
	var local: Vector2
	var cols: int
	
	if player_rect.has_point(mouse_pos):
		target = "bag"
		local = mouse_pos - player_rect.position
		cols = BAG_COLS
	elif loot_rect.has_point(mouse_pos):
		target = "loot"
		local = mouse_pos - loot_rect.position
		cols = LOOT_COLS
	else:
		return  # 不在任何有效区域
	
	var col = clampi(int(local.x / CELL_SIZE), 0, cols - 1)
	var row = clampi(int(local.y / CELL_SIZE), 0, 9999)
	
	var can_place = _can_place_at(target, row, col)
	var preview_color = Color(0.2, 1.0, 0.3, 0.45) if can_place else Color(1.0, 0.2, 0.2, 0.45)
	
	preview_node = Control.new()
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.z_index = 50
	
	var parent = player_grid if target == "bag" else loot_grid
	parent.add_child(preview_node)
	
	var rect = ColorRect.new()
	rect.position = Vector2(col * CELL_SIZE, row * CELL_SIZE)
	rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
	rect.color = preview_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.add_child(rect)

func _can_place_at(target: String, row: int, col: int) -> bool:
	"""检查目标位置是否可以放置（纯单格版本）"""
	if target == "bag":
		# 背包：通过 GameData 的 can_place_item 检查（排除拖拽源自身）
		var exclude_id = drag_item.get("instance_id", -1)
		return GameData.can_place_item(row, col, exclude_id)
	else:
		# 物资箱：检查是否被其他物品占用（排除自身）
		for item in loot_items:
			if item["row"] == row and item["col"] == col:
				if item.get("instance_id", -1) != drag_item.get("instance_id", -1):
					return false
		return true

func _end_drag(mouse_pos: Vector2) -> void:
	"""结束拖拽 - 根据来源和目标执行对应操作（v3: 统一处理）"""
	_clear_preview()
	is_dragging = false
	
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	
	# 恢复原始槽位的透明度
	if is_instance_valid(drag_source_slot):
		drag_source_slot.modulate = Color(1, 1, 1, 1)
		drag_source_slot = null
	
	var player_rect = player_grid.get_global_rect()
	var loot_rect = loot_grid.get_global_rect()
	
	if loot_rect.has_point(mouse_pos) and drag_source == "loot":
		# === 情况A: 物资箱 → 背包（贪心算法自动找空位）===
		_move_to_bag()
		
	elif player_rect.has_point(mouse_pos) and drag_source == "bag":
		# === 情况B: 背包内移动（精确放置到目标格）===
		var local = mouse_pos - player_rect.position
		var col = clampi(int(local.x / CELL_SIZE), 0, BAG_COLS - 1)
		var row = clampi(int(local.y / CELL_SIZE), 0, BAG_ROWS - 1)
		_move_within_bag(row, col)
		
	elif loot_rect.has_point(mouse_pos) and drag_source == "bag":
		# === 情况C: 背包 → 物资箱（精确放置到目标格）===
		var local = mouse_pos - loot_rect.position
		var col = clampi(int(local.x / CELL_SIZE), 0, LOOT_COLS - 1)
		var row = clampi(int(local.y / CELL_SIZE), 0, 9999)
		_move_to_loot(row, col)
		
	else:
		# === 情况D: 拖到空白处 → 取消，回到原位 ===
		_refresh_bag()

## ── 拖拽操作实现（v3: 极简化）───────────────────

func _move_to_bag() -> void:
	"""从物资箱移动物品到背包（自动找空位）"""
	var instance_id = drag_item.get("instance_id", -1)
	var item_name = ItemDB.get_item_name(drag_item["item_id"])
	
	# 从物资箱列表中移除
	var idx = -1
	for i in range(loot_items.size()):
		if loot_items[i].get("instance_id", -1) == instance_id:
			idx = i
			break
	if idx >= 0:
		loot_items.remove_at(idx)
	
	# 同步到物资源
	if current_spot and current_spot.has_method("sync_items"):
		current_spot.sync_items(loot_items)
	
	# 放入背包（使用 GameData.find_placement 获取正确位置）
	var placement = GameData.find_placement()
	var success = false
	if placement["found"]:
		success = GameData.place_item(drag_item["item_id"], 1, placement["row"], placement["col"])
	
	if success:
		print("[LootUI] 拾取: %s → 背包(%d,%d)" % [item_name, placement["row"], placement["col"]])
	else:
		print("[LootUI] 背包已满! 无法拾取: %s" % [item_name])
	
	_refresh_loot()
	_refresh_bag()
	_update_title()

func _move_within_bag(new_row: int, new_col: int) -> void:
	"""在背包内移动物品（v3: 使用 GameData.move_item，简洁！）"""
	var instance_id = drag_item.get("instance_id", -1)
	var item_name = ItemDB.get_item_name(drag_item["item_id"])
	
	if GameData.move_item(instance_id, new_row, new_col):
		print("[LootUI] 背包内移动: %s → (%d,%d)" % [item_name, new_row, new_col])
	else:
		print("[LootUI] 目标位置不可用，回到原位")
	
	_refresh_bag()

func _move_to_loot(row: int, col: int) -> void:
	"""从背包容器移动物品到物资箱（精确放置）"""
	# 检查目标位置是否被占用
	for item in loot_items:
		if item["row"] == row and item["col"] == col:
			print("[LootUI] 该位置已有物品!")
			_refresh_bag()
			return
	
	var instance_id = drag_item.get("instance_id", -1)
	var item_name = ItemDB.get_item_name(drag_item["item_id"])
	
	# 从背包移除
	if not GameData.remove_item_from_inventory(instance_id):
		print("[LootUI] 从背包移除失败!")
		return
	
	# 添加到物资箱（注意：append 到末尾会改变顺序，但这是用户主动操作）
	loot_items.append({
		"instance_id": instance_id,
		"item_id": drag_item["item_id"],
		"row": row,
		"col": col,
		"searched": true,  # 从背包放回的默认已搜索
		"rarity": drag_item.get("rarity", "common"),
	})
	
	# 同步到物资源
	if current_spot and current_spot.has_method("sync_items"):
		current_spot.sync_items(loot_items)
	
	print("[LootUI] 放回: %s → 物资箱(%d,%d)" % [item_name, row, col])
	_refresh_loot()
	_refresh_bag()
	_update_title()


## ── 双击快拾 ─────────────────────────────────────

func _try_double_click(mouse_pos: Vector2) -> bool:
	"""处理双击事件 - 仅对物资箱中的已搜索物品生效"""
	for child in loot_grid.get_children():
		if child.has_meta("item") and child.get_global_rect().has_point(mouse_pos):
			var item = child.get_meta("item")
			if item.get("searched", true):
				# 贪心找背包空位
				var placement = GameData.find_placement()
				if placement["found"]:
					# 直接从物资箱移除并放入背包
					var instance_id = item.get("instance_id", -1)
					var item_name = ItemDB.get_item_name(item["item_id"])
					
					# 从物资箱列表中移除
					var idx = -1
					for i in range(loot_items.size()):
						if loot_items[i].get("instance_id", -1) == instance_id:
							idx = i
							break
					if idx >= 0:
						loot_items.remove_at(idx)
					
					# 同步到物资源
					if current_spot and current_spot.has_method("sync_items"):
						current_spot.sync_items(loot_items)
					
					# 放入背包
					var success = GameData.place_item(item["item_id"], 1, placement["row"], placement["col"])
					
					if success:
						print("[LootUI] 双击快拾: %s → 背包(%d,%d)" % [item_name, placement["row"], placement["col"]])
					else:
						print("[LootUI] 背包已满！无法拾取: %s" % [item_name])
					
					_refresh_loot()
					_refresh_bag()
					_update_title()
					return true
				else:
					print("[LootUI] 背包已满！")
					return true
	return false


## ── 辅助方法 ─────────────────────────────────────

func _cancel_drag() -> void:
	"""取消当前拖拽"""
	_clear_preview()
	is_dragging = false
	
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	
	if is_instance_valid(drag_source_slot):
		drag_source_slot.modulate = Color(1, 1, 1, 1)
		drag_source_slot = null

func _clear_preview() -> void:
	"""清除预览节点"""
	if preview_node:
		preview_node.queue_free()
		preview_node = null

func _update_title() -> void:
	"""更新物资箱标题"""
	var total = loot_items.size()
	var searched_count = 0
	for item in loot_items:
		if item.get("searched", false):
			searched_count += 1
	loot_title.text = "物资箱 (%d/%d)" % [searched_count, total]

func _on_close() -> void:
	"""关闭物资箱界面"""
	_cancel_drag()
	
	# 关闭时同步最终状态到物资源
	if current_spot and current_spot.has_method("sync_items"):
		current_spot.sync_items(loot_items)
	
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
