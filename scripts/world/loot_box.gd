extends Area2D

var loot_level: int = 1
var loot_items: Array = []
var _opened: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("loot_spot")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	if has_meta("loot_level"):
		loot_level = get_meta("loot_level")

func _generate() -> void:
	if _opened:
		return
	_opened = true
	var raw = ItemDB.generate_loot(loot_level)
	var iid = 1
	for item in raw:
		var count = item.get("amount", 1)
		for _i in range(count):
			loot_items.append({
				"instance_id": randi(),
				"item_id": item["id"],
				"rarity": item.get("rarity", "common"),
				"shape_key": ItemDB.get_item(item["id"]).get("shape", "1x1"),
			})
			iid += 1

func interact(player: Node) -> void:
	_generate()
	print("Open box (level %d, %d items)" % [loot_level, loot_items.size()])
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
	loot_items.append(item_data)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_generate()
		if loot_items.size() > 0:
			print("F to open (remaining %d items)" % loot_items.size())
		else:
			print("Box empty - can return items")

func _on_body_exited(_body: Node2D) -> void:
	pass
