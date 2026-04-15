#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
游戏自动化测试脚本 - 事件驱动模式
======================================
通过 AutoRunner 的 --auto-test 参数驱动完整流程，
每个步骤通过调用 GDScript 场景方法（非坐标点击）执行。
截图记录每步结果供验证。

流程：主菜单 → 开始游戏 → 行前准备 → 出发(史前世界) → 进入副本
"""

import subprocess
import time
import os
import sys
import win32gui
import win32con
import win32api
import mss
from PIL import Image
from datetime import datetime

# ── 配置 ──────────────────────────────────────────────
GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
GODOT_CONSOLE_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_PATH = r"D:\youxi\soudache"
SCREENSHOT_DIR = r"D:\youxi\soudache\_test_screenshots"
WINDOW_TITLE_PREFIX = "Pet"  # 用更短的前缀匹配
EXPECTED_FINAL_SCENE = "game_world"     # 期望最终进入的场景名

os.makedirs(SCREENSHOT_DIR, exist_ok=True)


def log(msg):
    """带时间戳的日志"""
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    # 去除 emoji 避免在 Windows GBK 终端下报错
    safe_msg = msg.replace("✅", "[OK]").replace("⚠", "[WARN]").replace("🎮", "[GAME]")
    print(f"[{ts}] {safe_msg}")


def kill_godot():
    """关闭所有 Godot 进程"""
    for name in [
        "Godot_v4.6.1-stable_win64_console.exe",
        "Godot_v4.6.1-stable_win64.exe"
    ]:
        try:
            subprocess.run(
                ["taskkill", "/F", "/IM", name],
                capture_output=True,
                timeout=5,
            )
        except Exception:
            pass
    time.sleep(1)
    log("已清理 Godot 进程")


def find_game_window():
    """
    查找游戏窗口。
    返回 (hwnd, title) 或 None
    搜索包含 'Pet' 或 'Godot' 的可见窗口
    """
    result = []

    def enum_cb(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd):
            return
        title = win32gui.GetWindowText(hwnd)
        cls = win32gui.GetClassName(hwnd)
        # 匹配 Pet Extraction 或任何 Godot 引擎窗口
        if title and ("Pet" in title or "Godot" in title) and "Engine" in cls:
            result.append((hwnd, title, cls))
        elif title and "Pet" in title:
            result.append((hwnd, title, cls))

    win32gui.EnumWindows(enum_cb, None)
    
    # 也打印找到的所有相关窗口（调试用）
    all_wins = []
    def enum_all(hwnd, _):
        if win32gui.IsWindowVisible(hwnd):
            t = win32gui.GetWindowText(hwnd)
            c = win32gui.GetClassName(hwnd)
            if t and ("Pet" in t or "Godot" in t or "Extraction" in t):
                all_wins.append((hwnd, t, c))
    win32gui.EnumWindows(enum_all, None)
    
    if all_wins:
        log(f"检测到 {len(all_wins)} 个候选窗口:")
        for h, t, c in all_wins:
            log(f"   hwnd={h} title='{t}' class={c}")
    
    if result:
        hwnd, title, cls = result[0]
        log(f"选中窗口: '{title}' (class={cls}, hwnd={hwnd})")
        return hwnd, title
    return None


def focus_window(hwnd):
    """将窗口置前"""
    try:
        # 最小化再恢复，强制置前
        win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
        win32gui.SetForegroundWindow(hwnd)
    except Exception:
        pass
    time.sleep(0.3)


def get_window_screen_rect(hwnd):
    """
    获取窗口在屏幕上的位置和大小。
    Godot 引擎窗口可能不支持 GetClientRect，回退到 GetWindowRect。
    """
    # 方法1: 尝试获取客户区
    try:
        rect = win32gui.GetClientRect(hwnd)
        if rect and rect[2] > 0 and rect[3] > 0:
            tl = win32gui.ClientToScreen(hwnd, (rect[0], rect[1]))
            br = win32gui.ClientToScreen(hwnd, (rect[2], rect[3]))
            return tl[0], tl[1], br[0] - tl[0], br[1] - tl[1]
    except Exception as e:
        log(f"  GetClientRect 失败 ({e}), 回退到 GetWindowRect")

    # 方法2: 使用整个窗口矩形（去除标题栏）
    try:
        rect = win32gui.GetWindowRect(hwnd)
        x, y, x2, y2 = rect
        w, h = x2 - x, y2 - y
        if h > 60:  # 去除约32px标题栏
            return x, y + 32, w, h - 32
        return x, y, w, h
    except Exception as e:
        log(f"  GetWindowRect 也失败 ({e})")
        return None


def screenshot_window(hwnd, name):
    """截取游戏窗口并保存"""
    focus_window(hwnd)
    time.sleep(0.3)

    result = get_window_screen_rect(hwnd)
    if not result:
        log(f"[WARN] 无法获取窗口位置")
        return None
    x, y, w, h = result
    if w < 100 or h < 100:
        log(f"[WARN] 窗口太小 ({w}x{h})，跳过截图")
        return None

    with mss.mss() as sct:
        img = sct.grab({"left": x, "top": y, "width": w, "height": h})
        pil_img = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")

    path = os.path.join(SCREENSHOT_DIR, f"{name}.png")
    pil_img.save(path)
    log(f"截图: {name}.png ({w}x{h}) -> {path}")
    return pil_img


def quick_pixel_check(img):
    """快速像素分析，返回基本信息"""
    if img is None:
        return {"size": (0, 0), "avg_brightness": 0, "content_pixels": 0}
    px = img.load()
    w, h = img.size
    total_b = 0
    count = 0
    step = max(1, min(w, h) // 80)
    for sy in range(0, h, step):
        for sx in range(0, w, step):
            r, g, b = px[sx, sy]
            total_b += (r + g + b) / 3
            count += 1
    avg = total_b / max(count, 1)

    # 检测是否有明显内容（非纯黑/纯色）
    non_uniform = 0
    ref = px[w // 2, h // 2][:3]
    for sy in range(10, h - 10, step * 3):
        for sx in range(10, w - 10, step * 3):
            r, g, b = px[sx, sy]
            diff = abs(r - ref[0]) + abs(g - ref[1]) + abs(b - ref[2])
            if diff > 30:
                non_uniform += 1

    return {
        "size": (w, h),
        "avg_brightness": avg,
        "content_pixels": non_uniform,
    }


def launch_game_with_autorunner():
    """
    使用 --auto-test 启动游戏，
    AutoRunner 会自动执行：开始游戏→行前准备→出发→进入副本
    使用非控制台版 Godot 以获得更好的窗口行为
    """
    log("启动游戏 (带 --auto-test 自动流程)...")

    # 优先使用非控制台版本（窗口标题更稳定）
    exe_to_use = GODOT_EXE
    if not os.path.isfile(GODOT_EXE):
        log(f"  非控制版不存在，回退到控制台版")
        exe_to_use = GODOT_CONSOLE_EXE

    proc = subprocess.Popen(
        [exe_to_use, "--path", PROJECT_PATH, "--auto-test"],
        cwd=PROJECT_PATH,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    log(f"Godot 进程 PID={proc.pid} (exe={os.path.basename(exe_to_use)})")
    return proc


def wait_for_window(timeout=30):
    """等待游戏窗口出现"""
    log(f"等待游戏窗口出现 (超时 {timeout}s)...")
    start = time.time()
    while time.time() - start < timeout:
        result = find_game_window()
        if result:
            return result
        time.sleep(0.5)
    log("[FAIL] 超时，未找到游戏窗口")
    return None


def main():
    log("=" * 60)
    log("Pet Extraction 自动化测试 - 事件驱动模式")
    log("=" * 60)

    # Step 0: 清理旧进程
    log("\n--- Step 0: 清理 ---")
    kill_godot()

    # Step 1: 启动游戏（AutoRunner 自动跑流程）
    log("\n--- Step 1: 启动游戏 ---")
    proc = launch_game_with_autorunner()

    # Step 2: 等待窗口
    log("\n--- Step 2: 等待窗口 ---")
    window_info = wait_for_window(timeout=45)
    if not window_info:
        proc.terminate()
        return False
    hwnd, title = window_info

    # ── 截图阶段：在 AutoRunner 执行各步骤时截图 ──
    results = {}

    # 辅助函数：安全截图（自动重新查找窗口）
    def safe_screenshot(name, wait_before=0):
        """尝试截图，如果句柄失效则重新找窗口"""
        nonlocal hwnd
        if wait_before > 0:
            time.sleep(wait_before)
        
        # 每次截图前尝试重新获取有效句柄
        for attempt in range(3):
            try:
                # 测试句柄是否有效
                if win32gui.IsWindow(hwnd):
                    focus_window(hwnd)
                    img = screenshot_window(hwnd, name)
                    return img
                else:
                    log(f"  句柄无效，重新查找...")
            except Exception as e:
                log(f"  句柄异常: {e}, 重新查找...")
            
            # 重新查找窗口
            time.sleep(1)
            result = find_game_window()
            if result:
                hwnd, title = result
                continue
            
        log(f"  [WARN] 无法截图 {name}")
        return None

    # 截图1: 主菜单加载完成（Step 1 执行前）
    log("\n--- Screenshot 1: Main Menu ---")
    img1 = safe_screenshot("01_main_menu", wait_before=2)
    if img1:
        info = quick_pixel_check(img1)
        results["Main Menu"] = info
        log(f"  brightness={info['avg_brightness']:.1f}, content={info['content_pixels']}")

    # 截图2: 准备界面（Step 2 执行后）
    log("\n--- Screenshot 2: Prep Screen ---")
    img2 = safe_screenshot("02_prep_screen", wait_before=3)
    if img2:
        info = quick_pixel_check(img2)
        results["Prep Screen"] = info
        log(f"  brightness={info['avg_brightness']:.1f}, content={info['content_pixels']}")

    # 截图3: 地图选择（Step 3 执行后）
    log("\n--- Screenshot 3: Map Select ---")
    img3 = safe_screenshot("03_map_select", wait_before=3)
    if img3:
        info = quick_pixel_check(img3)
        results["Map Select"] = info
        log(f"  brightness={info['avg_brightness']:.1f}, content={info['content_pixels']}")

    # 截图4: 进入游戏世界/副本（Step DONE）
    log("\n--- Screenshot 4: Game World (Prehistoric) ---")
    img4 = safe_screenshot("04_game_world", wait_before=4)
    if img4:
        info = quick_pixel_check(img4)
        results["Game World"] = info
        log(f"  brightness={info['avg_brightness']:.1f}, content={info['content_pixels']}")

    # 再等一会确保完全稳定
    time.sleep(2)
    img_final = safe_screenshot("05_stable_world", wait_before=0)

    # ── 结果汇总 ──
    log("\n" + "=" * 60)
    log("测试结果汇总")
    log("=" * 60)

    all_ok = True
    for step_name, info in results.items():
        has_content = info["content_pixels"] > 20
        status = "[PASS]" if has_content else "[?]"
        if not has_content:
            all_ok = False
        log(f"  {status} {step_name}: "
            f"{info['size'][0]}x{info['size'][1]}, "
            f"brightness={info['avg_brightness']:.0f}, "
            f"content={info['content_pixels']}")

    if "Game World" in results:
        gw = results["Game World"]
        if gw["content_pixels"] > 50:
            log("\n[SUCCESS] Entered Prehistoric World dungeon!")
            log("   Game window stays open, please verify manually.")
        else:
            log("\n[WARN] Game world screenshot has little content, may not be fully loaded")
            all_ok = False

    log("=" * 60)

    # 不关闭游戏！保持开启供人工验证
    log("游戏保持运行中，PID=" + str(proc.pid))
    log(f"截图目录: {SCREENSHOT_DIR}")

    return all_ok


if __name__ == "__main__":
    try:
        ok = main()
        sys.exit(0 if ok else 1)
    except KeyboardInterrupt:
        log("\n用户中断")
        sys.exit(130)
    except Exception as e:
        log(f"\n错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
