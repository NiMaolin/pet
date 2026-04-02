## SaveSystem - 存档系统
extends Node

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 3
# 隐藏自动保存槽位（游戏进程专用，对玩家不可见）
const AUTO_SLOT: int = 3

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# ── 核心：保存到指定槽位 ──────────────────────────────────
func _do_save(slot: int) -> bool:
	var data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"game_data": GameData.get_save_data(),
	}
	var path = SAVE_DIR + "save_%d.json" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

# ── 核心：从指定槽位读取 ──────────────────────────────────
func _do_load(slot: int) -> bool:
	var path = SAVE_DIR + "save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null:
		return false
	GameData.load_save_data(data.get("game_data", {}))
	return true

# ── 玩家可见的保存游戏 ────────────────────────────────────
# 将当前游戏进程（隐藏槽位）复制到玩家选择的可见槽位
func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	var ok = _do_save(slot)
	if ok:
		GameData.last_save_slot = slot
		print("✅ 存档已保存到槽位 %d" % slot)
	return ok

# ── 玩家可见的读取存档 ────────────────────────────────────
# 先把选中的槽位内容复制到隐藏槽位，再加载
func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	# 读取选中槽位 → 覆盖隐藏自动存档
	if not _do_load(slot):
		return false
	GameData.last_save_slot = slot
	print("✅ 存档槽位 %d 已加载" % slot)
	return true

# ── 自动保存游戏进程（内部用，slot=3）─────────────────────
# 每隔一段时间调用一次，保存当前游戏进度
func auto_save() -> void:
	var ok = _do_save(AUTO_SLOT)
	if ok:
		print("💾 自动保存完成（隐藏槽位）")

# ── 从自动保存恢复（读取隐藏槽位）──────────────────────────
func load_auto_save() -> bool:
	var ok = _do_load(AUTO_SLOT)
	if ok:
		print("📂 已从自动存档恢复")
	return ok

# ── 删除存档 ────────────────────────────────────────────
func delete_save(slot: int) -> void:
	var path = SAVE_DIR + "save_%d.json" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("✅ 存档槽位 %d 已删除" % slot)

# ── 检查存档是否存在 ─────────────────────────────────────
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_DIR + "save_%d.json" % slot)

# ── 获取存档信息（用于 UI 显示）────────────────────────────
func get_save_info(slot: int) -> Dictionary:
	var path = SAVE_DIR + "save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return {}
	var ts = data.get("timestamp", 0)
	var dt = Time.get_datetime_dict_from_unix_time(int(ts))
	var pt = int(data.get("game_data", {}).get("play_time", 0))
	return {
		"exists": true,
		"date": "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute],
		"play_time": "%02d:%02d" % [pt / 60, pt % 60],
		"pet_count": data.get("game_data", {}).get("collected_pets", []).size(),
	}

# ── 开始新游戏 ────────────────────────────────────────────
# 不绑定任何可见槽位，只重置游戏进程
func start_new_game() -> void:
	GameData.equipped_pet_id = 0
	GameData.fused_pet_id = 0
	GameData.player_health = GameData.player_max_health
	GameData.play_time = 0.0
	GameData.last_save_slot = -1
	GameData.clear_inventory()
	# 自动保存到隐藏槽位
	auto_save()
	print("✅ 新游戏已开始（自动保存到隐藏槽位）")

# ── 获取/检查自动存档是否存在 ──────────────────────────────
func has_auto_save() -> bool:
	return FileAccess.file_exists(SAVE_DIR + "save_%d.json" % AUTO_SLOT)
