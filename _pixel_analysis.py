"""深度像素分析 - 找箱子精灵"""
import subprocess, time, win32gui, win32con, win32api, mss, os
from PIL import Image

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT_PATH = r"D:\youxi\soudache"
OUT_DIR = r"d:\youxi\soudache\_test_screenshots"
os.makedirs(OUT_DIR, exist_ok=True)

def close_godot():
    subprocess.run(["taskkill","/F","/IM","Godot_v4.6.1-stable_win64_console.exe"], capture_output=True)
    subprocess.run(["taskkill","/F","/IM","Godot_v4.6.1-stable_win64.exe"], capture_output=True)
    print("[OK] Godot closed")

def find_window():
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
    time.sleep(0.5)
    rect = win32gui.GetWindowRect(hwnd)
    x, y = rect[0], rect[1]
    w, h = rect[2]-rect[0], rect[3]-rect[1]
    with mss.mss() as sct:
        img = sct.grab((x, y, rect[2], rect[3]))
        p = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")
    if h > 60:
        p = p.crop((0, 32, w, h))
    path = os.path.join(OUT_DIR, name + ".png")
    p.save(path)
    print(f"  [{name}] {p.size[0]}x{p.size[1]} saved")
    return p

print("=" * 50)
print("Deep Pixel Analysis - Finding Loot Boxes")
print("=" * 50)

close_godot()
time.sleep(1)

print("[1] Starting game...")
subprocess.Popen(
    [GODOT_EXE, "--path", PROJECT_PATH],
    cwd=PROJECT_PATH,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL
)

time.sleep(4)

print("[2] Finding window...")
hwnd = None
for _ in range(12):
    wins = find_window()
    if wins:
        hwnd = wins[0][0]
        break
    time.sleep(1)

if not hwnd:
    print("[FAIL] No window found")
    exit(1)
print(f"  hwnd={hwnd}")

print("[3] Snap initial game world...")
img = snap_window(hwnd, "09_deep_analysis")
w, h = img.size
px = img.load()
print(f"  Image: {w}x{h}")

# 基准背景色（从角落采样）
bg_samples = [px[5, 5], px[w-5, 5], px[5, h-5], px[w-5, h-5],
              px[w//2, 5], px[w//2, h-5]]
bg_r = sum(s[0] for s in bg_samples) // len(bg_samples)
bg_g = sum(s[1] for s in bg_samples) // len(bg_samples)
bg_b = sum(s[2] for s in bg_samples) // len(bg_samples)
print(f"  Background color: RGB({bg_r},{bg_g},{bg_b})")

# 找出所有与背景明显不同的区域
print("\n[4] Scanning for non-background pixels...")
interesting = []
step = max(1, min(w, h) // 100)  # 采样步长
for sy in range(0, h, step):
    for sx in range(0, w, step):
        r, g, b = px[sx, sy]
        diff = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
        brightness = (r + g + b) / 3
        if diff > 20 and brightness > 8:
            interesting.append((sx, sy, r, g, b, diff, brightness))

interesting.sort(key=lambda x: x[5], reverse=True)
print(f"  Found {len(interesting)} distinct pixels from background")
print(f"  Top 30 (most distinct from background):")
for item in interesting[:30]:
    sx, sy, r, g, b, diff, brightness = item
    tag = ""
    # 识别颜色类型
    if r > g > b and brightness < 150:
        tag = " <- BROWN/WOOD"
    elif g > r and g > b and brightness < 130:
        tag = " <- GREEN/METAL"
    elif r > 100 and g < 60 and b < 60:
        tag = " <- RED"
    elif brightness < 50:
        tag = " <- DARK"
    print(f"    ({sx:4d},{sy:4d}) RGB({r:3d},{g:3d},{b:3d}) brightness={brightness:.0f} diff={diff:.0f}{tag}")

# 分析色系分布
print("\n[5] Color distribution:")
color_buckets = {
    "dark (<20)": 0,
    "dark_brown (20-60)": 0,
    "brown (60-120)": 0,
    "olive (120-180)": 0,
    "light (>180)": 0,
}
for item in interesting:
    br = item[6]
    if br < 20:
        color_buckets["dark (<20)"] += 1
    elif br < 60:
        color_buckets["dark_brown (20-60)"] += 1
    elif br < 120:
        color_buckets["brown (60-120)"] += 1
    elif br < 180:
        color_buckets["olive (120-180)"] += 1
    else:
        color_buckets["light (>180)"] += 1

for k, v in color_buckets.items():
    pct = v / max(1, len(interesting)) * 100
    bar = "#" * int(pct / 2)
    print(f"  {k:25s}: {v:4d} ({pct:.1f}%) {bar}")

print("\n[6] Screenshot files:")
for f in sorted(os.listdir(OUT_DIR))[-8:]:
    fp = os.path.join(OUT_DIR, f)
    print(f"  {f}  {os.path.getsize(fp):,} bytes")

print("=" * 50)
# 判断
brown_wood = sum(1 for i in interesting if i[2] > i[3] > 10 and i[6] < 150)
green_metal = sum(1 for i in interesting if i[3] > i[2] and i[3] > i[4] and i[6] < 130)
print(f"Brown/wood pixels: {brown_wood}")
print(f"Green/metal pixels: {green_metal}")
if brown_wood > 5:
    print("[PASS] Wood-colored loot boxes likely present in game")
if green_metal > 5:
    print("[PASS] Green-colored loot boxes likely present in game")
print("=" * 50)
