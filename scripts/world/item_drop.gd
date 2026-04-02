## ItemDrop - 物品掉落
extends Area2D

var item_id: int = 0
var amount: int = 1

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

	# 从 meta 读取数据
	if has_meta("item_id"):
		item_id = get_meta("item_id")
	if has_meta("amount"):
		amount = get_meta("amount")

	# 设置颜色
	if sprite and item_id > 0:
		sprite.color = ItemDB.get_item_color(item_id)

func interact(player: Node) -> void:
	if GameData.add_item_to_inventory(item_id, amount):
		var item_name = ItemDB.get_item_name(item_id)
		print("✅ 拾取: %s x%d" % [item_name, amount])
		queue_free()
	else:
		print("❌ 背包已满！")

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var item_name = ItemDB.get_item_name(item_id)
		print("按 F 拾取: %s" % item_name)

func _on_area_exited(area: Area2D) -> void:
	pass
