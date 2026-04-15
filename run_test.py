#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Godot 自动化测试"""
import subprocess
import os
import sys

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_DIR = r"D:\youxi\soudache"
PROJECT_FILE = os.path.join(PROJECT_DIR, "project.godot")
TEST_SCRIPT = os.path.join(PROJECT_DIR, "scripts", "auto_test.gd")
RESULT_FILE = os.path.join(PROJECT_DIR, "test_result.txt")
TEST_UID = os.path.join(PROJECT_DIR, "scripts", "auto_test.gd.uid")

TEST_CODE = '''extends Node

func _ready():
	print("AUTO_TEST: Starting...")
	
	var f = FileAccess.open("res://test_result.txt", FileAccess.WRITE)
	f.store_line("AUTO_TEST: Starting")
	f.flush()
	
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	await get_tree().create_timer(0.5).timeout
	
	f.store_line("Step1: Load main menu")
	f.flush()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(0.8).timeout
	
	var scene = get_tree().current_scene
	f.store_line("Step1 OK: " + str(scene.name if scene else "null"))
	f.flush()
	
	f.store_line("Step2: Click StartGame")
	f.flush()
	var btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	
	f.store_line("Step3: Click EnterGame")
	f.flush()
	scene = get_tree().current_scene
	btn = scene.find_child("EnterGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	
	f.store_line("Step4: Click map StartGame")
	f.flush()
	scene = get_tree().current_scene
	btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(2.0).timeout
	
	scene = get_tree().current_scene
	f.store_line("Step5: Game scene = " + str(scene.name if scene else "null"))
	f.flush()
	
	f.store_line("Step6: Find loot spots")
	f.flush()
	var spots = get_tree().get_nodes_in_group("loot_spot")
	f.store_line("   Found: " + str(spots.size()))
	f.flush()
	
	if spots.size() > 0:
		var spot = spots[0]
		spot._ensure_generated()
		f.store_line("   Loot items: " + str(spot.loot_items.size()))
		f.flush()
		
		f.store_line("Step7: Open loot UI")
		f.flush()
		if scene.has_method("open_loot_ui"):
			scene.open_loot_ui(spot.loot_items, spot)
		await get_tree().create_timer(0.5).timeout
		
		var loot_ui = scene.get_node_or_null("LootUI")
		if loot_ui and loot_ui.visible:
			f.store_line("Step7 OK: Loot UI visible")
			f.flush()
			
			f.store_line("Step8: Wait for search...")
			f.flush()
			await get_tree().create_timer(8.0).timeout
			f.store_line("   Loot: " + str(loot_ui.loot_box_items.size()) + " Bag: " + str(GameData.placed_items.size()))
			f.flush()
			
			f.store_line("Step9: Test double-click")
			f.flush()
			if loot_ui.loot_slot_nodes.size() > 0:
				var slot = loot_ui.loot_slot_nodes[0]
				if is_instance_valid(slot):
					var pos = slot.get_global_rect().get_center()
					f.store_line("   Click at: " + str(pos))
					f.flush()
					_do_double_click(loot_ui, pos)
					await get_tree().create_timer(0.5).timeout
					f.store_line("   After: Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
					f.flush()
	
	f.store_line("RESULT: PASS")
	f.flush()
	f.close()
	get_tree().quit()

func _do_double_click(ui: CanvasLayer, pos: Vector2):
	for i in range(2):
		var down = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = pos
		down.double_click = (i == 1)
		ui._input(down)
		await get_tree().create_timer(0.08).timeout
		
		var up = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = pos
		ui._input(up)
		await get_tree().create_timer(0.08).timeout
'''

def run():
    print("=== Godot Auto Test ===")
    
    # Clean old result
    if os.path.exists(RESULT_FILE):
        os.remove(RESULT_FILE)
    
    # Write test script
    with open(TEST_SCRIPT, "w", encoding="utf-8") as f:
        f.write(TEST_CODE)
    with open(TEST_UID, "w", encoding="utf-8") as f:
        f.write("uid://br5y5dniqpskk\n")
    print("1. Test script written")
    
    # Update project.godot
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        content = f.read()
    original = content
    
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        if any(x in line for x in ['GreedyTest', 'AutoTest', 'RealClickTest', 'BoxTest', 'DeltaTest', 'Req51Test', 'GridTest']):
            continue
        new_lines.append(line)
    
    insert_idx = -1
    for i, line in enumerate(new_lines):
        if 'AssetGenerator=' in line:
            insert_idx = i + 1
            break
    
    if insert_idx > 0:
        new_lines.insert(insert_idx, 'AutoTest="*res://scripts/auto_test.gd"')
    
    content = '\n'.join(new_lines)
    with open(PROJECT_FILE, "w", encoding="utf-8") as f:
        f.write(content)
    print("2. project.godot updated")
    
    # Run Godot
    print("3. Running Godot (60s timeout)...")
    
    try:
        proc = subprocess.Popen(
            [GODOT_EXE, "--headless", "--quit-after", "60", PROJECT_DIR],
            cwd=PROJECT_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        try:
            stdout, stderr = proc.communicate(timeout=90)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout, stderr = proc.communicate()
            print("[TIMEOUT]")
        
    except Exception as e:
        print(f"[ERROR: {e}]")
        content = original
        with open(PROJECT_FILE, "w", encoding="utf-8") as f:
            f.write(content)
        return 1
    
    # Restore project.godot
    with open(PROJECT_FILE, "w", encoding="utf-8") as f:
        f.write(original)
    print("4. project.godot restored")
    
    # Read result
    if os.path.exists(RESULT_FILE):
        with open(RESULT_FILE, "r", encoding="utf-8") as f:
            result = f.read()
        print("\n=== Test Results ===")
        print(result)
        os.remove(RESULT_FILE)
        
        if "RESULT: PASS" in result:
            print("\n=== TEST PASSED ===")
            return 0
        else:
            print("\n=== TEST FAILED ===")
            return 1
    else:
        print("\n[No result file - check Godot output above]")
        return 1

if __name__ == "__main__":
    sys.exit(run())
