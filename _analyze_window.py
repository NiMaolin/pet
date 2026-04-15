"""分析游戏窗口截图内容"""
import win32gui, win32con, mss, os
from PIL import Image

OUT_DIR = r"d:\youxi\soudache\_test_screenshots"
os.makedirs(OUT_DIR, exist_ok=True)

def find_godot_window():
    result = []
    def cb(h, _):
        if win32gui.IsWindowVisible(h):
            t = win32gui.GetWindowText(h)
            if t and ("Pet" in t or "Godot" in t):
                result.append((h, t))
    win32gui.EnumWindows(cb, None)
    return result

def snap_window(hwnd, name):
    try:
        win32gui.SetForegroundWindow(hwnd)
    except:
        pass
    import time; time.sleep(0.5)

    rect = win32gui.GetWindowRect(hwnd)
    x, y = rect[0], rect[1]
    w, h = rect[2]-rect[0], rect[3]-rect[1]
    print(f"  Window rect: {rect}  size={w}x{h}")

    with mss.mss() as sct:
        img = sct.grab((x, y, rect[2], rect[3]))
        p = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")

    # 去除标题栏
    title_h = 32
    if h > 60:
        p = p.crop((0, title_h, w, h))

    path = os.path.join(OUT_DIR, name + ".png")
    p.save(path)
    print(f"  Saved: {p.size[0]}x{p.size[1]} -> {path}")
    return p, rect

def analyze_game_content(img, name):
    w, h = img.size
    px = img.load()

    checks = {
        "center":      (0.3, 0.3, 0.7, 0.7),
        "left_area":   (0.1, 0.3, 0.3, 0.7),
        "right_area":  (0.7, 0.3, 0.9, 0.7),
        "bottom":      (0.2, 0.7, 0.8, 0.95),
        "hud":         (0.0, 0.0, 0.2, 0.12),
    }

    print(f"\n  Analyzing {name} ({w}x{h}):")
    results = {}
    for region_name, (rx1, ry1, rx2, ry2) in checks.items():
        x1 = int(rx1*w); y1 = int(ry1*h); x2 = int(rx2*w); y2 = int(ry2*h)
        step_x = max(1, (x2-x1)//8)
        step_y = max(1, (y2-y1)//8)
        samples = [px[sx, sy] for sx in range(x1, x2, step_x) for sy in range(y1, y2, step_y)]
        if samples:
            avg = tuple(sum(c[i] for c in samples)//len(samples) for i in range(3))
            brightness = sum(avg) / 3
            variance = max(abs(avg[0]-avg[1]), abs(avg[1]-avg[2]), abs(avg[0]-avg[2]))
            has_content = brightness > 15 and variance > 8
            results[region_name] = {"avg": avg, "brightness": brightness, "variance": variance}
            status = "[has content]" if has_content else "[neutral]"
            print(f"    {region_name:15s}: RGB{avg}  brightness={brightness:.0f}  variance={variance:.0f}  {status}")
    return results

print("Finding Godot window...")
windows = find_godot_window()
if windows:
    hwnd, title = windows[0]
    print(f"Found: {title} (hwnd={hwnd})")

    img, rect = snap_window(hwnd, "05_window_cropped")
    results = analyze_game_content(img, "game_window")

    # 判断是否有游戏内容
    dark_regions = sum(1 for r, d in results.items()
                       if d["brightness"] < 80 and d["variance"] > 10)
    print(f"\n  Dark/colorful regions detected: {dark_regions}")
    print(f"  Game renders content: {dark_regions > 0}")

    # 列出所有截图
    print(f"\n  All screenshots in {OUT_DIR}:")
    for f in sorted(os.listdir(OUT_DIR)):
        fpath = os.path.join(OUT_DIR, f)
        print(f"    {f}  {os.path.getsize(fpath):,} bytes")
else:
    print("No Godot window found - is the game running?")
