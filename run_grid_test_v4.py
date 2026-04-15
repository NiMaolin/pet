#!/usr/bin/env python3
"""
run_grid_test_v4.py - 格子系统 v4 自动化测试启动器
通过 Godot 运行 grid_system_test_v4.gd 脚本，不使用 UI 坐标
"""
import subprocess
import sys
import os
import time
import re

PROJECT_DIR = r"D:\youxi\soudache"
GODOT_EXE   = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
TEST_SCENE  = "res://scenes/grid_test_v4.tscn"
TIMEOUT     = 40  # 最长等待秒数

def find_godot():
    candidates = [
        GODOT_EXE,
        r"C:\Program Files\Godot\Godot_v4.6-stable_win64.exe",
        r"C:\Godot\Godot_v4.6-stable_win64.exe",
    ]
    # 也从 PATH 查找
    import shutil
    godot_path = shutil.which("godot") or shutil.which("godot4")
    if godot_path:
        candidates.insert(0, godot_path)
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None

def run_test():
    godot = find_godot()
    if not godot:
        print("❌ 找不到 Godot 可执行文件！")
        print("   请确认 Godot 4.6 已安装，或修改脚本中的 GODOT_EXE 路径")
        sys.exit(1)

    print(f"🚀 使用 Godot: {godot}")
    print(f"📂 项目目录: {PROJECT_DIR}")
    print(f"🧪 测试场景: {TEST_SCENE}")
    print("=" * 55)

    cmd = [
        godot,
        "--headless",
        "--path", PROJECT_DIR,
        TEST_SCENE,
        "--quit-after", "30",
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=TIMEOUT,
            cwd=PROJECT_DIR,
        )
    except subprocess.TimeoutExpired:
        print(f"❌ 测试超时（>{TIMEOUT}s），可能卡死")
        sys.exit(1)
    except FileNotFoundError:
        print(f"❌ 无法启动 Godot: {godot}")
        sys.exit(1)

    # 解析输出
    output = result.stdout + result.stderr
    lines  = output.splitlines()

    # 打印相关行
    in_test = False
    pass_count = 0
    fail_count = 0
    for line in lines:
        if "GRID SYSTEM TEST" in line or "GRID TEST" in line:
            in_test = True
        if in_test or "✅" in line or "❌" in line or "PASS" in line or "FAIL" in line:
            print(line)
        if "PASS:" in line:
            pass_count += 1
        if "FAIL:" in line:
            fail_count += 1

    print("=" * 55)
    print(f"\n📊 汇总: {pass_count} PASS / {fail_count} FAIL")

    if fail_count == 0 and pass_count > 0:
        print("🎉 所有测试通过！")
        return 0
    elif fail_count > 0:
        print(f"⚠️  {fail_count} 项测试失败，请检查")
        return 1
    else:
        print("⚠️  未检测到测试输出，请检查场景是否正确")
        # 打印完整输出供调试
        print("\n--- 完整输出 ---")
        for line in lines[-40:]:
            print(line)
        return 2

if __name__ == "__main__":
    sys.exit(run_test())
