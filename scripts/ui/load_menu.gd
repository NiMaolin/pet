## LoadMenu - 读取存档界面
extends Control

@onready var slot_btns: Array = []

func _ready() -> void:
	print("=== 读取存档界面加载 ===")
	# 动态获取三个槽位按钮
	slot_btns = [
		$Panel/VBox/Slot1,
		$Panel/VBox/Slot2,
		$Panel/VBox/Slot3,
	]
	_refresh_slots()

func _refresh_slots() -> void:
	for i in range(3):
		var info = SaveSystem.get_save_info(i)   # 槽位 0/1/2
		var btn = slot_btns[i]
		if info.get("exists", false):
			var prefix = "★ " if i == GameData.last_save_slot else ""
			btn.text = "%s槽位 %d\n%s  |  时长 %s  |  宠物 %d 只" % [
				prefix,
				i + 1,
				info.get("date", ""),
				info.get("play_time", "00:00"),
				info.get("pet_count", 0),
			]
			btn.disabled = false
		else:
			btn.text = "槽位 %d\n（空存档）" % (i + 1)
			btn.disabled = true

func _on_slot1_pressed() -> void:
	_load_slot(0)

func _on_slot2_pressed() -> void:
	_load_slot(1)

func _on_slot3_pressed() -> void:
	_load_slot(2)

func _load_slot(slot: int) -> void:
	if SaveSystem.load_game(slot):
		print("✅ 加载存档槽位 %d 成功" % (slot + 1))
		get_tree().change_scene_to_file("res://scenes/ui/prep_screen.tscn")
	else:
		print("❌ 存档槽位 %d 不存在或读取失败" % (slot + 1))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
