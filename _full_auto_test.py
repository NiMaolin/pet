"""
Godot 搜打撤游戏 - 完整自动化测试
功能：
1. 启动游戏
2. 模拟 WASD 移动
3. 模拟鼠标左键攻击
4. 模拟 F 键交互
5. 截图验证：玩家、敌人、箱子
6. 像素级颜色分析验证美术资源
"""
import subprocess, time, win32gui, win32con, win32api, mss, os, random
from PIL import Image

pyautogui_FAKE = __import__("pyautogui")
pyautogui_FAKE.FAILSAFE = False
pyautogui_FAKE.PAUSE = 0.05

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_PATH = r"D:\youxi\soudache"
OUT_DIR = r"d:\youxi\soudache\_test_screenshots"
os.makedirs(OUT_DIR, exist_ok=True)


def close_godot():
    subprocess.run(["taskkill","/F","/IM","Godot_v4.6.1-stable_win64_console.exe"], capture_output=True)
    subprocess.run(["taskkill","/F","/IM","Godot_v4.6.1-stable_win64.exe"], capture_output=True)
    print("[OK] Godot processes closed")


def find_game_window():
    """找到运行中的游戏窗口（class=Engine）"""
    def cb(h, _):
        if win32gui.IsWindowVisible(h):
            t = win32gui.GetWindowText(h)
            c = win32gui.GetClassName(h)
            if t and "Pet" in t and "Engine" in c:
                return h
    wins = []
    def enum_cb(h, _):
        if win32gui.IsWindowVisible(h):
            t = win32gui.GetWindowText(h)
            c = win32gui.GetClassName(h)
            if t and ("Pet" in t or "Godot" in t):
                wins.append((h, t, c))
    win32gui.EnumWindows(enum_cb, None)
    return wins


def focus_window(hwnd):
    try:
        win32gui.SetForegroundWindow(hwnd)
    except:
        pass
    time.sleep(0.5)


def snap_game_window(hwnd, name):
    """截取游戏窗口（去除标题栏）"""
    focus_window(hwnd)
    time.sleep(0.3)
    rect = win32gui.GetWindowRect(hwnd)
    x, y = rect[0], rect[1]
    w, h = rect[2] - rect[0], rect[3] - rect[1]

    with mss.mss() as sct:
        img = sct.grab((x, y, rect[2], rect[3]))
        p = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")

    # 去除标题栏 (32px)
    if h > 60:
        p = p.crop((0, 32, w, h))

    path = os.path.join(OUT_DIR, name + ".png")
    p.save(path)
    print(f"  [{name}] {p.size[0]}x{p.size[1]} -> {path}")
    return p


def analyze_screenshot(img, name=""):
    """分析截图中的游戏内容"""
    w, h = img.size
    px = img.load()

    # 采样背景色
    bg_samples = [px[5, 5], px[w-5, 5], px[w//2, 5], px[5, h//2]]
    bg_r = sum(s[0] for s in bg_samples) // len(bg_samples)
    bg_g = sum(s[1] for s in bg_samples) // len(bg_samples)
    bg_b = sum(s[2] for s in bg_samples) // len(bg_samples)
    print(f"  [{name}] background: RGB({bg_r},{bg_g},{bg_b})")

    # 扫描所有像素，找非背景区域
    step = max(1, min(w, h) // 120)
    interesting = []
    for sy in range(0, h, step):
        for sx in range(0, w, step):
            r, g, b = px[sx, sy]
            diff = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
            brightness = (r + g + b) / 3
            if diff > 25 and brightness > 5:
                interesting.append((sx, sy, r, g, b, diff, brightness))

    interesting.sort(key=lambda x: x[5], reverse=True)

    # 分类统计
    categories = {
        "brown_wood (enemy box)": [],
        "green_metal (map box)": [],
        "blue (player)": [],
        "red (attack flash)": [],
        "white_hud": [],
        "other": [],
    }

    for item in interesting:
        sx, sy, r, g, b, diff, brightness = item
        # 棕木箱: R 明显大于 G 和 B
        if r > g and r > b and brightness < 150 and r - g > 15:
            categories["brown_wood (enemy box)"].append(item)
        # 军绿箱: G 明显大于 R 和 B
        elif g > r and g > b and brightness < 140 and g - r > 10:
            categories["green_metal (map box)"].append(item)
        # 蓝色玩家
        elif b > r and b > g and brightness > 40:
            categories["blue (player)"].append(item)
        # 红色
        elif r > 80 and r > g * 1.5 and r > b * 1.5:
            categories["red (attack flash)"].append(item)
        # 白色 HUD
        elif brightness > 160 and diff < 60:
            categories["white_hud"].append(item)
        else:
            categories["other"].append(item)

    print(f"  [{name}] Color analysis ({len(interesting)} non-background pixels):")
    for cat, items in categories.items():
        if items:
            print(f"    {cat}: {len(items)} pixels")
            # 显示最强的几个
            for item in items[:2]:
                sx, sy, r, g, b = item[0], item[1], item[2], item[3], item[4]
                print(f"      at ({sx:4d},{sy:4d}) RGB({r:3d},{g:3d},{b:3d})")

    return interesting, categories


def simulate_movement():
    """模拟 WASD 移动"""
    for key in ["w", "a", "s", "d"]:
        vk = win32api.VkKeyScan(key) & 0xff
        win32api.keybd_event(vk, 0, 0, 0)
        time.sleep(0.25)
        win32api.keybd_event(vk, 0, win32con.KEYEVENTF_KEYUP, 0)
        time.sleep(0.1)


def simulate_attack(hwnd):
    """模拟鼠标左键攻击"""
    rect = win32gui.GetWindowRect(hwnd)
    cx, cy = (rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2
    pyautogui_FAKE.moveTo(cx, cy)
    time.sleep(0.2)
    for i in range(3):
        pyautogui_FAKE.click()
        time.sleep(0.5)


def simulate_interact():
    """模拟 F 键交互"""
    for _ in range(2):
        vk = win32api.VkKeyScan("f") & 0xff
        win32api.keybd_event(vk, 0, 0, 0)
        time.sleep(0.05)
        win32api.keybd_event(vk, 0, win32con.KEYEVENTF_KEYUP, 0)
        time.sleep(0.5)


def main():
    print("=" * 60)
    print("GODOT GAME AUTO TEST - Full Verification")
    print("=" * 60)

    # Step 1: Close existing Godot
    close_godot()
    time.sleep(1)

    # Step 2: Start game
    print("\n[1] Starting Godot game...")
    subprocess.Popen(
        [GODOT_EXE, "--path", PROJECT_PATH],
        cwd=PROJECT_PATH,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # Step 3: Find game window
    print("[2] Finding game window...")
    hwnd = None
    for attempt in range(20):
        wins = find_game_window()
        for h, t, c in wins:
            if "Engine" in c:
                hwnd = h
                print(f"  Found: '{t}' class='{c}' hwnd={hwnd}")
                break
        if hwnd:
            break
        time.sleep(0.8)
        print(f"  Retry {attempt+1}/20...")

    if not hwnd:
        print("[FAIL] Game window not found")
        return

    # Wait for game to fully load
    time.sleep(3)
    focus_window(hwnd)

    # Step 4: Initial screenshot
    print("\n[3] Snap initial (game loaded)...")
    img = snap_game_window(hwnd, "10_initial")
    interesting, cats = analyze_screenshot(img, "initial")

    # Step 5: WASD movement
    print("\n[4] Simulating WASD movement...")
    simulate_movement()
    img = snap_game_window(hwnd, "11_after_move")
    analyze_screenshot(img, "after_move")

    # Step 6: Attack
    print("\n[5] Simulating left-click attack...")
    simulate_attack(hwnd)
    img = snap_game_window(hwnd, "12_after_attack")
    interesting2, cats2 = analyze_screenshot(img, "after_attack")

    # Step 7: Interact
    print("\n[6] Simulating F-key interact...")
    simulate_interact()
    img = snap_game_window(hwnd, "13_after_interact")
    analyze_screenshot(img, "after_interact")

    # Step 8: Final report
    print("\n" + "=" * 60)
    print("TEST REPORT")
    print("=" * 60)

    screenshots = sorted(os.listdir(OUT_DIR))
    print(f"Screenshots ({len(screenshots)} files):")
    for f in screenshots[-8:]:
        fp = os.path.join(OUT_DIR, f)
        print(f"  {f}  {os.path.getsize(fp):,} bytes")

    print()
    print("Verification Results:")
    checks = []

    # Check player (blue pixels)
    player_pixels = len(cats.get("blue (player)", [])) + len(cats2.get("blue (player)", []))
    checks.append(("Player sprite (blue)", player_pixels > 0))

    # Check enemy boxes (brown)
    brown = len(cats.get("brown_wood (enemy box)", [])) + len(cats2.get("brown_wood (enemy box)", []))
    checks.append(("Enemy loot box (brown)", brown > 0))

    # Check map boxes (green)
    green = len(cats.get("green_metal (map box)", [])) + len(cats2.get("green_metal (map box)", []))
    checks.append(("Map loot box (green)", green > 0))

    # Check game content (non-background)
    checks.append(("Game renders content", len(interesting) > 100))

    for name, passed in checks:
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")

    all_passed = all(p for _, p in checks)
    print()
    print(f"Overall: {'ALL CHECKS PASSED' if all_passed else 'SOME CHECKS FAILED'}")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
