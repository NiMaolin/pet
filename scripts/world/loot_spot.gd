## LootSpot - 物资箱（水墨风格贴图版）
extends Area2D

var spot_id: int = 0
var loot_level: int = 1
var loot_items: Array = []
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

	# 创建水墨风格物资箱贴图
	visual = Sprite2D.new()
	visual.centered = false
	
	var tex_path = "res://assets/ink/loot_level" + str(loot_level) + ".png"
	var tex = load(tex_path)
	if tex:
		visual.texture = tex
	else:
		print("⚠️ 未找到贴图: " + tex_path)
	
	add_child(visual)
	
	# 碰撞
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

func _ensure_generated() -> void:
	if _generated:
		return
	_generated = true
	var raw = ItemDB.generate_loot(loot_level)
	var iid = 1
	for item in raw:
		var count = item.get("amount", 1)
		for _i in range(count):
			loot_items.append({
				"instance_id": (spot_id * 10000) + iid,
				"item_id": item["id"],
				"rarity": item.get("rarity", "common"),
				"shape_key": ItemDB.get_item(item["id"]).get("shape", "1x1"),
			})
			iid += 1

func interact(player: Node) -> void:
	_ensure_generated()
	print("Open box %d (level %d, %d items)" % [spot_id, loot_level, loot_items.size()])
	var world = get_tree().current_scene
	if world.has_method("open_loot_ui"):
		world.call("open_loot_ui", loot_items, self)

func remove_item(instance_id: int) -> bool:
	for i in range(loot_items.size()):
		if loot_items[i]["instance_id"] == instance_id:
			loot_items.remove_at(i)
			_update_visual()
			return true
	return false

func add_item(item_data: Dictionary) -> void:
	loot_items.append(item_data)
	_update_visual()

func _update_visual() -> void:
	if visual:
		var tex_path = "res://assets/ink/loot_level" + str(loot_level) + ".png"
		if not loot_items.is_empty():
			var tex = load(tex_path)
			if tex:
				visual.texture = tex

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_ensure_generated()
		if loot_items.size() > 0:
			print("F to open (remaining %d items)" % loot_items.size())
		else:
			print("Box empty - can return items")

func _on_body_exited(_body: Node2D) -> void:
	pass
