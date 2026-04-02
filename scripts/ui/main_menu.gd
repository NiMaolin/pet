extends Control
func _ready():
	print("=== 主菜单加载 ===")
func _on_new_game_pressed():
	SaveSystem.start_new_game()
	get_tree().change_scene_to_file("res://scenes/ui/prep_screen.tscn")
func _on_load_game_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/load_menu.tscn")
func _on_quit_pressed():
	get_tree().quit()
