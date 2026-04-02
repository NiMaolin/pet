## FlowTest - 流程测试
extends Node

var log_text: String = ""

func _ready() -> void:
	print("=== 流程测试开始 ===")
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout

	# 1. 主菜单 -> 准备界面
	var scene = get_tree().current_scene
	var btn = scene.find_child("NewGame", true, true)
	if btn: btn.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout
	log_text += "准备界面: %s\n" % get_tree().current_scene.name

	# 2. 测试保存按钮
	scene = get_tree().current_scene
	var save_btn = scene.find_child("Save", true, true)
	log_text += "Save按钮: %s\n" % ("找到" if save_btn else "未找到")
	if save_btn:
		save_btn.emit_signal("pressed")
		await get_tree().create_timer(0.5).timeout
		# 检查存档对话框是否打开
		var save_dialog = scene.get_node_or_null("SaveDialog")
		log_text += "存档对话框可见: %s\n" % (save_dialog.visible if save_dialog else "节点不存在")
		# 关闭对话框
		if save_dialog and save_dialog.visible:
			var close = save_dialog.find_child("CloseBtn", true, true)
			if close: close.emit_signal("pressed")

	# 3. 测试返回主菜单
	var back_btn = scene.find_child("MainMenu", true, true)
	log_text += "MainMenu按钮: %s\n" % ("找到" if back_btn else "未找到")
	if back_btn:
		back_btn.emit_signal("pressed")
		await get_tree().create_timer(1.5).timeout
		log_text += "返回后场景: %s\n" % get_tree().current_scene.name

	# 4. 重新进入游戏测试撤离
	scene = get_tree().current_scene
	btn = scene.find_child("NewGame", true, true)
	if btn: btn.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout
	scene = get_tree().current_scene
	var prepare = scene.find_child("Prepare", true, true)
	if prepare: prepare.emit_signal("pressed")
	await get_tree().create_timer(1.5).timeout
	scene = get_tree().current_scene
	var start = scene.find_child("Start", true, true)
	if start: start.emit_signal("pressed")
	await get_tree().create_timer(2.0).timeout

	# 5. 测试撤离（移动玩家到撤离点）
	var world = get_tree().current_scene
	log_text += "游戏世界: %s\n" % world.name
	var player = world.get_node_or_null("Player")
	var escape_nodes = get_tree().get_nodes_in_group("escape_point")
	log_text += "撤离点数量: %d\n" % escape_nodes.size()
	if player and escape_nodes.size() > 0:
		var ep = escape_nodes[0]
		player.global_position = ep.global_position
		log_text += "玩家移到撤离点: %s\n" % ep.global_position
		await get_tree().create_timer(2.5).timeout
		log_text += "撤离后场景: %s\n" % get_tree().current_scene.name

	# 截图
	var img = get_viewport().get_texture().get_image()
	img.save_png("D:\\youxi\\soudache\\flow_test.png")
	log_text += "截图已保存\n"

	var f = FileAccess.open("D:\\youxi\\soudache\\flow_report.txt", FileAccess.WRITE)
	f.store_string(log_text)
	f.close()
	print("=== 测试完成 ===")
	print(log_text)
	get_tree().quit()
