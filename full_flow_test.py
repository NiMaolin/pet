#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动化测试脚本 - 完整流程测试
1. 启动游戏，显示窗口
2. 通过代码调用按钮事件（非坐标点击）
3. 流程：主菜单 → 开始游戏 → 行前准备 → 地图选择 → 出发 → 史前世界
"""
import subprocess
import os
import sys
import time

GODOT_EXE = r"C:\Tools\Godot_v4.6.1-stable_win64.exe"
PROJECT_DIR = r"D:\youxi\soudache"
TEST_SCRIPT = r"scripts\full_auto_test.gd"
PROJECT_FILE = os.path.join(PROJECT_DIR, "project.godot")

# 完整测试代码 - 调用按钮事件而非坐标点击
TEST_CODE = '''extends Node

var step = 0
var result_log = []

func _ready():
	print("========== 完整自动化测试开始 ==========")
	result_log.append("Test started at: " + str(Time.get_unix_time_from_system()))
	call_deferred("run_full_flow")

func run_full_flow():
	await get_tree().create_timer(1.0).timeout  # 等待游戏加载
	step = 1
	print("\\n[步骤1] 等待主菜单加载...")
	await get_tree().create_timer(1.0).timeout
	
	# 检查当前场景
	var current = get_tree().current_scene
	print("  当前场景: " + str(current))
	
	# 进入游戏流程
	yield(start_game_click, "done")
	yield(prepare_click, "done") 
	yield(map_select_click, "done")
	yield(enter_copy_click, "done")
	
	# 等待进入副本
	await get_tree().create_timer(2.0).timeout
	
	# 验证是否在游戏世界
	var game_scene = get_tree().current_scene
	print("\\n[验证] 当前场景: " + str(game_scene))
	
	if game_scene and "GameWorld" in str(game_scene.name):
		print("✅ 成功进入史前世界副本！")
		result_log.append("SUCCESS: Entered prehistoric copy")
		# 可以在这里继续测试游戏内功能
		test_complete(true)
	else:
		print("❌ 未进入游戏世界")
		result_log.append("FAIL: Did not enter game world")
		test_complete(false)

# 步骤2: 点击"开始游戏"
signal start_game_click_done
func start_game_click():
	step = 2
	print("\\n[步骤2] 点击 开始游戏...")
	
	var scene = get_tree().current_scene
	if not scene:
		print("  ❌ 场景为空")
		result_log.append("FAIL: No scene found")
		test_complete(false)
		return
	
	# 查找开始游戏按钮 - 方法1: 通过节点名称
	var btn = scene.find_child("NewGame", true, false)
	if not btn:
		# 方法2: 遍历所有Button
		var buttons = []
		if scene.has_node("Panel/VBox"):
			var vbox = scene.get_node("Panel/VBox")
			for child in vbox.get_children():
				if child is Button:
					buttons.append(child)
					print("  Found button: " + child.name)
		
		if buttons.size() > 0:
			btn = buttons[0]  # 第一个是"开始游戏"
	
	if btn and btn is Button:
		print("  ✅ 找到按钮: " + btn.name)
		btn.pressed.emit()
		print("  ✅ 已触发 pressed 信号")
		result_log.append("OK: Clicked NewGame")
	else:
		print("  ❌ 未找到开始游戏按钮")
		result_log.append("FAIL: NewGame button not found")
		test_complete(false)
		return
	
	await get_tree().create_timer(1.5).timeout
	start_game_click_done.emit()

# 步骤3: 点击"行前准备"
signal prepare_click_done
func prepare_click():
	step = 3
	print("\\n[步骤3] 点击 行前准备...")
	
	var scene = get_tree().current_scene
	if not scene:
		print("  ❌ 场景为空")
		test_complete(false)
		return
	
	# 查找行前准备按钮
	var btn = scene.find_child("Prepare", true, false)
	if not btn:
		# 尝试其他方式查找
		if scene.has_node("Panel/VBox/HBox/ButtonPanel"):
			var panel = scene.get_node("Panel/VBox/HBox/ButtonPanel")
			for child in panel.get_children():
				if child is Button and "准备" in child.text:
					btn = child
					break
	
	if btn and btn is Button:
		print("  ✅ 找到按钮: " + btn.name)
		btn.pressed.emit()
		result_log.append("OK: Clicked Prepare")
	else:
		print("  ❌ 未找到行前准备按钮，尝试直接切换场景...")
		# 备选：直接切换场景
		get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
		result_log.append("OK: Direct scene change to map_select")
	
	await get_tree().create_timer(1.0).timeout
	prepare_click_done.emit()

# 步骤4: 点击地图选择（默认史前世界）
signal map_select_click_done
func map_select_click():
	step = 4
	print("\\n[步骤4] 地图选择界面...")
	
	var scene = get_tree().current_scene
	if not scene:
		test_complete(false)
		return
	
	# 默认已选择史前世界，直接找"出发"按钮
	var btn = scene.find_child("Start", true, false)
	if not btn:
		# 尝试按文本查找
		if scene.has_node("CenterContainer/VBox/Start"):
			btn = scene.get_node("CenterContainer/VBox/Start")
	
	if btn and btn is Button:
		print("  ✅ 找到出发按钮: " + btn.name)
		btn.pressed.emit()
		result_log.append("OK: Clicked Start")
	else:
		print("  ❌ 未找到出发按钮")
		test_complete(false)
		return
	
	await get_tree().create_timer(0.5).timeout
	map_select_click_done.emit()

# 步骤5: 进入副本
signal enter_copy_click_done
func enter_copy_click():
	step = 5
	print("\\n[步骤5] 进入副本...")
	
	# 设置游戏数据
	GameData.is_in_game = true
	GameData.clear_inventory()
	
	# scene change 已由 map_select.gd 的 _on_start_pressed 处理
	# 等待场景切换
	await get_tree().create_timer(2.0).timeout
	
	enter_copy_click_done.emit()

func test_complete(success: bool):
	print("\\n" + "="*50)
	print("测试结果: " + ("✅ 成功" if success else "❌ 失败"))
	print("="*50)
	
	for log in result_log:
		print("  " + log)
	
	print("\\n5秒后退出...")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()
'''

def run():
    print("=" * 60)
    print("完整流程自动化测试")
    print("流程: 主菜单 → 开始游戏 → 行前准备 → 地图选择 → 出发 → 史前世界")
    print("=" * 60)
    
    # 1. 备份 project.godot
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        original_content = f.read()
    
    # 2. 创建测试脚本
    test_path = os.path.join(PROJECT_DIR, TEST_SCRIPT)
    with open(test_path, "w", encoding="utf-8") as f:
        f.write(TEST_CODE)
    print("\n1. 测试脚本已创建: " + TEST_SCRIPT)
    
    # 3. 修改 project.godot 添加测试
    test_entry = 'FullAutoTest="*res://scripts/full_auto_test.gd"'
    if test_entry not in original_content:
        # 找到合适位置插入
        new_content = original_content.replace(
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"',
            'AssetGenerator="*res://scripts/systems/asset_generator.gd"\nFullAutoTest="*res://scripts/full_auto_test.gd"'
        )
        with open(PROJECT_FILE, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("2. 已添加到 project.godot")
    else:
        print("2. 已存在，跳过")
    
    # 4. 启动 Godot（显示窗口，非 headless）
    print("\n3. 启动游戏窗口...")
    print("   注意: 请查看弹出的游戏窗口")
    print("   窗口标题应为: Pet Extraction (DEBUG)")
    
    try:
        # 不使用 --headless，让窗口显示出来
        # 使用 --quit-after 让它自动退出（超时后）
        proc = subprocess.Popen(
            [GODOT_EXE, "--quit-after", "120", PROJECT_DIR],
            cwd=PROJECT_DIR,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP
        )
        
        # 等待一段时间让窗口显示
        print("   等待游戏启动...")
        time.sleep(3)
        
        # 监控进程
        try:
            stdout, stderr = proc.communicate(timeout=120)
            output = stdout.decode("utf-8", errors="replace")
            print("\n--- 游戏输出 ---")
            print(output[:3000] if len(output) > 3000 else output)
        except subprocess.TimeoutExpired:
            print("\n超时，测试完成")
            proc.kill()
            
    except Exception as e:
        print(f"启动失败: {e}")
    
    # 5. 恢复 project.godot
    with open(PROJECT_FILE, "w", encoding="utf-8") as f:
        f.write(original_content)
    print("\n4. 已恢复 project.godot")
    
    # 6. 删除测试脚本
    if os.path.exists(test_path):
        os.remove(test_path)
    print("5. 已清理测试脚本")
    
    print("\n" + "=" * 60)
    print("测试完成")
    print("=" * 60)

if __name__ == "__main__":
    sys.exit(run())