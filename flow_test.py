#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
完整流程自动化测试
- 启动游戏窗口
- 通过代码调用按钮事件（非坐标点击）
- 流程：主菜单 → 开始游戏 → 行前准备 → 地图选择 → 出发
- 验证是否成功进入史前世界副本
"""
import subprocess
import os
import time
import shutil

PROJECT_DIR = r"D:\youxi\soudache"
GODOT_EXE = r"C:\Tools\Godot_v4.6.1-stable_win64.exe"
TEST_SCRIPT = "scripts/flow_test.gd"
PROJECT_FILE = os.path.join(PROJECT_DIR, "project.godot")

# GDScript 测试代码
TEST_GDSCRIPT = '''extends Node

var current_step = 0
var result_text = ""

func _ready():
	print("========== 自动化流程测试 ==========")
	call_deferred("start_test")

func start_test():
	# 等待游戏完全加载
	await get_tree().create_timer(2.0).timeout
	
	current_step = 1
	print("\\n[步骤1] 验证主菜单...")
	
	var scene = get_tree().current_scene
	if scene and "MainMenu" in str(scene):
		print("  ✅ 主菜单已加载")
		result_text += "1.主菜单:OK "
	else:
		print("  ❌ 主菜单未加载，当前场景: " + str(scene))
		result_text += "1.主菜单:FAIL "
		finish_test(false)
		return
	
	# 步骤2: 点击"开始游戏"
	current_step = 2
	print("\\n[步骤2] 点击'开始游戏'...")
	
	var btn = scene.find_child("NewGame", true, false)
	if not btn:
		# 尝试其他路径
		btn = scene.get_node_or_null("Panel/VBox/NewGame")
	
	if btn:
		btn.pressed.emit()
		print("  ✅ 已触发开始游戏按钮")
		result_text += "2.开始游戏:OK "
	else:
		print("  ❌ 未找到开始游戏按钮")
		result_text += "2.开始游戏:FAIL "
		finish_test(false)
		return
	
	# 等待场景切换
	await get_tree().create_timer(1.5).timeout
	
	# 步骤3: 点击"行前准备"
	current_step = 3
	print("\\n[步骤3] 点击'行前准备'...")
	
	scene = get_tree().current_scene
	if not scene:
		print("  ❌ 场景为空")
		finish_test(false)
		return
	
	# 找行前准备按钮 - 可能叫Prepare或类似名称
	btn = scene.find_child("Prepare", true, false)
	if not btn:
		# 遍历找包含"准备"的按钮
		var all_nodes = scene.get_node(".").get_children()
		for n in all_nodes:
			if n is Button and ("准备" in str(n.text) or "Prepare" in str(n.name)):
				btn = n
				break
	
	if btn:
		btn.pressed.emit()
		print("  ✅ 已触发行前准备按钮")
		result_text += "3.行前准备:OK "
	else:
		print("  ⚠️ 未找到行前准备按钮，尝试直接切换...")
		# 直接切换场景
		get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
		result_text += "3.行前准备:DIR "
	
	await get_tree().create_timer(1.0).timeout
	
	# 步骤4: 地图选择（默认史前世界）
	current_step = 4
	print("\\n[步骤4] 地图选择...")
	
	scene = get_tree().current_scene
	if not scene:
		finish_test(false)
		return
	
	# 默认选中史前世界，找"出发"按钮
	btn = scene.find_child("Start", true, false)
	if not btn:
		btn = scene.get_node_or_null("CenterContainer/VBox/Start")
	
	if btn:
		btn.pressed.emit()
		print("  ✅ 已触发出发按钮")
		result_text += "4.地图选择:OK "
	else:
		print("  ❌ 未找到出发按钮")
		result_text += "4.地图选择:FAIL "
		finish_test(false)
		return
	
	await get_tree().create_timer(0.5).timeout
	
	# 步骤5: 进入副本
	current_step = 5
	print("\\n[步骤5] 进入副本...")
	
	# map_select.gd 会自动设置 GameData.is_in_game = true
	# 并切换到 game_world.tscn
	await get_tree().create_timer(2.0).timeout
	
	# 验证
	scene = get_tree().current_scene
	print("  当前场景: " + str(scene))
	
	if scene and "GameWorld" in str(scene.name):
		print("\\n" + "="*50)
		print("✅ 成功进入史前世界副本！")
		print("="*50)
		result_text += "5.进入副本:OK "
		finish_test(true)
	else:
		print("\\n" + "="*50)
		print("❌ 未成功进入副本")
		print("="*50)
		result_text += "5.进入副本:FAIL "
		finish_test(false)

func finish_test(success: bool):
	print("\\n最终结果: " + ("✅ 成功" if success else "❌ 失败"))
	print("流程: " + result_text)
	
	# 保持窗口显示一段时间，让用户看到
	await get_tree().create_timer(10.0).timeout
	
	print("\\n测试结束，退出游戏")
	get_tree().quit()
'''

def run_test():
	print("=" * 60)
	print("完整流程自动化测试")
	print("流程: 主菜单 → 开始游戏 → 行前准备 → 地图选择 → 出发")
	print("=" * 60)
	
	# 1. 读取 project.godot 备份
	with open(PROJECT_FILE, "r", encoding="utf-8") as f:
		original_content = f.read()
	
	# 2. 写入测试脚本
	test_path = os.path.join(PROJECT_DIR, TEST_SCRIPT)
	with open(test_path, "w", encoding="utf-8") as f:
		f.write(TEST_GDSCRIPT)
	print(f"\n1. 测试脚本已创建: {TEST_SCRIPT}")
	
	# 3. 修改 project.godot
	test_entry = 'FlowTest="*res://scripts/flow_test.gd"'
	if test_entry not in original_content:
		new_content = original_content.replace(
			'AssetGenerator="*res://scripts/systems/asset_generator.gd"',
			'AssetGenerator="*res://scripts/systems/asset_generator.gd"\nFlowTest="*res://scripts/flow_test.gd"'
		)
		with open(PROJECT_FILE, "w", encoding="utf-8") as f:
			f.write(new_content)
		print("2. 已添加到 project.godot")
	else:
		print("2. 已有配置")
	
	# 4. 启动 Godot（显示窗口）
	print("\n3. 启动游戏窗口...")
	print("   窗口标题应为: Pet Extraction (DEBUG)")
	
	proc = subprocess.Popen(
		[GODOT_EXE, "--path", PROJECT_DIR],
		creationflags=subprocess.CREATE_NEW_PROCESS_GROUP
	)
	print(f"   进程 PID: {proc.pid}")
	
	# 等待窗口启动
	time.sleep(5)
	
	# 检查进程
	if proc.poll() is None:
		print("   ✅ 游戏正在运行")
		# 等待测试完成（测试脚本会自动退出）
		try:
			proc.wait(timeout=60)
			print(f"   进程退出，退出码: {proc.returncode}")
		except subprocess.TimeoutExpired:
			print("   超时，终止进程")
			proc.terminate()
	else:
		print(f"   进程已退出，退出码: {proc.returncode}")
	
	# 5. 恢复 project.godot
	with open(PROJECT_FILE, "w", encoding="utf-8") as f:
		f.write(original_content)
	print("\n4. 已恢复 project.godot")
	
	# 6. 清理测试脚本
	if os.path.exists(test_path):
		os.remove(test_path)
	print("5. 已清理测试脚本")
	
	print("\n" + "=" * 60)
	print("测试完成")
	print("=" * 60)

if __name__ == "__main__":
	run_test()