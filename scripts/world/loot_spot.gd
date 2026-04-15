## LootSpot - 地图固定物资箱（简化单格系统）
extends Area2D

const LOOT_COLS: int = 6  # 物资箱列数

var spot_id: int = 0
var loot_level: int = 1
var loot_items: Array = []  # [{instance_id, item_id, row, col, rarity, searched}]
var _generated: bool = false
var visual: Sprite2D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("loot_spot")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

	if has_meta("spot_id"):
		spot_id = get_meta("spot_id")
	if has_meta("loot_level"):
		loot_level = get_meta("loot_level")

	# 地图箱统一使用军绿金属箱外观
	visual = Sprite2D.new()
	visual.centered = true

	var tex = load("res://assets/ink/loot_box_map.png")
	if not tex:
		tex = load("res://assets/ink/loot_level1.png")
	if tex:
		visual.texture = tex
	else:
		print("warn: loot_box_map.png not found")

	add_child(visual)

	# 碰撞
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

## 生成物品并分配固定位置（仅首次调用时执行）
func _ensure_generated() -> void:
	if _generated:
		return
	_generated = true

	var raw = ItemDB.generate_loot(loot_level)
	var iid = 1
	var row = 0
	var col = 0

	for item in raw:
		# 每个物品占1格，row-major顺序分配位置
		loot_items.append({
			"instance_id": (spot_id * 10000) + iid,
			"item_id": item["id"],
			"rarity": item.get("rarity", "common"),
			"row": row,
			"col": col,
			"searched": false,  # 初始未搜索
		})

		iid += 1
		col += 1
		if col >= LOOT_COLS:
			col = 0
			row += 1

## 从外部同步物品状态（关闭物资箱时调用）
func sync_items(items: Array) -> void:
	loot_items = items

## 交互打开物资箱
func interact(player: Node) -> void:
	_ensure_generated()
	print("Open map box %d (level %d, %d items)" % [spot_id, loot_level, loot_items.size()])
	var world = get_tree().current_scene
	if world.has_method("open_loot_ui"):
		world.call("open_loot_ui", loot_items, self)

## 移除物品
func remove_item(instance_id: int) -> bool:
	for i in range(loot_items.size()):
		if loot_items[i]["instance_id"] == instance_id:
			loot_items.remove_at(i)
			return true
	return false

## 添加物品
func add_item(item_data: Dictionary) -> void:
	# 新物品放在末尾（找第一个空位）
	var row = 0
	var col = 0
	var occupied = {}
	for item in loot_items:
		occupied[Vector2i(item["row"], item["col"])] = true

	while occupied.has(Vector2i(row, col)):
		col += 1
		if col >= LOOT_COLS:
			col = 0
			row += 1

	item_data["row"] = row
	item_data["col"] = col
	item_data["searched"] = true
	loot_items.append(item_data)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_ensure_generated()
		var unsearched = loot_items.filter(func(e): return not e.get("searched", false))
		if unsearched.size() > 0:
			print("F to open (%d items, %d unsearched)" % [loot_items.size(), unsearched.size()])
		else:
			print("Box already searched")

func _on_body_exited(_body: Node2D) -> void:
	pass
