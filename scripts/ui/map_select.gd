extends Control
@onready var start_button: Button = $CenterContainer/VBox/Start
@onready var map1_button: Button = $CenterContainer/VBox/Map1
var selected_map: String = "prehistoric"
func _ready():
	print("=== 地图选择界面加载 ===")
	_select_map("prehistoric")
func _select_map(map_id: String):
	selected_map = map_id
	GameData.current_map = map_id
	map1_button.text = "✅  史前世界\n普通难度 · 史前生物"
	start_button.text = "出发！→ 史前世界"
func _on_map1_pressed(): _select_map("prehistoric")
func _on_start_pressed():
	GameData.is_in_game = true
	# 重置人物状态（仅重置血量，不重置仓库/宠物等）
	GameData.player_health = GameData.player_max_health
	GameData.play_time = 0.0
	# 清除背包（物资点物品）
	GameData.clear_inventory()
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/prep_screen.tscn")
