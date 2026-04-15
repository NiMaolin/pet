"""启动并测试游戏"""
import subprocess
import time
import win32gui
import mss
from PIL import Image

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT = r"D:\youxi\soudache"
SHOT_DIR = r"D:\youxi\soudache\_test_screenshots"

# Kill existing Godot
for name in ["Godot_v4.6.1-stable_win64_console.exe", "Godot_v4.6.1-stable_win64.exe"]:
    subprocess.run(["taskkill", "/F", "/IM", name], capture_output=True, timeout=5)
time.sleep(1)

# Start
print("Starting game...")
subprocess.Popen(
    [GODOT_EXE, "--path", PROJECT],
    cwd=PROJECT,
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
)
time.sleep(6)

# Find window
def find_window():
    result = []
    def cb(h, _):
        if win32gui.IsWindowVisible(h):
            t = win32gui.GetWindowText(h)
            if t and "Pet" in t:
                result.append((h, t))
    win32gui.EnumWindows(cb, None)
    return result

wins = find_window()
print("Windows:", wins)
if not wins:
    print("ERROR: No game window found")
    exit(1)

hwnd, title = wins[0]
try:
    win32gui.SetForegroundWindow(hwnd)
except:
    pass
time.sleep(0.5)

# Screenshot
rect = win32gui.GetWindowRect(hwnd)
with mss.mss() as sct:
    img = sct.grab((rect[0], rect[1], rect[2], rect[3]))
    p = Image.frombytes("RGB", img.size, img.bgra, "raw", "BGRX")

path = SHOT_DIR + "/17_verify_ui.png"
p.save(path)
print("Screenshot:", path)

# Quick pixel analysis
px = p.load()
w, h = p.size
bg = px[5, 5]
bg_r, bg_g, bg_b = bg[:3]

distinct = []
step = 4
for sy in range(0, h, step):
    for sx in range(0, w, step):
        r, g, b = px[sx, sy][:3]
        diff = abs(r-bg_r) + abs(g-bg_g) + abs(b-bg_b)
        brightness = (r+g+b)/3
        if diff > 25 and brightness > 5:
            distinct.append((sx, sy, r, g, b, diff, brightness))
distinct.sort(key=lambda x: x[5], reverse=True)

print("Top colors:")
for item in distinct[:10]:
    sx, sy, r, g, b, diff, brightness = item
    tag = ""
    if r > g and brightness < 160: tag = " <- BROWN"
    elif g > r and brightness < 140: tag = " <- GREEN"
    elif brightness > 160: tag = " <- WHITE"
    elif brightness < 50: tag = " <- DARK"
    print("  (%4d,%4d) RGB(%3d,%3d,%3d) brightness=%5.1f%s" % (sx, sy, r, g, b, brightness, tag))

# Count categories
brown = sum(1 for i in distinct if i[6] < 160 and i[2] > i[3] and i[2]-i[3] > 10)
green = sum(1 for i in distinct if i[6] < 140 and i[3] > i[2] and i[3]-i[2] > 10)
white = sum(1 for i in distinct if i[6] > 160)
dark = sum(1 for i in distinct if i[6] < 50)

print("\nSummary: Brown=%d Green=%d White=%d Dark=%d" % (brown, green, white, dark))
if brown > 50:
    print("[OK] Brown pixels detected -> sprite rendering")
if dark > 200:
    print("[OK] Dark pixels detected -> loot UI panel visible")
print("\nGame started successfully. Screenshot saved to:", path)
