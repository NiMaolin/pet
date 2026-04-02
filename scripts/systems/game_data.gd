## GameData - 游戏状态管理（含俄罗斯方块背包）
extends Node

# ── 信号 ──────────────────────────────────────────────────
signal health_changed(current: int, max_val: int)
signal pet_fused(pet_id: int)
signal pet_unfused
signal inventory_changed
signal warehouse_changed

# ── 玩家属性 ──────────────────────────────────────────────
var player_health: int = 100
var player_max_health: int = 100
var player_attack: int = 15
var player_defense: int = 5

# ── 宠物 ──────────────────────────────────────────────────
var equipped_pet_id: int = 0
var fused_pet_id: int = 0
var collected_pets: Array = []

# ── 背包（俄罗斯方块式，10列×6行）──────────────────────────
const GRID_COLS: int = 10
const GRID_ROWS: int = 6
# grid[row][col] = item_instance_id or 0
var grid: Array = []
# 已放置的物品实例列表
var placed_items: Array = []  # [{item_id, amount, row, col, shape_key, rotated}]

# ── 仓库 ──────────────────────────────────────────────────
var warehouse: Array = []  # [{item_id, amount, shape_key}]  每件独立

# ── 游戏状态 ──────────────────────────────────────────────
var is_in_game: bool = false
var current_map: String = ""
# 上次保存的槽位（-1 = 从未保存）；游戏进程本身不绑定槽位
var last_save_slot: int = -1
var play_time: float = 0.0

# ── 物品形状定义（行×列的占格列表）──────────────────────────
# 每个形状是 [[row_offset, col_offset], ...] 的列表
const ITEM_SHAPES: Dictionary = {
	"1x1": [[0,0]],
	"1x2": [[0,0],[0,1]],
	"2x1": [[0,0],[1,0]],
	"1x3": [[0,0],[0,1],[0,2]],
	"3x1": [[0,0],[1,0],[2,0]],
	"2x2": [[0,0],[0,1],[1,0],[1,1]],
	"2x3": [[0,0],[0,1],[0,2],[1,0],[1,1],[1,2]],
	"3x2": [[0,0],[0,1],[1,0],[1,1],[2,0],[2,1]],
	"3x3": [[0,0],[0,1],[0,2],[1,0],[1,1],[1,2],[2,0],[2,1],[2,2]],
}

func _ready() -> void:
	_init_grid()

func _process(delta: float) -> void:
	if is_in_game:
		play_time += delta

# ── 背包初始化 ────────────────────────────────────────────
func _init_grid() -> void:
	grid = []
	for r in range(GRID_ROWS):
		var row = []
		for c in range(GRID_COLS):
			row.append(0)
		grid.append(row)
	placed_items.clear()

# ── 获取物品形状 ──────────────────────────────────────────
func get_item_shape(item_id: int) -> String:
	return ItemDB.get_item(item_id).get("shape", "1x1")

func get_shape_cells(shape_key: String, rotated: bool = false) -> Array:
	var cells = ITEM_SHAPES.get(shape_key, [[0,0]])
	if not rotated:
		return cells
	# 旋转90度：[r,c] → [c, max_r - r]
	var max_r = 0
	for cell in cells:
		max_r = max(max_r, cell[0])
	var rotated_cells = []
	for cell in cells:
		rotated_cells.append([cell[1], max_r - cell[0]])
	return rotated_cells

# ── 检查是否可以放置 ──────────────────────────────────────
func can_place_item(item_id: int, row: int, col: int, rotated: bool = false) -> bool:
	var shape_key = get_item_shape(item_id)
	var cells = get_shape_cells(shape_key, rotated)
	for cell in cells:
		var r = row + cell[0]
		var c = col + cell[1]
		if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLS:
			return false
		if grid[r][c] != 0:
			return false
	return true

# ── 检查是否可以放置（排除指定 instance_id）────────────────
func can_place_item_excluding(item_id: int, row: int, col: int, rotated: bool, exclude_id: int) -> bool:
	var shape_key = get_item_shape(item_id)
	var cells = get_shape_cells(shape_key, rotated)
	for cell in cells:
		var r = row + cell[0]
		var c = col + cell[1]
		if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLS:
			return false
		var occupant = grid[r][c]
		if occupant != 0 and occupant != exclude_id:
			return false
	return true

# ── 移动已放置物品到新位置 ────────────────────────────────
func move_placed_item(instance_id: int, new_row: int, new_col: int, new_rotated: bool) -> bool:
	var idx = -1
	for i in range(placed_items.size()):
		if placed_items[i]["instance_id"] == instance_id:
			idx = i; break
	if idx == -1: return false
	var item = placed_items[idx]
	if not can_place_item_excluding(item["item_id"], new_row, new_col, new_rotated, instance_id):
		return false
	# 清除旧占用
	var old_cells = get_shape_cells(item["shape_key"], item["rotated"])
	for cell in old_cells:
		grid[item["row"] + cell[0]][item["col"] + cell[1]] = 0
	# 写入新占用
	var new_shape_key = get_item_shape(item["item_id"])
	var new_cells = get_shape_cells(new_shape_key, new_rotated)
	for cell in new_cells:
		grid[new_row + cell[0]][new_col + cell[1]] = instance_id
	placed_items[idx]["row"] = new_row
	placed_items[idx]["col"] = new_col
	placed_items[idx]["rotated"] = new_rotated
	placed_items[idx]["shape_key"] = new_shape_key
	inventory_changed.emit()
	return true

# ── 自动寻找可放置位置 ────────────────────────────────────
func find_placement(item_id: int) -> Dictionary:
	for rotated in [false, true]:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if can_place_item(item_id, r, c, rotated):
					return {"row": r, "col": c, "rotated": rotated, "found": true}
	return {"found": false}

# ── 放置物品到背包 ────────────────────────────────────────
func place_item(item_id: int, amount: int, row: int, col: int, rotated: bool = false) -> bool:
	if not can_place_item(item_id, row, col, rotated):
		return false
	var shape_key = get_item_shape(item_id)
	var cells = get_shape_cells(shape_key, rotated)
	var instance_id = placed_items.size() + 1
	for cell in cells:
		grid[row + cell[0]][col + cell[1]] = instance_id
	placed_items.append({
		"instance_id": instance_id,
		"item_id": item_id,
		"amount": amount,
		"row": row,
		"col": col,
		"shape_key": shape_key,
		"rotated": rotated,
	})
	inventory_changed.emit()
	return true

# ── 自动放置物品（寻找空位）─────────────────────────────────
func add_item_to_inventory(item_id: int, amount: int) -> bool:
	var placement = find_placement(item_id)
	if not placement["found"]:
		return false
	return place_item(item_id, amount, placement["row"], placement["col"], placement["rotated"])

# ── 从背包移除物品 ────────────────────────────────────────
func remove_item_from_inventory(instance_id: int) -> bool:
	var idx = -1
	for i in range(placed_items.size()):
		if placed_items[i]["instance_id"] == instance_id:
			idx = i
			break
	if idx == -1:
		return false
	var item = placed_items[idx]
	var cells = get_shape_cells(item["shape_key"], item["rotated"])
	for cell in cells:
		grid[item["row"] + cell[0]][item["col"] + cell[1]] = 0
	placed_items.remove_at(idx)
	inventory_changed.emit()
	return true

# ── 背包物品数量 ──────────────────────────────────────────
func get_inventory_item_count() -> int:
	return placed_items.size()

# ── 清空背包 ──────────────────────────────────────────────
func clear_inventory() -> void:
	_init_grid()
	inventory_changed.emit()

# ── 背包转仓库 ────────────────────────────────────────────
func transfer_inventory_to_warehouse() -> void:
	for item in placed_items:
		warehouse.append({
			"item_id": item["item_id"],
			"amount": item["amount"],
			"shape_key": item["shape_key"],
		})
	clear_inventory()
	warehouse_changed.emit()

# ── 宠物系统 ──────────────────────────────────────────────
func collect_pet(pet_id: int) -> void:
	if pet_id not in collected_pets:
		collected_pets.append(pet_id)

func fuse_pet(pet_id: int) -> void:
	if pet_id in collected_pets:
		fused_pet_id = pet_id
		var pet = PetDB.get_pet(pet_id)
		player_attack = pet["stats"]["attack"]
		player_defense = pet["stats"]["defense"]
		pet_fused.emit(pet_id)

func unfuse_pet() -> void:
	fused_pet_id = 0
	player_attack = 15
	player_defense = 5
	pet_unfused.emit()

# ── 存档数据 ──────────────────────────────────────────────
func get_save_data() -> Dictionary:
	# 序列化背包（placed_items 已含所有信息，grid 可从 placed_items 重建）
	return {
		"player_health": player_health,
		"collected_pets": collected_pets,
		"equipped_pet_id": equipped_pet_id,
		"warehouse": warehouse,
		"play_time": play_time,
		"placed_items": placed_items.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	player_health = data.get("player_health", 100)
	collected_pets = data.get("collected_pets", [])
	equipped_pet_id = data.get("equipped_pet_id", 0)
	# 仓库现在是 Array，兼容旧存档（Dictionary 格式）
	warehouse.clear()
	var raw_warehouse = data.get("warehouse", [])
	if raw_warehouse is Dictionary:
		# 旧存档兼容：转成 Array
		for k in raw_warehouse:
			warehouse.append({"item_id": int(k), "amount": raw_warehouse[k],
				"shape_key": ItemDB.get_item(int(k)).get("shape", "1x1")})
	else:
		warehouse = raw_warehouse.duplicate(true)
	play_time = data.get("play_time", 0.0)
	# 恢复背包
	_init_grid()
	var saved_items = data.get("placed_items", [])
	for item in saved_items:
		var shape_key = item.get("shape_key", "1x1")
		var rotated = item.get("rotated", false)
		var row = item.get("row", 0)
		var col = item.get("col", 0)
		var cells = get_shape_cells(shape_key, rotated)
		var instance_id = placed_items.size() + 1
		for cell in cells:
			grid[row + cell[0]][col + cell[1]] = instance_id
		placed_items.append({
			"instance_id": instance_id,
			"item_id": item.get("item_id", 1),
			"amount": item.get("amount", 1),
			"row": row,
			"col": col,
			"shape_key": shape_key,
			"rotated": rotated,
		})
	if saved_items.size() > 0:
		inventory_changed.emit()
