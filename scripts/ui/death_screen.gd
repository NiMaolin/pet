## DeathScreen - 撤离失败界面
extends Control

var can_return: bool = false

func _ready() -> void:
	print("=== 撤离失败界面加载 ===")
	GameData.clear_inventory()
	GameData.is_in_game = false
	# 延迟两帧，防止死亡时的按键穿透
	await get_tree().process_frame
	await get_tree().process_frame
	can_return = true

func _input(event: InputEvent) -> void:
	if not can_return:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_return_to_prep()
	elif event is InputEventMouseButton and event.pressed:
		_return_to_prep()

func _return_to_prep() -> void:
	if not can_return:
		return
	can_return = false
	print("返回准备界面")
	get_tree().change_scene_to_file("res://scenes/ui/prep_screen.tscn")
