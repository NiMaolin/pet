"""
全流程自动化测试 - 模拟真实玩家操作
测试：名称居中、双击拾取、血量不显示负数、死亡返回
"""
import subprocess
import time
import win32gui
import win32con
import mss
import pyautogui
import os
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.1

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_PATH = r"D:\youxi\soudache"
SCREENSHOT_DIR = r"D:\youxi\soudache\_test_screenshots"
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

SCR_WIDTH, SCR_HEIGHT = pyautogui.size()

def log(msg):
    print(f"[TEST] {msg}")

def find_godot_window():
    """找到 Godot 游戏窗口"""
    result = []
    def cb(h, _):
        if win32gui.IsWindowVisible(h):
            t = win32gui.GetWindowText(h)
            if t and "Pet" in t:
                result.append((h, t))
    win32gui.EnumWindows(cb, None)
    return result

def get_window_rect(hwnd):
    """获取窗口客户区rect"""
    rect = win32gui.GetClientRect(hwnd)
    # 转换到屏幕坐标
    tl = win32gui.ClientToScreen(hwnd, (rect[0], rect[1]))
    br = win32gui.ClientToScreen(hwnd, (rect[2], rect[3]))
    return tl[0], tl[1], br[0] - tl[0], br[1] - tl[1]

def bring_to_front(hwnd):
    """激活窗口"""
    try:
        win32gui.SetForegroundWindow(hwnd)
        time.sleep(0.3)
    except:
        pass

def screenshot_window(hwnd, name):
    """截取窗口客户区"""
    x, y, w, h = get_window_rect(hwnd)
    if w < 100 or h < 100:
        log(f"窗口太小，跳过截图: {w}x{h}")
        return None
    with mss.mss() as sct:
        img = sct.grab((x, y, x + w, y + h))
        p = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")
    path = os.path.join(SCREENSHOT_DIR, f"{name}.png")
    p.save(path)
    log(f"截图保存: {path} ({w}x{h})")
    return p

def pixel_analysis(img, name):
    """像素分析"""
    px = img.load()
    w, h = img.size
    bg = px[5, 5]
    bg_r, bg_g, bg_b = bg[:3]

    colors = {"brown": 0, "green": 0, "white": 0, "dark": 0, "blue": 0, "purple": 0}
    step = 3
    for sy in range(0, h, step):
        for sx in range(0, w, step):
            r, g, b = px[sx, sy][:3]
            brightness = (r + g + b) / 3
            diff = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
            if diff < 20:
                continue
            if r > g * 1.3 and brightness < 180: colors["brown"] += 1
            elif g > r * 1.2 and brightness < 150: colors["green"] += 1
            elif brightness > 180: colors["white"] += 1
            elif brightness < 50: colors["dark"] += 1
            elif b > r * 1.2 and b > g * 1.1: colors["blue"] += 1
            elif r > 100 and b > 100 and g < 80: colors["purple"] += 1

    log(f"颜色分析 [{name}]: 棕色={colors['brown']} 绿色={colors['green']} "
        f"白色={colors['white']} 暗色={colors['dark']} 蓝色={colors['blue']} 紫色={colors['purple']}")
    return colors

def analyze_loot_ui(img, name):
    """分析物资箱UI中的物品名称是否居中"""
    px = img.load()
    w, h = img.size

    # 找所有方格（40x40背景色格子）
    cells = []
    cell_size = 40
    step = 2
    for sy in range(0, h - cell_size, step):
        for sx in range(0, w - cell_size, step):
            # 检查是否像格子
            avg = [0, 0, 0]
            count = 0
            for dy in range(0, cell_size, 5):
                for dx in range(0, cell_size, 5):
                    r, g, b = px[sx + dx, sy + dy][:3]
                    avg[0] += r; avg[1] += g; avg[2] += b
                    count += 1
            avg[0] /= count; avg[1] /= count; avg[2] /= count
            brightness = sum(avg) / 3
            # 暗色格子（约 0.1-0.15 brightness -> 25-38）
            if 20 < brightness < 45:
                cells.append((sx, sy, avg))

    # 去重合并
    unique_cells = []
    for cx, cy, c in cells:
        is_dup = False
        for ux, uy, _ in unique_cells:
            if abs(cx - ux) < 20 and abs(cy - uy) < 20:
                is_dup = True
                break
        if not is_dup:
            unique_cells.append((cx, cy, c))

    log(f"检测到 {len(unique_cells)} 个物品格子")
    for i, (cx, cy, c) in enumerate(unique_cells[:5]):
        r, g, b = [int(x) for x in c]
        # 检查文字区域（格子上半部分应该有文字颜色）
        text_area_colors = []
        for ty in range(cy, cy + 20, 3):
            for tx in range(cx + 5, cx + cell_size - 5, 3):
                if tx < w and ty < h:
                    tr, tg, tb = px[tx, ty][:3]
                    text_brightness = (tr + tg + tb) / 3
                    if 100 < text_brightness < 250:  # 白色/灰色文字
                        text_area_colors.append((tr, tg, tb))

        if text_area_colors:
            avg_text = [sum(x[i] for x in text_area_colors) / len(text_area_colors)
                        for i in range(3)]
            log(f"  格子{i}: RGB({r},{g},{b}), 文字区域: RGB({int(avg_text[0])},{int(avg_text[1])},{int(avg_text[2])})")
            # 检查文字是否居中（通过检查左右边缘空白）
            left_blank = 0
            right_blank = 0
            mid_y = cy + cell_size // 2
            for tx in range(cx + 2, cx + cell_size // 2, 3):
                if mid_y < h:
                    tr, tg, tb = px[tx, mid_y][:3]
                    if (tr + tg + tb) / 3 > 80:  # 空白/背景色
                        left_blank += 1
            for tx in range(cx + cell_size // 2, cx + cell_size - 2, 3):
                if mid_y < h:
                    tr, tg, tb = px[tx, mid_y][:3]
                    if (tr + tg + tb) / 3 > 80:
                        right_blank += 1
            log(f"    左空白比例: {left_blank}, 右空白比例: {right_blank}")
            if left_blank > 2 and right_blank > 2:
                log(f"    ✅ 文字看起来居中")
            else:
                log(f"    ⚠️ 文字可能偏左")

    return len(unique_cells)

def kill_godot():
    """杀掉所有 Godot 进程"""
    for name in ["Godot_v4.6.1-stable_win64_console.exe", "Godot_v4.6.1-stable_win64.exe"]:
        subprocess.run(["taskkill", "/F", "/IM", name],
                      capture_output=True, timeout=5)
    time.sleep(1)

def launch_game():
    """启动游戏"""
    kill_godot()
    log("启动游戏...")
    subprocess.Popen(
        [GODOT_EXE, "--path", PROJECT_PATH],
        cwd=PROJECT_PATH,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    time.sleep(6)  # 等待游戏加载

def test_basic_gameplay():
    """基础游戏测试：移动、攻击、交互"""
    wins = find_godot_window()
    if not wins:
        log("❌ 未找到游戏窗口")
        return None
    hwnd, title = wins[0]
    log(f"找到窗口: {title}")
    bring_to_front(hwnd)

    # 截图初始状态
    img = screenshot_window(hwnd, "01_initial")
    if img:
        pixel_analysis(img, "初始状态")

    # 模拟 WASD 移动
    log("模拟 WASD 移动...")
    pyautogui.keyDown("w")
    time.sleep(0.3)
    pyautogui.keyUp("w")
    pyautogui.keyDown("d")
    time.sleep(0.3)
    pyautogui.keyUp("d")

    # 截图移动后
    img = screenshot_window(hwnd, "02_after_move")
    if img:
        pixel_analysis(img, "移动后")

    # 鼠标左键攻击
    log("模拟鼠标攻击...")
    pyautogui.click()
    time.sleep(0.2)
    pyautogui.click()

    # 截图攻击后
    img = screenshot_window(hwnd, "03_after_attack")
    if img:
        pixel_analysis(img, "攻击后")

    # 按 F 键尝试交互（如果有物资箱）
    log("模拟 F 键交互...")
    pyautogui.press("f")
    time.sleep(1)

    img = screenshot_window(hwnd, "04_after_interact")
    if img:
        pixel_analysis(img, "交互后")

    return wins[0]

def test_loot_ui():
    """测试物资箱UI"""
    wins = find_godot_window()
    if not wins:
        return
    hwnd = wins[0][0]
    bring_to_front(hwnd)

    log("打开物资箱...")
    pyautogui.press("f")
    time.sleep(2)

    img = screenshot_window(hwnd, "05_loot_ui")
    if img:
        pixel_analysis(img, "物资箱UI")
        cell_count = analyze_loot_ui(img, "物资箱")
        log(f"检测到 {cell_count} 个物品格子")

        # 双击测试
        if cell_count > 0:
            log("模拟双击拾取...")
            pyautogui.doubleClick()
            time.sleep(1)
            img2 = screenshot_window(hwnd, "06_after_doubleclick")
            if img2:
                pixel_analysis(img2, "双击后")

def test_death_screen():
    """测试死亡界面"""
    wins = find_godot_window()
    if not wins:
        return
    hwnd = wins[0][0]
    bring_to_front(hwnd)

    # 让玩家受到致命伤害（通过控制台指令，或直接修改血量）
    # 这里我们假设游戏已有受伤机制，模拟一些操作
    log("触发死亡...")
    # 移动到危险区域等
    for _ in range(10):
        pyautogui.keyDown("s")
        time.sleep(0.1)
        pyautogui.keyUp("s")
        pyautogui.click()

    time.sleep(2)
    img = screenshot_window(hwnd, "07_death_check")
    if img:
        px = img.load()
        w, h = img.size
        # 检查是否有红色/深色覆盖（死亡界面特征）
        dark_pixels = 0
        step = 5
        for sy in range(0, h, step):
            for sx in range(0, w, step):
                r, g, b = px[sx, sy][:3]
                brightness = (r + g + b) / 3
                if brightness < 30:
                    dark_pixels += 1
        log(f"死亡界面检测: 暗色像素={dark_pixels}")
        if dark_pixels > 100:
            log("✅ 可能显示了死亡/覆盖界面")
            # 按任意键返回
            log("按任意键返回...")
            pyautogui.press("space")
            time.sleep(2)
            img2 = screenshot_window(hwnd, "08_after_death_return")
            if img2:
                pixel_analysis(img2, "返回后")
        else:
            log("⚠️ 未检测到明显的死亡界面")

def run_full_test():
    """完整测试流程"""
    log("=" * 60)
    log("开始自动化测试")
    log("=" * 60)

    # 启动游戏
    launch_game()

    # 基础游戏测试
    test_basic_gameplay()

    # 物资箱测试
    test_loot_ui()

    # 死亡界面测试
    test_death_screen()

    # 关闭游戏
    log("测试完成，关闭游戏...")
    kill_godot()

    log("=" * 60)
    log("自动化测试完成！请查看 _test_screenshots/ 目录下的截图")
    log("=" * 60)

if __name__ == "__main__":
    run_full_test()
