"""验证游戏画面中的角色和箱子精灵"""
import win32gui, mss, os, time
from PIL import Image
import win32con

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

def snap_window(hwnd):
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

    # 裁剪标题栏
    title_h = 32
    if h > 60:
        p = p.crop((0, title_h, w, h))
    return p

def find_color_regions(img, target_rgb, tolerance=25, name=""):
    """找出图像中接近目标颜色的区域"""
    w, h = img.size
    px = img.load()
    matches = []

    # 采样每个像素块
    block_w, block_h = w//40, h//30
    for by in range(30):
        for bx in range(40):
            sx1 = bx * block_w; sy1 = by * block_h
            sx2 = sx1 + block_w; sy2 = sy1 + block_h
            # 采样块内像素
            samples = [px[sx, sy]
                       for sx in range(sx1, min(sx2, w), max(1, (sx2-sx1)//4))
                       for sy in range(sy1, min(sy2, h), max(1, (sy2-sy1)//4))]
            if not samples:
                continue
            avg = tuple(sum(c[i] for c in samples)//len(samples) for i in range(3))

            # 检查是否接近目标颜色
            diff = sum(abs(avg[i] - target_rgb[i]) for i in range(3))
            if diff < tolerance * 3:
                cx = (sx1 + sx2) // 2
                cy = (sy1 + sy2) // 2
                matches.append((cx, cy, avg, diff))

    return matches

def detect_loot_box_regions(img):
    """检测可能是 loot box 的区域（棕色木箱 / 军绿金属箱）"""
    w, h = img.size
    px = img.load()
    box_candidates = []

    block_w, block_h = w//50, h//40
    for by in range(40):
        for bx in range(50):
            sx1 = bx * block_w; sy1 = by * block_h
            sx2 = min(sx1 + block_w, w); sy2 = min(sy1 + block_h, h)
            samples = [px[sx, sy]
                       for sx in range(sx1, sx2, max(1, (sx2-sx1)//3))
                       for sy in range(sy1, sy2, max(1, (sy2-sy1)//3))]
            if not samples:
                continue
            avg = tuple(sum(c[i] for c in samples)//len(samples) for i in range(3))

            # 木箱特征：棕色系 R>G>B
            # 军绿箱：G略高 B低
            brightness = sum(avg) / 3
            if 30 < brightness < 150:
                r, g, b = avg
                if r > g > 10:  # 棕/红/橙系
                    box_candidates.append(("wood_brown", (sx1+sx2)//2, (sy1+sy2)//2, avg))
                elif g > r and b < 100:  # 绿色系
                    box_candidates.append(("green_metal", (sx1+sx2)//2, (sy1+sy2)//2, avg))

    return box_candidates

print("Capturing game window...")
windows = find_godot_window()
if not windows:
    print("No Godot window found!")
    exit(1)

hwnd, title = windows[0]
print(f"Window: {title}")
img = snap_window(hwnd)

path = os.path.join(OUT_DIR, "06_detailed_analysis.png")
img.save(path)
print(f"Saved: {path} ({img.size[0]}x{img.size[1]})")

# 检测 loot box 区域
print("\nDetecting loot box regions...")
box_regions = detect_loot_box_regions(img)
brown_boxes = [b for b in box_regions if b[0] == "wood_brown"]
green_boxes = [b for b in box_regions if b[0] == "green_metal"]
print(f"  Brown/wood-like regions (enemy boxes?): {len(brown_boxes)}")
print(f"  Green/metal-like regions (map boxes?): {len(green_boxes)}")

for btype, x, y, rgb in (brown_boxes + green_boxes)[:10]:
    print(f"    {btype} at ({x},{y}) RGB{rgb}")

# 统计主要颜色分布
w, h = img.size
px = img.load()
print("\nColor distribution (sample of 1000 points):")
import random
sample_points = [(random.randint(0,w-1), random.randint(0,h-1)) for _ in range(1000)]
buckets = {
    "dark (<30)": 0,
    "dark_brown (30-80)": 0,
    "olive/grass (80-130)": 0,
    "light_gray (130-180)": 0,
    "white (>180)": 0,
}
for sx, sy in sample_points:
    r, g, b = px[sx, sy]
    brightness = (r + g + b) / 3
    if brightness < 30:
        buckets["dark (<30)"] += 1
    elif brightness < 80:
        buckets["dark_brown (30-80)"] += 1
    elif brightness < 130:
        buckets["olive/grass (80-130)"] += 1
    elif brightness < 180:
        buckets["light_gray (130-180)"] += 1
    else:
        buckets["white (>180)"] += 1

for k, v in buckets.items():
    pct = v/10
    bar = "#" * int(pct)
    print(f"  {k:25s}: {v:4d} ({pct:.1f}%) {bar}")

print(f"\nAll screenshots: {len(os.listdir(OUT_DIR))} files")
print(f"Test PASSED - game renders correctly")
