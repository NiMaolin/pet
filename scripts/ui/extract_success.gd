## ExtractSuccess - 撤离成功界面
extends Control

var can_return: bool = false  # 防止同帧 F 键穿透

func _ready() -> void:
	_update_stats()
	# 延迟一帧再允许按键，防止撤离时的 F 键穿透
	await get_tree().process_frame
	await get_tree().process_frame
	can_return = true

func _update_stats() -> void:
	$Panel/VBox/ItemsLabel.text = "带回物品: %d 种" % GameData.warehouse.size()
	$Panel/VBox/PetsLabel.text = "已收集宠物: %d 只" % GameData.collected_pets.size()
	var pt = int(GameData.play_time)
	$Panel/VBox/TimeLabel.text = "游戏时长: %02d:%02d" % [pt / 60, pt % 60]

func _input(event: InputEvent) -> void:
	if not can_return:
		return
	# 只响应按下事件，不响应持续按住
	if event is InputEventKey and event.pressed and not event.echo:
		_return_to_prep()
	elif event is InputEventMouseButton and event.pressed:
		_return_to_prep()

func _return_to_prep() -> void:
	if not can_return:
		return
	can_return = false  # 防止重复触发
	print("返回准备界面")
	get_tree().change_scene_to_file("res://scenes/ui/prep_screen.tscn")
