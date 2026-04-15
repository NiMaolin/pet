## VerifyTest - Godot 内置验证脚本（autoload）
## 启动后自动运行，生成截图和日志后退出
extends Node

var screenshot_count = 0
var test_started = false

func _ready() -> void:
	print("=== VerifyTest: Starting verification ===")
	test_started = true

	# 等待一帧让场景完全加载
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	run_verification()

func run_verification() -> void:
	print("--- VerifyTest: Running checks ---")

	# 1. 检查玩家节点
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		print("OK player found at: ", player.global_position)
		# 检查玩家的 sprite
		if player.has_node("AnimatedSprite2D"):
			var sprite = player.get_node("AnimatedSprite2D")
			print("OK player has AnimatedSprite2D: ", sprite.sprite_frames.get_animation_names() if sprite.sprite_frames else "NO FRAMES")
		elif player.has("sprite"):
			var sprite = player.get("sprite")
			if sprite:
				print("OK player has sprite: ", sprite.texture.resource_path if sprite.texture else "NO TEXTURE")
		else:
			print("WARN player has no sprite node")
	else:
		print("FAIL no player in group 'player'")

	# 2. 检查敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("OK enemies count: ", enemies.size())
	for e in enemies:
		print("  enemy at: ", e.global_position, " type: ", e.get("enemy_type"))
		if e.has("sprite"):
			var sp = e.get("sprite")
			if sp:
				print("  enemy sprite: ", sp.texture.resource_path if sp.texture else "NO TEXTURE")

	# 3. 手动生成一个 loot box 来测试
	print("--- Creating test loot box ---")
	var test_box = Area2D.new()
	test_box.global_position = Vector2(100, 100)
	test_box.script = preload("res://scripts/world/loot_box.gd")
	test_box.set_meta("loot_items", [{"item_id": 1, "instance_id": 999, "rarity": "common", "shape_key": "1x1"}])
	get_tree().current_scene.add_child(test_box)
	await get_tree().process_frame

	# 4. 检查 loot box 的 sprite
	await get_tree().create_timer(0.2).timeout
	print("OK test loot box created")
	var box_children = test_box.get_children()
	for child in box_children:
		print("  loot_box child: ", child.name, " type=", child.get_class())
		if child is Sprite2D:
			print("    texture: ", child.texture.resource_path if child.texture else "NONE")
			print("    centered: ", child.centered)
			print("    global_pos: ", child.global_position)

	# 5. 截图（Godot 4 可以用 viewport 的 get_texture().get_image()）
	print("--- Taking screenshot ---")
	var vp = get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			var screenshot_path = "user://verify_screenshot.png"
			var err = img.save_png(screenshot_path)
			print("OK screenshot saved: ", screenshot_path, " err=", err)

	# 6. 输出文件内容到 log
	var user_dir = "user://"
	print("--- File system check ---")
	var dir = DirAccess.open(user_dir)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			print("  file: ", f)
			f = dir.get_next()

	# 等待一下再退出
	await get_tree().create_timer(1.0).timeout
	print("=== VerifyTest: Done, exiting ===")
	get_tree().quit()
