"""Quick test: just launch game and find window"""
import subprocess, time, os, sys, ctypes
from ctypes import wintypes
import win32gui

GAME = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
PROJECT = r"D:\youxi\soudache"
SS_DIR = r"D:\youxi\soudache\_quick_shots"
os.makedirs(SS_DIR, exist_ok=True)

# Launch WITHOUT --auto-test, just normal game
proc = subprocess.Popen(
    [GAME, "--path", PROJECT],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding="utf-8",
    errors="replace",
)

print("Game PID=%d" % proc.pid)
print("Waiting for window...")

def find_window():
    def cb(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd):
            return True
        title = win32gui.GetWindowText(hwnd)
        if title:
            result.append((hwnd, title))
        return True
    result = []
    win32gui.EnumWindows(cb, None)
    return result

# Poll for window up to 20s
hwnd = 0
for i in range(40):
    time.sleep(0.5)
    windows = find_window()
    for hw, title in windows:
        if "Pet Extraction" in title or "godot" in title.lower():
            hwnd = hw
            print("Found! hwnd=%d title=[%s]" % (hw, title))
            break
    if hwnd:
        break

if not hwnd:
    print("No Godot window found. All visible windows:")
    for hw, title in find_window()[:10]:
        print("  %d: [%s]" % (hw, title))
    
    # Check if process still alive
    rc = proc.poll()
    print("Process status: %s" % ("alive" if rc is None else "exit code=%d" % rc))
    if rc is None:
        # Read any error output
        import select
        pass

def screenshot(hwnd, name):
    import win32ui, win32con
    left, top, right, bottom = wintypes.RECT(), wintypes.RECT(), wintypes.RECT(), wintypes.RECT()
    # Use GetWindowRect via ctypes
    rect = wintypes.RECT()
    ctypes.windll.user32.GetWindowRect(hwnd, ctypes.byref(rect))
    w = max(rect.right - rect.left, 1)
    h = max(rect.bottom - rect.top, 1)
    
    hwnd_dc = win32gui.GetDC(hwnd)
    mfc_dc = win32ui.CreateDCFromHandle(hwnd_dc)
    save_dc = mfc_dc.CreateCompatibleDC()
    bitmap = win32ui.CreateBitmap()
    bitmap.CreateCompatibleBitmap(mfc_dc, w, h)
    save_dc.SelectObject(bitmap)
    save_dc.BitBlt((0, 0), (w, h), mfc_dc, (0, 0), win32con.SRCCOPY)
    
    bmpinfo = bitmap.GetInfo()
    bmpstr = bitmap.GetBitmapBits(True)
    from PIL import Image
    img = Image.frombuffer('RGB', (bmpinfo['bmWidth'], bmpinfo['bmHeight']), bmpstr, 'raw', 'BGRX', 0, 1)
    
    path = os.path.join(SS_DIR, name + ".png")
    img.save(path)
    
    win32gui.DeleteObject(bitmap.GetHandle())
    save_dc.DeleteDC()
    mfc_dc.DeleteDC()
    win32gui.ReleaseDC(hwnd, hwnd_dc)
    
    print("Screenshot: %s (%dx%d)" % (name, w, h))

if hwnd:
    time.sleep(2)  # Let it render
    screenshot(hwnd, "01_initial")
    
    # Wait more and take another
    time.sleep(5)
    if win32gui.IsWindow(hwnd):
        screenshot(hwnd, "02_after_5s")
    else:
        print("Window closed!")
else:
    print("FAILED: Cannot proceed without window")

print("\nDone. Game still running? %s" % (proc.poll() is None))
