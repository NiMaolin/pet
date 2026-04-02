extends Control
@onready var pet_count_label: Label    = $Panel/VBox/HBox/InfoPanel/VBox/PetCount
@onready var item_count_label: Label   = $Panel/VBox/HBox/InfoPanel/VBox/ItemCount
@onready var time_label: Label         = $Panel/VBox/HBox/InfoPanel/VBox/PlayTime
@onready var equipped_pet_label: Label = $Panel/VBox/HBox/InfoPanel/VBox/EquippedPet
@onready var save_dialog: CanvasLayer  = $SaveDialog
@onready var slot_btn_0: Button        = $SaveDialog/Panel/Margin/VBox/Slot0/SlotBtn0
@onready var slot_btn_1: Button        = $SaveDialog/Panel/Margin/VBox/Slot1/SlotBtn1
@onready var slot_btn_2: Button        = $SaveDialog/Panel/Margin/VBox/Slot2/SlotBtn2
@onready var close_btn: Button         = $SaveDialog/Panel/Margin/VBox/TitleRow/CloseBtn
@onready var status_label: Label       = $SaveDialog/Panel/Margin/VBox/StatusLabel
@onready var warehouse_ui: CanvasLayer = $WarehouseUI

func _ready() -> void:
	print("=== 准备界面加载 ===")
	_connect_buttons()
	_update_info()
	slot_btn_0.pressed.connect(func(): _do_save(0))
	slot_btn_1.pressed.connect(func(): _do_save(1))
	slot_btn_2.pressed.connect(func(): _do_save(2))
	close_btn.pressed.connect(_close_save_dialog)
	warehouse_ui.closed.connect(_update_info)

func _connect_buttons() -> void:
	# 连接按钮信号
	var warehouse_btn = get_node_or_null("Panel/VBox/HBox/ButtonPanel/VBox/Warehouse")
	var pet_dex_btn = get_node_or_null("Panel/VBox/HBox/ButtonPanel/VBox/PetDex")
	var prepare_btn = get_node_or_null("Panel/VBox/HBox/ButtonPanel/VBox/Prepare")
	var save_btn = get_node_or_null("Panel/VBox/HBox2/Save")
	var back_btn = get_node_or_null("Panel/VBox/HBox2/MainMenu")
	
	if warehouse_btn: warehouse_btn.pressed.connect(_on_warehouse_pressed)
	if pet_dex_btn: pet_dex_btn.pressed.connect(_on_pet_dex_pressed)
	if prepare_btn: prepare_btn.pressed.connect(_on_prepare_pressed)
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	if back_btn: back_btn.pressed.connect(_on_main_menu_pressed)
func _update_info() -> void:
	pet_count_label.text = "已收集宠物: %d" % GameData.collected_pets.size()
	item_count_label.text = "仓库物品: %d 件" % GameData.warehouse.size()
	var pt = int(GameData.play_time)
	time_label.text = "游戏时长: %02d:%02d" % [pt / 60, pt % 60]
	if GameData.equipped_pet_id != 0:
		var pet = PetDB.get_pet(GameData.equipped_pet_id)
		equipped_pet_label.text = "已装备宠物: %s" % pet.get("name", "未知")
	else:
		equipped_pet_label.text = "已装备宠物: 无"
func _on_warehouse_pressed() -> void:
	warehouse_ui.open_warehouse()
func _on_save_pressed() -> void:
	_open_save_dialog()
func _open_save_dialog() -> void:
	status_label.text = ""
	_refresh_slot_labels()
	save_dialog.visible = true
func _close_save_dialog() -> void:
	save_dialog.visible = false
func _refresh_slot_labels() -> void:
	for i in range(3):
		var btn = _get_slot_btn(i)
		var info = SaveSystem.get_save_info(i)
		if info.get("exists", false):
			var prefix = "★ " if i == GameData.last_save_slot else ""
			btn.text = "%s槽位 %d\n%s  |  时长 %s  |  宠物 %d 只" % [
				prefix, i + 1,
				info.get("date", ""),
				info.get("play_time", "00:00"),
				info.get("pet_count", 0)]
		else:
			btn.text = "槽位 %d\n（空存档）" % (i + 1)
func _get_slot_btn(i: int) -> Button:
	match i:
		0: return slot_btn_0
		1: return slot_btn_1
		2: return slot_btn_2
	return slot_btn_0
func _do_save(slot: int) -> void:
	var ok = SaveSystem.save_game(slot)
	if ok:
		status_label.text = "✅ 已保存到槽位 %d！" % (slot + 1)
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_refresh_slot_labels()
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(save_dialog):
			_close_save_dialog()
	else:
		status_label.text = "❌ 保存失败，请重试"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
func _on_pet_dex_pressed() -> void: print("打开图鉴")
func _on_prepare_pressed() -> void:
	print("=== 点击行前准备 ===")
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
