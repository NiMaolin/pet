#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""简化版自动测试 - 验证完整流程和血量重置"""
import subprocess
import os
import sys

GODOT_EXE = r"C:\Tools\Godot_v4.6.1-stable_win64.exe"
PROJECT_DIR = r"D:\youxi\soudache"

# 简化的 GDScript 测试代码
TEST_CODE = '''extends Node

func _ready():
	print("=== Auto Test Started ===")
	call_deferred("run_tests")

func run_tests():
	await get_tree().create_timer(0.5).timeout
	
	# 1. 加载主菜单
	print("1. Loading main menu...")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(0.5).timeout
	
	var scene = get_tree().current_scene
	print("   Scene: " + str(scene.name if scene else "null"))
	
	# 2. 点击新游戏
	print("2. Clicking new game...")
	var btn = scene.find_child("NewGame", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	
	# 3. 点击准备按钮
	print("3. Clicking prepare...")
	scene = get_tree().current_scene
	btn = scene.find_child("PrepareButton", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	
	# 4. 点击出发按钮
	print("4. Clicking start (first run)...")
	scene = get_tree().current_scene
	btn = scene.find_child("Start", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	
	# 5. 获取首次进入后的血量
	var health_before = GameData.player_health
	var max_health = GameData.player_max_health
	print("   First run health: " + str(health_before) + "/" + str(max_health))
	
	# 6. 模拟扣血
	print("6. Simulating damage...")
	GameData.player_health = max(1, health_before - 50)
	var health_after_damage = GameData.player_health
	print("   Health after damage: " + str(health_after_damage))
	
	# 7. 到达撤离点（模拟撤离成功）
	print("7. Simulating escape success...")
	get_tree().change_scene_to_file("res://scenes/ui/extract_success.tscn")
	await get_tree().create_timer(0.5).timeout
	
	# 8. 点击任意键返回（模拟按键）
	print("8. Pressing any key to return...")
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.pressed = true
	get_tree().input(key_event)
	await get_tree().create_timer(0.5).timeout
	
	# 9. 再次点击出发按钮
	print("9. Clicking start (second run)...")
	scene = get_tree().current_scene
	btn = scene.find_child("Start", true, false)
	if btn:
		btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	
	# 10. 验证血量重置
	var health_after_restart = GameData.player_health
	print("   Health after restart: " + str(health_after_restart))
	
	# 结果判定
	print("")
	if health_after_restart == max_health and health_after_restart != health_after_damage:
		print("=== RESULT: PASS ===")
		print("血量重置功能正常！首次血量=" + str(health_before) + ", 扣血后=" + str(health_after_damage) + ", 重启后=" + str(health_after_restart))
	else:
		print("=== RESULT: FAIL ===")
		print("血量重置失败！期望=" + str(max_health) + ", 实际=" + str(health_after_restart))
		print("首次血量=" + str(health_before) + ", 扣血后=" + str(health_after_damage))
	
	get_tree().quit()
'''

def main():
    print("=== Simplified Auto Test ===\n")
    
    # 创建测试脚本
    test_script = os.path.join(PROJECT_DIR, "scripts", "auto_test.gd")
    with open(test_script, "w", encoding="utf-8") as f:
        f.write(TEST_CODE)
    print(f"1. Test script created: {test_script}")
    
    # 修改 project.godot 添加测试
    project_file = os.path.join(PROJECT_DIR, "project.godot")
    with open(project_file, "r", encoding="utf-8") as f:
        original = f.read()
    
    if "AutoTest" not in original:
        modified = original.replace(
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"',
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"\nAutoTest="*res://scripts/auto_test.gd"'
        )
        with open(project_file, "w", encoding="utf-8") as f:
            f.write(modified)
        print("2. Added AutoTest to project.godot")
    else:
        print("2. AutoTest already in project.godot")
        modified = original
    
    # 运行 Godot
    print("3. Running Godot...")
    try:
        result = subprocess.run(
            [GODOT_EXE, "--headless", "--quit-after", "30", PROJECT_DIR],
            cwd=PROJECT_DIR,
            capture_output=True,
            timeout=45
        )
        
        # 解码输出
        stdout = result.stdout.decode("utf-8", errors="replace")
        
        # 打印输出
        print("-" * 50)
        print(stdout)
        
        # 检查结果
        if "RESULT: PASS" in stdout:
            print("\n[测试通过]")
        elif "RESULT: FAIL" in stdout:
            print("\n[测试失败]")
        else:
            print("\n[测试未完成 - 检查输出]")
            
    except subprocess.TimeoutExpired:
        print("\n[超时]")
    except Exception as e:
        print(f"\n[错误: {e}]")
    
    # 恢复 project.godot
    with open(project_file, "w", encoding="utf-8") as f:
        f.write(original)
    print("\n4. Restored project.godot")
    
    # 清理测试脚本
    if os.path.exists(test_script):
        os.remove(test_script)
    print("5. Cleaned up test script")
    
    print("\nDone.")

if __name__ == "__main__":
    sys.exit(main())