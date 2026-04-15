#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""自动化测试脚本 - Godot 真实点击测试"""
import subprocess
import os
import sys

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_DIR = r"D:\youxi\soudache"
TEST_SCRIPT = r"scripts\auto_test.gd"
PROJECT_FILE = os.path.join(PROJECT_DIR, "project.godot")

# 测试脚本内容
TEST_CODE = '''extends Node

func _ready():
	print("=== Auto Test Started ===")
	call_deferred("run_tests")

func run_tests():
	await get_tree().create_timer(0.5).timeout
	
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	# 1. Load main menu
	print("1. Loading main menu...")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(0.5).timeout
	
	var scene = get_tree().current_scene
	print("   Scene: " + str(scene.name if scene else "null"))
	
	# 2. Click StartGame
	print("2. Clicking StartGame...")
	var btn = scene.find_child("StartGame", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	
	# 3. Click EnterGame
	print("3. Clicking EnterGame...")
	scene = get_tree().current_scene
	btn = scene.find_child("EnterGame", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	
	# 4. Select map
	print("4. Selecting map...")
	scene = get_tree().current_scene
	btn = scene.find_child("StartGame", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(2.0).timeout
	
	scene = get_tree().current_scene
	print("   Game scene: " + str(scene.name if scene else "null"))
	
	# 5. Find loot spot
	print("5. Finding loot spot...")
	var spots = get_tree().get_nodes_in_group("loot_spot")
	if spots.size() == 0:
		print("FAIL: No loot spots found!")
		test_done(false)
		return
	
	var spot = spots[0]
	spot._ensure_generated()
	print("   Loot items: " + str(spot.loot_items.size()))
	
	# 6. Open loot UI
	print("6. Opening loot UI...")
	if scene.has_method("open_loot_ui"):
		scene.open_loot_ui(spot.loot_items, spot)
	await get_tree().create_timer(0.5).timeout
	
	var loot_ui = scene.get_node_or_null("LootUI")
	if not loot_ui or not loot_ui.visible:
		print("FAIL: Loot UI not visible!")
		test_done(false)
		return
	
	print("   Loot UI opened, items: " + str(loot_ui.loot_box_items.size()))
	
	# 7. Wait for search
	print("7. Waiting for search...")
	var wait_time = 0.0
	while loot_ui.is_searching and wait_time < 15.0:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5
	
	await get_tree().create_timer(1.0).timeout
	
	var loot_before = loot_ui.loot_box_items.size()
	var bag_before = GameData.placed_items.size()
	print("   Before: Loot=" + str(loot_before) + " Bag=" + str(bag_before))
	
	# 8. Test double-click pick
	print("8. Testing double-click pick...")
	if loot_ui.loot_slot_nodes.size() > 0:
		var slot = loot_ui.loot_slot_nodes[0]
		if is_instance_valid(slot):
			var pos = slot.get_global_rect().get_center()
			print("   Clicking at: " + str(pos))
			
			# Double-click sequence
			for i in range(2):
				var down = InputEventMouseButton.new()
				down.button_index = MOUSE_BUTTON_LEFT
				down.pressed = true
				down.position = pos
				down.global_position = pos
				if i == 1: down.double_click = true
				loot_ui._input(down)
				await get_tree().create_timer(0.05).timeout
				
				var up = InputEventMouseButton.new()
				up.button_index = MOUSE_BUTTON_LEFT
				up.pressed = false
				up.position = pos
				up.global_position = pos
				loot_ui._input(up)
				await get_tree().create_timer(0.05).timeout
			
			await get_tree().create_timer(0.5).timeout
			
			var loot_after = loot_ui.loot_box_items.size()
			var bag_after = GameData.placed_items.size()
			
			print("   After: Loot=" + str(loot_after) + " Bag=" + str(bag_after))
			
			if bag_after > bag_before and loot_after < loot_before:
				print("PASS: Double-click pick works!")
			else:
				print("FAIL: Double-click pick did not work")
	
	# 9. Test double-click return
	print("9. Testing double-click return...")
	if loot_ui.player_item_slots.size() > 0:
		var bag_slot = loot_ui.player_item_slots[0]
		if is_instance_valid(bag_slot):
			var pos = bag_slot.get_global_rect().get_center()
			
			for i in range(2):
				var down = InputEventMouseButton.new()
				down.button_index = MOUSE_BUTTON_LEFT
				down.pressed = true
				down.position = pos
				down.global_position = pos
				if i == 1: down.double_click = true
				loot_ui._input(down)
				await get_tree().create_timer(0.05).timeout
				
				var up = InputEventMouseButton.new()
				up.button_index = MOUSE_BUTTON_LEFT
				up.pressed = false
				up.position = pos
				up.global_position = pos
				loot_ui._input(up)
				await get_tree().create_timer(0.05).timeout
			
			await get_tree().create_timer(0.5).timeout
			
			print("   After return: Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
	
	# 10. Close UI
	print("10. Closing UI...")
	loot_ui._on_close()
	await get_tree().create_timer(0.3).timeout
	
	test_done(true)

func test_done(success: bool):
	print("")
	print("=== RESULT: " + ("OK" if success else "FAILED") + " ===")
	get_tree().quit()
'''

def run():
    print("=== Godot Auto Test ===\n")
    
    # 1. Create test script
    test_path = os.path.join(PROJECT_DIR, TEST_SCRIPT)
    with open(test_path, "w", encoding="utf-8") as f:
        f.write(TEST_CODE)
    print("1. Test script created")
    
    # 2. Modify project.godot
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        godot_content = f.read()
    
    original_content = godot_content
    
    if "AutoTest" not in godot_content:
        godot_content = godot_content.replace(
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"',
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"\nAutoTest="*res://scripts/auto_test.gd"'
        )
        with open(PROJECT_FILE, "w", encoding="utf-8") as f:
            f.write(godot_content)
        print("2. Added AutoTest to project.godot")
    
    # 3. Run Godot
    print("3. Running Godot...")
    
    try:
        result = subprocess.run(
            [GODOT_EXE, "--headless", "--quit-after", "60", PROJECT_DIR],
            cwd=PROJECT_DIR,
            capture_output=True,
            timeout=90
        )
        
        # Decode output
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        
        # Print output (handle any encoding issues)
        try:
            print("-" * 50)
            print(stdout)
        except:
            # Fallback: write to file
            with open("test_output.txt", "w", encoding="utf-8") as f:
                f.write(stdout)
            print("Output written to test_output.txt")
        
        # Check for errors
        if "ERROR" in stderr:
            try:
                print("STDERR:", stderr[:500])
            except:
                pass
        
        # Determine result
        if "RESULT: OK" in stdout:
            print("\n[TEST PASSED]")
            return_code = 0
        elif "RESULT: FAILED" in stdout:
            print("\n[TEST FAILED]")
            return_code = 1
        else:
            print("\n[TEST INCONCLUSIVE - check output above]")
            return_code = 1
            
    except subprocess.TimeoutExpired:
        print("\n[TIMEOUT]")
        return_code = 1
    except Exception as e:
        print(f"\n[ERROR: {e}]")
        return_code = 1
    
    # 4. Restore project.godot
    with open(PROJECT_FILE, "w", encoding="utf-8") as f:
        f.write(original_content)
    
    # 5. Cleanup
    if os.path.exists(test_path):
        os.remove(test_path)
    
    print("\nDone.")
    return return_code

if __name__ == "__main__":
    sys.exit(run())
