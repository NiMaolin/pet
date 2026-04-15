extends Node

func _ready():
    print("=== AutoTest: Starting ===")
    call_deferred("run_tests")

func run_tests():
    await get_tree().create_timer(2.0).timeout
    
    # 1. Load main menu
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
    await get_tree().create_timer(2.0).timeout
    print("1. Loaded main_menu")
    
    # 2. Click NewGame
    var scene = get_tree().current_scene
    var btn = scene.find_child("NewGame", true, false)
    if btn:
        btn.pressed.emit()
    await get_tree().create_timer(2.0).timeout
    print("2. Clicked NewGame")
    
    # 3. Click Prepare
    scene = get_tree().current_scene
    btn = scene.find_child("Prepare", true, false)
    if btn:
        btn.pressed.emit()
    await get_tree().create_timer(2.0).timeout
    print("3. Clicked Prepare")
    
    # 4. Click Start (first run)
    scene = get_tree().current_scene
    btn = scene.find_child("Start", true, false)
    if btn:
        btn.pressed.emit()
    await get_tree().create_timer(3.0).timeout
    print("4. Clicked Start - first run")
    
    # 5. Check initial health
    var hp = GameData.player_health
    var maxHp = GameData.player_max_health
    print("First run HP: " + str(hp) + "/" + str(maxHp))
    
    # 6. Simulate damage
    GameData.player_health = max(1, hp - 50)
    print("HP after damage: " + str(GameData.player_health))
    
    # 7. Go to extract_success
    get_tree().change_scene_to_file("res://scenes/ui/extract_success.tscn")
    await get_tree().create_timer(2.0).timeout
    print("5. Loaded extract_success")
    
    # 8. Return to prep
    get_tree().change_scene_to_file("res://scenes/ui/prep_screen.tscn")
    await get_tree().create_timer(2.0).timeout
    print("6. Back to prep_screen")
    
    # 9. Click Start again
    scene = get_tree().current_scene
    btn = scene.find_child("Start", true, false)
    if btn:
        btn.pressed.emit()
    await get_tree().create_timer(3.0).timeout
    print("7. Clicked Start - second run")
    
    # 10. Check health reset
    var hpAfter = GameData.player_health
    print("HP after restart: " + str(hpAfter))
    
    if hpAfter == maxHp:
        print("=== PASS ===")
    else:
        print("=== FAIL ===")
    
    await get_tree().create_timer(2.0).timeout
    get_tree().quit()
