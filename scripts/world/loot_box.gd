## LootBox - 怪物死亡掉落箱（v3: 纯单格数据格式）
extends Area2D

var loot_level: int = 1
var loot_items: Array = []  # [{instance_id, item_id, rarity, row, col, searched}]
var _opened: bool = false
const BOX_COLS: int = 4    # 怪物箱列数（比地图箱窄）

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("loot_spot")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	if has_meta("loot_level"):
		loot_level = get_meta("loot_level")

	# 创建视觉精灵 - 怪物箱用 enemy 样式
	var visual = Sprite2D.new()
	visual.centered = true
	var tex = load("res://assets/ink/loot_box_enemy.png")
	if not tex:
		tex = load("res://assets/ink/loot_level1.png")
	if tex:
		visual.texture = tex
	add_child(visual)

	# 碰撞
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

	# 如果 enemy.gd 已经通过 set_meta("loot_items") 注入，直接使用
	if has_meta("loot_items"):
		var raw = get_meta("loot_items")
		_opened = true
		# 格式化：统一为纯单格格式，分配固定位置
		var iid = 1
		var row = 0
		var col = 0
		for item in raw:
			var count = item.get("amount", 1)
			if item.has("item_id"):
				# 已有 item_id 的格式化物品（直接使用）
				for _i in range(count):
					loot_items.append({
						"instance_id": randi(),
						"item_id": item["item_id"],
						"rarity": item.get("rarity", "common"),
						"row": row,
						"col": col,
						"searched": false,
					})
					iid += 1
					col += 1
					if col >= BOX_COLS:
						col = 0
						row += 1
			else:
				# 旧格式 {id, amount}
				for _i in range(count):
					loot_items.append({
						"instance_id": randi(),
						"item_id": item["id"],
						"rarity": item.get("rarity", "common"),
						"row": row,
						"col": col,
						"searched": false,
					})
					iid += 1
					col += 1
					if col >= BOX_COLS:
						col = 0
						row += 1

func _generate() -> void:
	if _opened:
		return
	_opened = true
	var raw = ItemDB.generate_loot(loot_level)
	var iid = 1
	var row = 0
	var col = 0
	for item in raw:
		var count = item.get("amount", 1)
		for _i in range(count):
			loot_items.append({
				"instance_id": randi(),
				"item_id": item["id"],
				"rarity": item.get("rarity", "common"),
				"row": row,
				"col": col,
				"searched": false,
			})
			iid += 1
			col += 1
			if col >= BOX_COLS:
				col = 0
				row += 1

func interact(player: Node) -> void:
	_generate()
	print("Open enemy box (level %d, %d items)" % [loot_level, loot_items.size()])
	var world = get_tree().current_scene
	if world.has_method("open_loot_ui"):
		world.call("open_loot_ui", loot_items, self)

func remove_item(instance_id: int) -> bool:
	for i in range(loot_items.size()):
		if loot_items[i]["instance_id"] == instance_id:
			loot_items.remove_at(i)
			return true
	return false

func add_item(item_data: Dictionary) -> void:
	"""添加新物品到箱子（找第一个空位）"""
	var row = 0
	var col = 0
	var occupied = {}
	for item in loot_items:
		occupied[Vector2i(item["row"], item["col"])] = true
	
	while occupied.has(Vector2i(row, col)):
		col += 1
		if col >= BOX_COLS:
			col = 0
			row += 1
	
	item_data["row"] = row
	item_data["col"] = col
	item_data["searched"] = true
	loot_items.append(item_data)

func sync_items(items: Array) -> void:
	loot_items = items

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_generate()
		if loot_items.size() > 0:
			print("F to open (%d items)" % loot_items.size())
		else:
			print("Enemy box empty")

func _on_body_exited(_body: Node2D) -> void:
	pass
