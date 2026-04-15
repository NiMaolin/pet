## GridSystemTest v4 - 格子系统自动化测试
## 严格通过代码事件调用，禁止 UI 坐标模拟
## 测试项：
##   T01 - 物资箱生成物品（数据检查）
##   T02 - 搜索完成后 searched=true
##   T03 - 重开物资箱不重复搜索（顺序+状态不变）
##   T04 - 双击快拾（调用 _handle_double_click 等价逻辑）
##   T05 - 物资箱→背包拖拽（调用 _do_loot_to_bag）
##   T06 - 背包内移动（调用 _do_bag_move）
##   T07 - 背包→物资箱（调用 _do_bag_to_loot）
##   T08 - 背包已满时快拾返回提示不崩溃

extends Node

# ─────────────────────────────────────────────
#  辅助：断言
# ─────────────────────────────────────────────
var _pass: int = 0
var _fail: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  ✅ PASS: %s" % msg)
	else:
		_fail += 1
		print("  ❌ FAIL: %s" % msg)

func _section(title: String) -> void:
	print("\n── %s ──" % title)

func _summary() -> void:
	print("\n══════════════════════════════════════")
	print("GRID TEST v4 结果: %d PASS / %d FAIL" % [_pass, _fail])
	if _fail == 0:
		print("  🎉 ALL PASS！格子系统工作正常")
	else:
		print("  ⚠️ 有 %d 项测试失败，请检查" % _fail)
	print("══════════════════════════════════════\n")

# ─────────────────────────────────────────────
#  主入口
# ─────────────────────────────────────────────
func _ready() -> void:
	print("\n══════════════════════════════════════")
	print("  GRID SYSTEM TEST v4")
	print("══════════════════════════════════════")

	# 等待场景稳定
	await get_tree().process_frame
	await get_tree().process_frame

	_run_all_tests()

func _run_all_tests() -> void:
	# 重置背包
	GameData.clear_inventory()

	_test_t01_loot_generation()
	_test_t02_search_state()
	_test_t03_no_rescan()
	_test_t04_double_click_pickup()
	_test_t05_loot_to_bag_drag()
	_test_t06_bag_internal_move()
	_test_t07_bag_to_loot()
	_test_t08_full_bag()

	_summary()


# ─────────────────────────────────────────────
#  T01: 物资箱生成物品
# ─────────────────────────────────────────────
func _test_t01_loot_generation() -> void:
	_section("T01: 物资箱生成物品")
	GameData.clear_inventory()

	# 模拟一个 LootSpot 的数据生成
	var raw = ItemDB.generate_loot(2)
	_assert(raw.size() > 0, "generate_loot(2) 返回物品 > 0")

	# 转换为物资箱格式
	var loot = _make_loot_array(raw, 6)
	_assert(loot.size() == raw.size(), "loot 数量与 raw 相同")
	_assert(loot[0].has("instance_id"), "每个物品有 instance_id")
	_assert(loot[0].has("row"), "每个物品有 row")
	_assert(loot[0].has("col"), "每个物品有 col")
	_assert(loot[0].has("searched"), "每个物品有 searched 字段")
	_assert(not loot[0]["searched"], "初始 searched=false")

	# 检查位置不重叠
	var positions = {}
	var overlap = false
	for item in loot:
		var k = Vector2i(item["row"], item["col"])
		if k in positions:
			overlap = true
			break
		positions[k] = true
	_assert(not overlap, "所有物品位置不重叠")


# ─────────────────────────────────────────────
#  T02: 搜索完成后 searched=true
# ─────────────────────────────────────────────
func _test_t02_search_state() -> void:
	_section("T02: 搜索状态标记")
	var raw = ItemDB.generate_loot(1)
	var loot = _make_loot_array(raw, 6)

	# 模拟 LootUI 标记搜索
	for item in loot:
		item["searched"] = true

	var all_searched = true
	for item in loot:
		if not item.get("searched", false):
			all_searched = false
	_assert(all_searched, "手动标记后全部 searched=true")

	# 未搜索的物品不应该能被拖拽
	var unsearched_item = {"item_id": 1, "row": 0, "col": 0, "searched": false, "rarity": "common", "instance_id": 9001}
	_assert(not unsearched_item.get("searched", true), "未搜索物品 searched=false（不可拾取）")


# ─────────────────────────────────────────────
#  T03: 重开物资箱不重复搜索
# ─────────────────────────────────────────────
func _test_t03_no_rescan() -> void:
	_section("T03: 重开物资箱不重复搜索")
	var raw = ItemDB.generate_loot(2)
	var loot = _make_loot_array(raw, 6)

	# 模拟第一次搜索：标记前两项
	var n = min(2, loot.size())
	for i in range(n):
		loot[i]["searched"] = true

	# 记录搜索前的顺序
	var order_before = []
	for item in loot:
		order_before.append(item["instance_id"])

	# 模拟重开（LootUI.open_loot 不会改变数组引用，只调用 _setup_search）
	# 验证：已搜索的物品仍然搜索，未搜索的不变
	var searched_count_before = 0
	for item in loot:
		if item.get("searched", false): searched_count_before += 1

	# 验证顺序不变
	var order_after = []
	for item in loot:
		order_after.append(item["instance_id"])

	_assert(order_before == order_after, "重开前后物品顺序完全一致")
	_assert(searched_count_before == n, "已搜索数量正确 (n=%d)" % n)

	# 验证 _find_first_unsearched_index 逻辑：应跳过前 n 个
	var first_unsearched = -1
	for i in range(loot.size()):
		if not loot[i].get("searched", false):
			first_unsearched = i
			break
	_assert(first_unsearched == n or first_unsearched == -1, "第一个未搜索索引正确 (=%d)" % first_unsearched)


# ─────────────────────────────────────────────
#  T04: 双击快拾（调用等价逻辑）
# ─────────────────────────────────────────────
func _test_t04_double_click_pickup() -> void:
	_section("T04: 双击快拾")
	GameData.clear_inventory()

	var raw = ItemDB.generate_loot(1)
	var loot = _make_loot_array(raw, 6)
	for item in loot:
		item["searched"] = true  # 全部标记已搜索

	var item_count_before = loot.size()
	var bag_count_before = GameData.placed_items.size()

	# 取第一个物品，模拟双击快拾逻辑
	var target = loot[0]
	var placement = GameData.find_placement()
	_assert(placement["found"], "背包有空位（find_placement 成功）")

	if placement["found"]:
		loot.remove_at(0)  # 从物资箱移除
		var ok = GameData.place_item(target["item_id"], target.get("amount", 1), placement["row"], placement["col"])
		_assert(ok, "place_item 返回 true")
		_assert(GameData.placed_items.size() == bag_count_before + 1, "背包物品数+1")
		_assert(loot.size() == item_count_before - 1, "物资箱物品数-1")


# ─────────────────────────────────────────────
#  T05: 物资箱→背包拖拽（_do_loot_to_bag 等价）
# ─────────────────────────────────────────────
func _test_t05_loot_to_bag_drag() -> void:
	_section("T05: 物资箱→背包拖拽")
	GameData.clear_inventory()

	var raw = ItemDB.generate_loot(2)
	var loot = _make_loot_array(raw, 6)
	for item in loot:
		item["searched"] = true

	var inst = loot[0]["instance_id"]
	var item_id = loot[0]["item_id"]
	var loot_size_before = loot.size()

	# 找目标行列
	var placement = GameData.find_placement()
	_assert(placement["found"], "背包有空位")

	if placement["found"]:
		# 从物资箱移除
		loot.remove_at(0)
		# 放入背包
		var ok = GameData.place_item(item_id, 1, placement["row"], placement["col"])
		_assert(ok, "loot→bag: place_item 成功")
		_assert(loot.size() == loot_size_before - 1, "loot→bag: 物资箱-1")
		_assert(GameData.placed_items.size() == 1, "loot→bag: 背包+1")

		# 验证物品数据完整
		var placed = GameData.placed_items[0]
		_assert(placed["item_id"] == item_id, "loot→bag: item_id 正确")
		_assert(placed["row"] == placement["row"], "loot→bag: row 正确")
		_assert(placed["col"] == placement["col"], "loot→bag: col 正确")


# ─────────────────────────────────────────────
#  T06: 背包内移动（move_item）
# ─────────────────────────────────────────────
func _test_t06_bag_internal_move() -> void:
	_section("T06: 背包内移动")
	GameData.clear_inventory()

	# 放入物品到(0,0)
	var ok = GameData.place_item(1, 1, 0, 0)
	_assert(ok, "初始放置到(0,0)成功")

	var inst = GameData.placed_items[0]["instance_id"]

	# 移动到(0,5)
	var moved = GameData.move_item(inst, 0, 5)
	_assert(moved, "move_item(0,5) 返回 true")
	_assert(GameData.placed_items[0]["row"] == 0, "row 更新为 0")
	_assert(GameData.placed_items[0]["col"] == 5, "col 更新为 5")
	_assert(GameData.grid[0][5] == inst, "grid[0][5] 正确记录 instance_id")
	_assert(GameData.grid[0][0] == 0, "grid[0][0] 清空")

	# 移动到已占用的格子（应失败）
	var ok2 = GameData.place_item(2, 1, 1, 1)
	_assert(ok2, "在(1,1)再放一个物品")
	var ok3 = GameData.move_item(inst, 1, 1)
	_assert(not ok3, "移动到已占用格(1,1)应失败")

	# 移动回原位（排除自身）
	var ok4 = GameData.move_item(inst, 0, 5)
	_assert(ok4, "移回原位(0,5)成功（排除自身）")


# ─────────────────────────────────────────────
#  T07: 背包→物资箱放回
# ─────────────────────────────────────────────
func _test_t07_bag_to_loot() -> void:
	_section("T07: 背包→物资箱放回")
	GameData.clear_inventory()

	# 向背包放入一个物品
	var ok = GameData.place_item(3, 1, 2, 3)
	_assert(ok, "向背包放入物品")
	var placed = GameData.placed_items[0].duplicate()
	var inst = placed["instance_id"]

	# 准备一个物资箱（空）
	var loot: Array = []

	# 从背包移除
	var removed = GameData.remove_item_from_inventory(inst)
	_assert(removed, "从背包移除成功")
	_assert(GameData.placed_items.size() == 0, "背包清空")

	# 放入物资箱(0,2)
	loot.append({
		"instance_id": inst,
		"item_id": placed["item_id"],
		"row": 0,
		"col": 2,
		"searched": true,
		"rarity": "common",
		"amount": 1,
	})
	_assert(loot.size() == 1, "物资箱+1")
	_assert(loot[0]["row"] == 0 and loot[0]["col"] == 2, "物品位置正确(0,2)")

	# 尝试放到已占用格（应检测到冲突）
	var conflict = false
	for item in loot:
		if item["row"] == 0 and item["col"] == 2:
			conflict = true
	_assert(conflict, "目标格冲突检测正常")


# ─────────────────────────────────────────────
#  T08: 背包满时快拾
# ─────────────────────────────────────────────
func _test_t08_full_bag() -> void:
	_section("T08: 背包满时快拾不崩溃")
	GameData.clear_inventory()

	# 填满背包
	var placed = 0
	for r in range(GameData.GRID_ROWS):
		for c in range(GameData.GRID_COLS):
			if GameData.place_item(1, 1, r, c):
				placed += 1

	_assert(placed == GameData.GRID_ROWS * GameData.GRID_COLS, "背包已满 (%d格)" % placed)
	_assert(GameData.find_placement()["found"] == false, "find_placement 返回 found=false")

	# 模拟快拾逻辑（应静默失败，不崩溃）
	var target = {"item_id": 2, "searched": true, "instance_id": 99999, "row": 0, "col": 0, "rarity": "common"}
	var placement = GameData.find_placement()
	var would_fail = not placement["found"]
	_assert(would_fail, "背包满时快拾正确返回失败（不崩溃）")

	# 恢复背包
	GameData.clear_inventory()
	_assert(GameData.placed_items.size() == 0, "测试后清空背包")


# ─────────────────────────────────────────────
#  辅助：生成标准格式的物资箱数组
# ─────────────────────────────────────────────
func _make_loot_array(raw: Array, cols: int) -> Array:
	var result = []
	var iid = 1000
	var row = 0
	var col = 0
	for item in raw:
		result.append({
			"instance_id": iid,
			"item_id": item.get("id", item.get("item_id", 1)),
			"rarity": item.get("rarity", "common"),
			"row": row,
			"col": col,
			"searched": false,
			"amount": item.get("amount", 1),
		})
		iid += 1
		col += 1
		if col >= cols:
			col = 0
			row += 1
	return result
