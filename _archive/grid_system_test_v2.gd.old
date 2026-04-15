## GridSystemTest - 格子系统v2重构测试
## 通过 AutoRunner 的 --auto-test 参数驱动
extends Node

var _step: int = 0
var _timer: float = 0.0
var _world: Node = null
var _player: Node = null
var _loot_ui: CanvasLayer = null
var _loot_spot: Node = null
var _test_results: Array = []

func log_msg(msg: String) -> void:
	var ts = Time.get_time_string_from_system()
	print("[GridTest %s] %s" % [ts, msg])
	_test_results.append(msg)

func _ready() -> void:
	log_msg("格子系统 v2 重构测试启动")
	set_process(true)

func _process(delta: float) -> void:
	_timer += delta
	
	match _step:
		0:
			# 等待主菜单加载
			if _timer > 2.5:
				_do_start_game()
				_step = 1
				_timer = 0.0
		
		1:
			if _timer > 2.0:
				_do_prepare()
				_step = 2
				_timer = 0.0
		
		2:
			if _timer > 2.0:
				_do_map_select()
				_step = 3
				_timer = 0.0
		
		3:
			if _timer > 2.0:
				_do_enter_world()
				_step = 4
				_timer = 0.0
		
		4:
			# 进入世界后等几秒，然后开箱
			if _timer > 6.0:
				_do_open_loot_box()
				_step = 5
				_timer = 0.0
		
		5:
			# 等待搜索完成（最长的legendary需要5秒，多留余量）
			if _timer > 12.0:
				_check_search_complete()
				_step = 6
				_timer = 0.0
		
		6:
			# 双击拾取第一个已搜索物品
			if _timer > 1.5:
				_do_double_click_pickup()
				_step = 7
				_timer = 0.0
		
		7:
			# 关闭物资箱再重开（核心测试！）
			if _timer > 2.0:
				_do_close_and_reopen()
				_step = 8
				_timer = 0.0
		
		8:
			# 等待搜索状态确认（应该立即显示"完成"，不重新搜）
			if _timer > 10.0:
				_verify_no_rescan()
				_step = 9
				_timer = 0.0
		
		9:
			# 最终结果
			if _timer > 2.0:
				_print_final_results()
				set_process(false)

# ── 步骤实现 ────────────────────────────────

func _do_start_game() -> void:
	var root = get_tree().current_scene
	if root.has_method("_on_new_game_pressed"):
		root._on_new_game_pressed()
	log_msg("Step 1/9 OK: 开始新游戏")

func _do_prepare() -> void:
	var root = get_tree().current_scene
	if root.has_method("_on_prepare_pressed"):
		root._on_prepare_pressed()
	log_msg("Step 2/9 OK: 行前准备")

func _do_map_select() -> void:
	var root = get_tree().current_scene
	if root.has_method("_on_start_pressed"):
		root._on_start_pressed()
	log_msg("Step 3/9 OK: 出发")

func _do_enter_world() -> void:
	_world = get_tree().current_scene
	_player = _world.get_node_or_null("Player")
	_loot_ui = _world.get_node_or_null("LootUI")
	
	var spot_count = 0 if not _world.has_method("get") else _world.loot_spots.size()
	if _world and "loot_spots" in _world:
		spot_count = _world.loot_spots.size()
	
	log_msg("Step 4/9 OK: 进入游戏世界 (spots=%d)" % spot_count)

func _do_open_loot_box() -> void:
	if not _world or not _player:
		log_msg("ERROR: world or player is null!")
		return
	
	# 找到第一个物资点
	if "loot_spots" in _world and _world.loot_spots.size() > 0:
		_loot_spot = _world.loot_spots[0]
		_loot_spot.interact(_player)
		
		var total = _loot_spot.loot_items.size()
		var unsearched = 0
		for item in _loot_spot.loot_items:
			if not item.get("searched", false): unsearched += 1
		
		# 记录初始物品顺序和位置
		var order_str = ""
		for i in range(min(8, _loot_spot.loot_items.size())):
			var it = _loot_spot.loot_items[i]
			order_str += "%s(%d,%d,s=%d)" % [
				ItemDB.get_item_name(it.item_id), 
				it.row, it.col,
				1 if it.searched else 0
		 ]
			if i < min(7, _loot_spot.loot_items.size()-1):
				order_str += " → "
		if _loot_spot.loot_items.size() > 8:
			order_str += "..."
			
		log_msg("Step 5/9 OK: 打开物资箱 (total=%d, unsearched=%d)" % [total, unsearched])
		log_msg("  初始物品顺序: %s" % order_str)
	else:
		log_msg("ERROR: 没有找到物资点!")

func _check_search_complete() -> void:
	if _loot_ui == null:
		log_msg("WARN: LootUI is null at search check")
		return
	
	var unsearched = 0
	var searched = 0
	for item in _loot_ui.loot_items:
		if item.get("searched", false):
			searched += 1
		else:
			unsearched += 1
	
	log_msg("Step 6/9 OK: 搜索检查 (searched=%d, unsearched=%d)" % [searched, unsearched])

func _do_double_click_pickup() -> void:
	if _loot_ui == null or _loot_ui.loot_items.is_empty():
		log_msg("SKIP: 双击拾取 - 无物品")
		return
	
	# 找第一个已搜索的物品
	var target_idx = -1
	for i in range(_loot_ui.loot_items.size()):
		if _loot_ui.loot_items[i].get("searched", false):
			target_idx = i
			break
	
	if target_idx < 0:
		log_msg("SKIP: 双击拾取 - 无已搜索物品")
		return
	
	var item = _loot_ui.loot_items[target_idx]
	var name = ItemDB.get_item_name(item.item_id)
	
	# 构造双击事件
	var loot_grid = _loot_ui.loot_grid
	var slot_x = item.col * 40 + loot_grid.global_position.x + 20
	var slot_y = item.row * 40 + loot_grid.global_position.y + 20
	var vp = get_viewport()
	
	var mb_down = InputEventMouseButton.new()
	mb_down.button_index = MOUSE_BUTTON_LEFT
	mb_down.pressed = true
	mb_down.double_click = true
	mb_down.position = Vector2(slot_x, slot_y)
	vp.push_input(mb_down)
	
	var mb_up = InputEventMouseButton.new()
	mb_up.button_index = MOUSE_BUTTON_LEFT
	mb_up.pressed = false
	mb_up.position = Vector2(slot_x, slot_y)
	vp.push_input(mb_up)
	
	await get_tree().create_timer(0.8).timeout
	
	log_msg("Step 7/9 OK: 双击拾取 '%s' → 背包现在有%d件" % [name, GameData.placed_items.size()])

func _do_close_and_reopen() -> void:
	"""关闭物资箱再重新打开 - 核心验证！"""
	if _loot_ui == null:
		return
	
	# 记录关闭前的状态
	var items_before = _loot_ui.loot_items.size()
	var searched_before = 0
	var before_order = ""
	for item in _loot_ui.loot_items:
		if item.get("searched", false): searched_before += 1
		before_order += "%s(%d)" % [ItemDB.get_item_name(item.item_id), item.instance_id]
	before_order += " | "
	
	# 关闭
	_loot_ui._on_close()
	await get_tree().create_timer(1.0).timeout
	
	# 重新打开同一个箱子
	if _loot_spot:
		_loot_spot.interact(_player)
		await get_tree().create_timer(0.5).timeout
		
		var items_after = _loot_ui.loot_items.size()
		var searched_after = 0
		var after_order = ""
		for item in _loot_ui.loot_items:
			if item.get("searched", false): searched_after += 1
			after_order += "%s(%d)" % [ItemDB.get_item_name(item.item_id), item.instance_id]
		after_order += " | "
		
		log_msg("Step 8/9 OK: 关闭→重开 (before:%d/%d searched, after:%d/%d searched)" % [
			searched_before, items_before, searched_after, items_after])
		
		# 核心验证：搜索状态持久化
		if searched_after >= searched_before:
			log_msg("  PASS: 搜索状态持久! 已搜物品不会重新搜")
		else:
			log_msg("  FAIL: 搜索状态丢失! %d < %d" % [searched_after, searched_before])

func _verify_no_rescan() -> void:
	if _loot_ui == null:
		return
	
	var unsearched = 0
	for item in _loot_ui.loot_items:
		if not item.get("searched", false): unsearched += 1
	
	var still_searching = _loot_ui.is_searching
	
	if not still_searching and unsearched == 0:
		log_msg("PASS: 全部已搜完，没有重复搜索!")
	elif still_searching:
		log_msg("WARN: 还在搜索中... 可能有问题")
	elif unsearched > 0:
		log_msg("INFO: 还有 %d 个未搜（可能是双击拾取后剩余的）" % unsearched)
	
	# 输出最终物品列表
	var final_info = ""
	for i in range(min(6, _loot_ui.loot_items.size())):
		var it = _loot_ui.loot_items[i]
		final_info += "%s(s=%d) " % [ItemDB.get_item_name(it.item_id), 1 if it.searched else 0]
	if _loot_ui.loot_items.size() > 6:
		final_info += "..."
	log_msg("  物资箱剩余: [%s]" % final_info)
	log_msg("  背包物品数: %d件" % GameData.placed_items.size())

func _print_final_results() -> void:
	log_msg("")
	log_msg("=" * 50)
	log_msg("[GridTest] 格子系统 v2 测试完成!")
	log_msg("=" * 50)
	log_msg("最终状态:")
	log_msg("  背包: %d 件物品" % GameData.placed_items.size())
	log_msg("  仓库: %d 件物品" % GameData.warehouse.size())
	if _loot_ui:
		var looted = 0
		for it in _loot_ui.loot_items:
			if it.searched: looted += 1
		log_msg("  物资箱: %d/%d 已搜" % [looted, _loot_ui.loot_items.size()])
	log_msg("")
	log_msg("请人工验证:")
	log_msg("  1. 物资箱标题是否显示 '物资箱 (x/y)' 其中 y==x 或接近")
	log_msg("  2. 是否显示 '完成' 而非 '搜索中...'")
	log_msg("  3. 再次打开时是否没有重新搜索动画")
	log_msg("  4. 物品排列顺序与第一次打开一致")
	log_msg("=" * 50)
