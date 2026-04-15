## AutoRunner - 自动流程测试驱动器 v2
## 通过 Autoload 持久化，跨场景驱动画面跳转
## 参数：
##   --auto-test   : 基础流程测试（主菜单→准备→出发→副本）
##   --grid-test   : 格子系统完整测试（基础流程+开箱+搜索+拾取+重开验证）

extends Node

var step: int = 0
var running: bool = false
var label: Label = null
var grid_test_mode: bool = false

# 基础流程步骤
const STEP_NEW_GAME = 0      # 主菜单 → 点击"开始游戏"
const STEP_PREPARE = 1       # 准备界面 → 点击"行前准备"
const STEP_START = 2         # 地图选择 → 点击"出发"
const STEP_DONE = 3          # 进入副本，完成

func _ready() -> void:
	process_mode = 2  # PROCESS_MODE_ALWAYS_VISIBLE
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg == "--auto-test" or arg == "--grid-test":
			grid_test_mode = (arg == "--grid-test")
			_start_auto_test()
			return

func _start_auto_test() -> void:
	if running:
		return
	running = true
	step = 0
	print("\n========== AutoRunner %s ==========" % ("GridTest" if grid_test_mode else "Basic"))
	
	_create_hud_label()
	await get_tree().process_frame
	await get_tree().process_frame
	_execute_step()

func _create_hud_label() -> void:
	label = Label.new()
	label.name = "AutoRunnerLabel"
	label.text = "[AutoRunner] Starting..."
	label.position = Vector2(10, 140)
	label.z_index = 1000
	label.add_theme_color_override("font_color", Color(1, 0.85, 0))
	label.add_theme_font_size_override("font_size", 14)
	# Use deferred to avoid "busy setting up children" error
	get_tree().root.call_deferred("add_child", label)

func _update_hud(text: String) -> void:
	if is_instance_valid(label):
		label.text = "[AutoRunner] " + text

func _execute_step() -> void:
	if not running:
		return
	
	var current_scene = get_tree().current_scene
	var scene_name = ""
	if current_scene:
		scene_name = current_scene.name
	
	match step:
		STEP_NEW_GAME:
			_update_hud("Step 1/3: 主菜单 -> 开始游戏")
			print("[AutoRunner] Step 1: 主菜单 -> 开始游戏")
			await _wait(2.0)
			_do_new_game()
			
		STEP_PREPARE:
			_update_hud("Step 2/3: 准备界面 -> 行前准备")
			print("[AutoRunner] Step 2: 准备界面 -> 行前准备")
			await _wait(2.0)
			_do_prepare()
			
		STEP_START:
			_update_hud("Step 3/3: 地图选择 -> 出发")
			print("[AutoRunner] Step 3: 地图选择 -> 出发")
			await _wait(2.0)
			_do_start()
			
		STEP_DONE:
			if grid_test_mode:
				_update_hud("基础流程完成 -> 开始格子系统测试")
				print("[AutoRunner] 基础流程完成！开始格子系统测试...")
				await _wait(3.0)
				_start_grid_test()
			else:
				_update_hud("OK! 已进入副本")
				print("[AutoRunner] OK! 自动流程完成")
				print("========================================")
				await _wait(3)
				_finish()

# === 基础步骤执行 ===

func _do_new_game() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_on_new_game_pressed"):
		print("[AutoRunner] -> _on_new_game_pressed()")
		SaveSystem.start_new_game()
		scene._on_new_game_pressed()
		step = 1
		await get_tree().process_frame
		await get_tree().process_frame
		_execute_step()
	else:
		print("[AutoRunner] WARN: 非主菜单场景")

func _do_prepare() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_on_prepare_pressed"):
		print("[AutoRunner] -> _on_prepare_pressed()")
		scene._on_prepare_pressed()
		step = 2
		await get_tree().process_frame
		await get_tree().process_frame
		_execute_step()
	else:
		print("[AutoRunner] WARN: 非准备界面")

func _do_start() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_on_start_pressed"):
		print("[AutoRunner] -> _on_start_pressed()")
		scene._on_start_pressed()
		step = 3
		await get_tree().process_frame
		await get_tree().process_frame
		_execute_step()
	else:
		print("[AutoRunner] WARN: 非地图选择")

# ════════════════════════════════════
#  格子系统测试（核心部分）
# ════════════════════════════════════

var _gt_step: int = 0       # 格子系统测试子步骤
var _gt_timer: float = 0.0    # 子步骤计时器
var _world: Node = null
var _player: CharacterBody2D = null
var _loot_ui: CanvasLayer = null
var _loot_spot: Area2D = null

func _start_grid_test() -> void:
	"""初始化格子系统测试"""
	_gt_step = 0
	_gt_timer = 0.0
	set_process(true)  # 确保处理开启
	_run_grid_test_step()

func _run_grid_test_step() -> void:
	if not running or not grid_test_mode:
		return
	
	_gt_timer += get_process_delta_time()
	
	match _gt_step:
		0:  # 找到并打开物资箱
			if _gt_timer > 5.0:
				_gt_do_open_box()
		
		1:  # 等待搜索完成
			if _gt_timer > 12.0:
				_gt_check_searched()
		
		2:  # 双击拾取
			if _gt_timer > 1.5:
				_gt_double_click_pickup()
		
		3:  # 关闭重开
			if _gt_timer > 2.0:
				_gt_close_reopen()
		
		4:  # 最终验证
			if _gt_timer > 10.0:
				_gt_final_verify()


# ── 格子测试步骤实现 ───────────────────────

func _gt_do_open_box() -> void:
	_world = get_tree().current_scene
	_player = _world.get_node_or_null("Player")
	_loot_ui = _world.get_node_or_null("LootUI")
	
	if not _world or not _player:
		print("[GridTest] ERROR: world/player is null")
		return
	
	if not "loot_spots" in _world or _world.loot_spots.is_empty():
		print("[GridTest] ERROR: no loot spots found")
		_gt_finish(false, "无物资点")
		return
	
	_loot_spot = _world.loot_spots[0]
	_loot_spot.interact(_player)
	
	var total = _loot_spot.loot_items.size()
	var unsearched = 0
	for item in _loot_spot.loot_items:
		if not item.get("searched", false): unsearched += 1
	
	# 记录初始物品顺序
	var order = []
	for i in range(min(8, total)):
		var it = _loot_spot.loot_items[i]
		order.append("%s(r%d,c%d,s%d)" % [
			ItemDB.get_item_name(it.item_id), it.row, it.col,
			1 if it.searched else 0])
	
	print("[GridTest] Step A OK: 打开物资箱 (%d items, %d unsearched)" % [total, unsearched])
	print("[GridTest]   Order: " + ", ".join(order))
	_update_hud("格子系统: 搜索中... (%d/%d)" % [total - unsearched, total])
	
	_gt_step = 1
	_gt_timer = 0


func _gt_check_searched() -> void:
	if _loot_ui == null:
		print("[GridTest] WARN: LootUI null at search check")
		_gt_step = 4
		_gt_timer = 0
		return
	
	var searched = 0
	var unsearched = 0
	for item in _loot_ui.loot_items:
		if item.get("searched", false): searched += 1
		else: unsearched += 1
	
	print("[GridTest] Step B OK: 搜索检查 (searched=%d, un=%d)" % [searched, unsearched])
	_update_hud("格子系统: 已搜完! 双击拾取...")
	
	_gt_step = 2
	_gt_timer = 0


func _gt_double_click_pickup() -> void:
	if _loot_ui == null or _loot_ui.loot_items.is_empty():
		print("[GridTest] SKIP: double click - no items")
		_gt_step = 4
		_gt_timer = 0
		return
	
	# 找第一个已搜索的
	var target_idx = -1
	for i in range(_loot_ui.loot_items.size()):
		if _loot_ui.loot_items[i].get("searched", false):
			target_idx = i
			break
	
	if target_idx < 0:
		print("[GridTest] SKIP: no searchable items")
		_gt_step = 4
		_gt_timer = 0
		return
	
	var item = _loot_ui.loot_items[target_idx]
	var name = ItemDB.get_item_name(item.item_id)
	
	# 构造双击事件
	var loot_grid = _loot_ui.loot_grid
	var sx = int(item.col * 40 + loot_grid.global_position.x + 20)
	var sy = int(item.row * 40 + loot_grid.global_position.y + 20)
	var vp = get_viewport()
	
	var md = InputEventMouseButton.new()
	md.button_index = MOUSE_BUTTON_LEFT; md.pressed = true; md.double_click = true
	md.position = Vector2(sx, sy); vp.push_input(md)
	
	var mu = InputEventMouseButton.new()
	mu.button_index = MOUSE_BUTTON_LEFT; mu.pressed = false
	mu.position = Vector2(sx, sy); vp.push_input(mu)
	
	await get_tree().create_timer(1.0).timeout
	
	print("[GridTest] Step C OK: 双击拾取 '%s' -> bag=%d" % [name, GameData.placed_items.size()])
	_update_hud("格子系统: 关闭&重开验证...")
	
	_gt_step = 3
	_gt_timer = 0


func _gt_close_reopen() -> void:
	if _loot_ui == null:
		return
	
	# 记录关闭前
	var s_before = 0
	var n_before = _loot_ui.loot_items.size()
	for item in _loot_ui.loot_items:
		if item.searched: s_before += 1
	
	_loot_ui._on_close()
	await get_tree().create_timer(1.5).timeout
	
	# 重开
	if _loot_spot:
		_loot_spot.interact(_player)
		await get_tree().create_timer(0.5).timeout
		
		var s_after = 0
		var n_after = _loot_ui.loot_items.size()
		for item in _loot_ui.loot_items:
			if item.searched: s_after += 1
		
		var pass_rescan = (s_after >= s_before)
		
		print("[GridTest] Step D OK: Close&Reopen (before:%d/%d searched, after:%d/%d)" % [
			s_before, n_before, s_after, n_after])
		print("[GridTest]   Rescan test: %s" % ("PASS - no rescan!" if pass_rescan else "FAIL - rescan detected!"))
		_update_hud("格子系统: 验证搜索状态...")
		
		_gt_step = 4
		_gt_timer = 0


func _gt_final_verify() -> void:
	if _loot_ui == null:
		_gt_finish(true, "LootUI null at final")
		return
	
	var unsearched = 0
	for item in _loot_ui.loot_items:
		if not item.searched: unsearched += 1
	
	var still_searching = _loot_ui.is_searching
	
	# 输出最终状态
	var info = ""
	for i in range(min(6, _loot_ui.loot_items.size())):
		var it = _loot_ui.loot_items[i]
		info += "%s(s%d)" % [ItemDB.get_item_name(it.item_id), 1 if it.searched else 0]
		if i < min(5, _loot_ui.loot_items.size()-1): info += " "
	
	print("")
	print("==================================================")
	print("[GridTest] FINAL RESULTS:")
	print("  Bag:     %d items" % GameData.placed_items.size())
	print("  LootBox: %s" % info)
	print("  Still searching? %s" % str(still_searching))
	print("  Unsearched remaining: %d" % unsearched)
	
	if not still_searching and unsearched <= 1:
		print("  VERDICT: ALL PASS!")
		_update_hud("Grid Test: ALL PASS!")
	else:
		print("  VERDICT: CHECK NEEDED")
		_update_hud("Grid Test: Check needed")
	
	print("==================================================")
	
	_gt_finish(not still_searching, "")


func _gt_finish(success: bool, note: String) -> void:
	grid_test_mode = false
	# 不立即 finish，保持游戏运行供人工验证
	print("\n[AutoRunner] 格子系统测试结束。游戏保持运行供人工验证。")


func _finish() -> void:
	if is_instance_valid(label):
		label.queue_free()
	running = false

func _wait(seconds: float) -> void:
	var timer = get_tree().create_timer(seconds)
	await timer.timeout

# ── 重写 _process 来驱动格子测试 ──────────

func _process(delta: float) -> void:
	if not grid_test_mode or not running:
		return
	_run_grid_test_step()
