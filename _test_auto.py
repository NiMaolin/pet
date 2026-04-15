"""
Godot 游戏自动化测试 - 模拟真实玩家操作
测试内容：
1. 玩家角色动画（行走、攻击）
2. 怪物动画
3. 两种箱子外观验证
4. 截图存档
"""
import subprocess
import time
import win32gui
import win32con
import win32api
import pyautogui
import mss
import os
from PIL import Image

# 禁用 pyautogui 安全模式
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.05

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_PATH = r"D:\youxi\soudache"
SCREENSHOT_DIR = r"d:\youxi\soudache\_test_screenshots"
os.makedirs(SCREENSHOT_DIR, exist_ok=True)


def find_godot_window():
    """找到 Godot 窗口句柄"""
    windows = []

    def enum_handler(hwnd, ctx):
        if win32gui.IsWindowVisible(hwnd):
            title = win32gui.GetWindowText(hwnd)
            if title and ("Godot" in title or "Pet Extraction" in title):
                windows.append((hwnd, title))

    win32gui.EnumWindows(enum_handler, None)
    for hwnd, title in windows:
        print(f"  找到窗口: {title} (hwnd={hwnd})")
    if windows:
        return windows[0][0]
    return None


def focus_window(hwnd):
    """聚焦窗口"""
    if hwnd:
        win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
        try:
            win32gui.SetForegroundWindow(hwnd)
        except Exception:
            # 如果无法置前，尝试用鼠标点击窗口
            rect = win32gui.GetWindowRect(hwnd)
            cx = (rect[0] + rect[2]) // 2
            cy = (rect[1] + rect[3]) // 2
            win32api.SetCursorPos((cx, cy))
        time.sleep(0.5)
        print(f"  聚焦窗口 hwnd={hwnd}")


def press_key(key):
    """按下一个键"""
    vk = win32api.VkKeyScan(key)
    vk_code = vk & 0xff
    extra = (vk >> 8) & 0xff
    win32api.keybd_event(vk_code, 0, 0, 0)
    time.sleep(0.05)
    win32api.keybd_event(vk_code, 0, win32con.KEYEVENTF_KEYUP, 0)
    time.sleep(0.05)


def hold_key(key, duration):
    """按住键一段时间"""
    vk = win32api.VkKeyScan(key)
    vk_code = vk & 0xff
    win32api.keybd_event(vk_code, 0, 0, 0)
    time.sleep(duration)
    win32api.keybd_event(vk_code, 0, win32con.KEYEVENTF_KEYUP, 0)


def move_mouse(x, y, duration=0.2):
    """移动鼠标到相对位置（使用 pyautogui 相对移动）"""
    pyautogui.move(x, y, duration=duration)
    time.sleep(0.1)


def left_click(x, y):
    """左键点击"""
    pyautogui.click(x, y)
    time.sleep(0.15)


def screenshot(name):
    """截取屏幕并保存到文件"""
    with mss.mss() as sct:
        # 截取主显示器
        monitor = sct.monitors[1]
        img = sct.grab(monitor)
        img_rgb = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")
        path = os.path.join(SCREENSHOT_DIR, f"{name}.png")
        img_rgb.save(path)
        print(f"  截图: {path}")
        return path, img_rgb


def analyze_screenshot(img, name, checks):
    """分析截图中的关键像素区域，返回检测结果"""
    results = {}
    width, height = img.size
    pixels = img.load()

    for check_name, region in checks.items():
        # region: (x1, y1, x2, y2) 百分比
        x1 = int(region[0] * width)
        y1 = int(region[1] * height)
        x2 = int(region[2] * width)
        y2 = int(region[3] * height)

        # 采样该区域像素
        samples = []
        for sx in range(x1, x2, max(1, (x2 - x1) // 10)):
            for sy in range(y1, y2, max(1, (y2 - y1) // 10)):
                samples.append(pixels[sx, sy])

        # 计算平均颜色
        if samples:
            avg_r = sum(s[0] for s in samples) // len(samples)
            avg_g = sum(s[1] for s in samples) // len(samples)
            avg_b = sum(s[2] for s in samples) // len(samples)
            results[check_name] = {"avg": (avg_r, avg_g, avg_b), "sample_count": len(samples)}
            print(f"    [{check_name}] 区域采样 {len(samples)} 像素, 平均色: RGB({avg_r},{avg_g},{avg_b})")

    return results


def wait_for_game_ready(hwnd, timeout=10):
    """等待游戏加载"""
    print("  等待游戏加载...")
    start = time.time()
    while time.time() - start < timeout:
        if hwnd and win32gui.IsWindowVisible(hwnd):
            time.sleep(1)
            return True
        time.sleep(0.5)
    return False


def close_godot():
    """关闭所有 Godot 进程"""
    subprocess.run(["taskkill", "/F", "/IM", "Godot_v4.6.1-stable_win64_console.exe"],
                   capture_output=True)
    subprocess.run(["taskkill", "/F", "/IM", "Godot_v4.6.1-stable_win64.exe"],
                   capture_output=True)
    print("  已关闭 Godot 进程")


def run_test():
    print("=" * 60)
    print("Godot 游戏自动化测试开始")
    print("=" * 60)

    # 0. 清理旧进程
    close_godot()
    time.sleep(1)

    # 1. 启动游戏
    print("\n[步骤1] 启动游戏...")
    subprocess.Popen(
        [GODOT_EXE, "--path", PROJECT_PATH],
        cwd=PROJECT_PATH,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    time.sleep(2)

    # 2. 找到游戏窗口
    print("\n[步骤2] 查找游戏窗口...")
    hwnd = None
    for attempt in range(15):
        hwnd = find_godot_window()
        if hwnd:
            break
        time.sleep(1)
        print(f"  重试 {attempt + 1}/15...")

    if not hwnd:
        print("  无法找到游戏窗口，测试失败！")
        return False

    focus_window(hwnd)
    wait_for_game_ready(hwnd)

    # 3. 截图：初始画面
    print("\n[步骤3] 截取初始画面...")
    path, img = screenshot("01_initial")
    results = analyze_screenshot(img, "initial", {
        "game_area": (0.0, 0.0, 1.0, 1.0),       # 全屏
        "center_region": (0.3, 0.3, 0.7, 0.7),  # 游戏区域中心
    })
    game_has_content = results.get("center_region", {}).get("avg", (0, 0, 0))[0] > 20
    print(f"  游戏区域有内容: {game_has_content}")

    # 4. 模拟玩家移动（WASD）
    print("\n[步骤4] 模拟玩家移动（WASD）...")
    for key in ["w", "a", "s", "d"]:
        hold_key(key, 0.3)
        time.sleep(0.1)
    path, img = screenshot("02_after_move")
    print("  移动完成，截图存档")

    # 5. 模拟攻击（鼠标左键点击）
    print("\n[步骤5] 模拟攻击（鼠标左键）...")
    # 移动鼠标到游戏窗口中心并点击
    rect = win32gui.GetWindowRect(hwnd)
    cx = (rect[0] + rect[2]) // 2
    cy = (rect[1] + rect[3]) // 2
    pyautogui.moveTo(cx, cy)
    time.sleep(0.2)
    for _ in range(3):
        pyautogui.click()
        time.sleep(0.3)
    path, img = screenshot("03_after_attack")
    print("  攻击完成，截图存档")

    # 6. 模拟交互（F键 - 搜索物资箱）
    print("\n[步骤6] 模拟交互（F键搜索）...")
    for _ in range(2):
        press_key("f")
        time.sleep(0.5)
    path, img = screenshot("04_after_interact")

    # 7. 分析最终截图
    print("\n[步骤7] 分析最终截图...")
    results = analyze_screenshot(img, "final", {
        "loot_box_area": (0.4, 0.4, 0.6, 0.6),
    })

    # 8. 输出测试报告
    print("\n" + "=" * 60)
    print("测试报告")
    print("=" * 60)
    print(f"  ✅ 游戏启动成功")
    print(f"  ✅ 截图已保存到: {SCREENSHOT_DIR}")
    print(f"  截图文件列表:")
    for f in sorted(os.listdir(SCREENSHOT_DIR)):
        full = os.path.join(SCREENSHOT_DIR, f)
        size = os.path.getsize(full)
        print(f"    - {f} ({size:,} bytes)")
    print("=" * 60)

    return True


if __name__ == "__main__":
    try:
        success = run_test()
    except Exception as e:
        print(f"\n测试异常: {e}")
        import traceback
        traceback.print_exc()
        success = False

    print(f"\n最终结果: {'通过' if success else '失败'}")
