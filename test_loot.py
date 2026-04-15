#!/usr/bin/env python3
"""自动化测试脚本 - 模拟真实点击操作"""

import subprocess
import time
import os
import sys
import shutil

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_DIR = r"D:\youxi\soudache"
TEST_SCRIPT = r"scripts/python_test.gd"

def run_test():
    print("=== 自动化点击测试 ===\n")
    
    # 创建测试脚本
    test_script = '''extends Node

var test_results = []

func _ready():
    print("=== Python-Driven Test Started ===")
    call_deferred("run_tests")

func run_tests():
    await get_tree().create_timer(0.5).timeout
    
    # Setup: Clear inventory, make player invincible
    GameData.player_health = 9999
    GameData.clear_inventory()
    
    # Load main menu
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
    await get_tree().create_timer(0.5).timeout
    
    var scene = get_tree().current_scene
    print("Scene: " + scene.name)
    
    # Click Start Game -> Prepare Screen
    var btn = scene.find_child("StartGame", true, false)
    if btn: btn.pressed.emit()
    await get_tree().create_timer(1.0).timeout
    
    # Click Enter Game -> Map Selection
    scene = get_tree().current_scene
    btn = scene.find_child("EnterGame", true, false)
    if btn: btn.pressed.emit()
    await get_tree().create_timer(0.5).timeout
    
    # Click Start Game -> Game World
    scene = get_tree().current_scene
    btn = scene.find_child("StartGame", true, false)
    if btn: btn.pressed.emit()
    await get_tree().create_timer(2.0).timeout
    
    scene = get_tree().current_scene
    print("Game World: " + scene.name)
    
    # Find loot spot and interact
    var spots = get_tree().get_nodes_in_group("loot_spot")
    if spots.size() == 0:
        print("FAIL: No loot spots")
        get_tree().quit()
        return
    
    var spot = spots[0]
    spot._ensure_generated()
    print("Loot items: " + str(spot.loot_items.size()))
    
    # Open loot UI
    scene.open_loot_ui(spot.loot_items, spot)
    await get_tree().create_timer(1.0).timeout
    
    var loot_ui = scene.get_node_or_null("LootUI")
    if not loot_ui or not loot_ui.visible:
        print("FAIL: Loot UI not visible")
        get_tree().quit()
        return
    
    print("Loot UI opened")
    
    # Wait for search
    await get_tree().create_timer(8.0).timeout
    
    print("Search complete: Box=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
    
    # === TEST 1: Double-click pick ===
    print("\\n=== TEST 1: Double-click pick ===")
    if loot_ui.loot_slot_nodes.size() > 0:
        var slot = loot_ui.loot_slot_nodes[0]
        var pos = slot.get_global_rect().get_center()
        
        # Double-click simulation
        loot_ui._handle_click(pos, true)
        await get_tree().create_timer(0.1).timeout
        loot_ui._handle_click(pos, false, true)
        
        await get_tree().create_timer(0.5).timeout
        
        var box_after = loot_ui.loot_box_items.size()
        var bag_after = GameData.placed_items.size()
        
        print("Result: Box=" + str(box_after) + " Bag=" + str(bag_after))
        
        if bag_after > 0:
            print("PASS: Item picked to bag")
        else:
            print("FAIL: Pick did not work")
    
    # === TEST 2: Double-click return ===
    print("\\n=== TEST 2: Double-click return ===")
    if loot_ui.player_item_slots.size() > 0:
        var bag_slot = loot_ui.player_item_slots[0]
        var pos = bag_slot.get_global_rect().get_center()
        
        loot_ui._handle_click(pos, true)
        await get_tree().create_timer(0.1).timeout
        loot_ui._handle_click(pos, false, true)
        
        await get_tree().create_timer(0.5).timeout
        
        print("Result: Box=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
    
    print("\\n=== All Tests Complete ===")
    get_tree().quit()
'''
    
    script_path = os.path.join(PROJECT_DIR, TEST_SCRIPT)
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(test_script)
    print(f"Test script created: {script_path}\n")
    
    # 修改 project.godot 添加 autoload
    godot_file = os.path.join(PROJECT_DIR, "project.godot")
    
    with open(godot_file, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "PythonTest" not in content:
        content = content.replace(
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"',
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"\nPythonTest="*res://scripts/python_test.gd"'
        )
        with open(godot_file, "w", encoding="utf-8") as f:
            f.write(content)
        print("Added PythonTest to autoload\n")
    
    # 运行 Godot
    print("Running Godot...")
    cmd = [GODOT_EXE, "--headless", "--quit-after", "60", PROJECT_DIR]
    
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=PROJECT_DIR, timeout=90)
    
    print(result.stdout)
    if result.stderr:
        # 只打印非关键的警告
        for line in result.stderr.split('\n'):
            if 'WARNING' not in line and 'leaked' not in line:
                print("STDERR:", line)
    
    # 恢复 project.godot
    content = content.replace('\nPythonTest="*res://scripts/python_test.gd"', '')
    with open(godot_file, "w", encoding="utf-8") as f:
        f.write(content)
    
    # 清理测试脚本
    if os.path.exists(script_path):
        os.remove(script_path)
    
    print("\n=== 测试完成 ===")
    return 0

if __name__ == "__main__":
    sys.exit(run_test())
