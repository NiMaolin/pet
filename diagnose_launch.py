"""Diag: launch game, capture console output, screenshot each step"""
import subprocess, time, os, sys, ctypes
from ctypes import wintypes
import win32gui

GAME = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
PROJECT = r"D:\youxi\soudache"
LOG_FILE = r"D:\youxi\soudache\_diag_log.txt"
SS_DIR = r"D:\youxi\soudache\_diag_shots"
os.makedirs(SS_DIR, exist_ok=True)

def log(msg):
    # Filter non-ASCII for Windows console
    safe = msg.encode("ascii", "replace").decode("ascii")
    print(safe)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(msg + "\n")

# Clear log
open(LOG_FILE, "w", encoding="utf-8").close()

log("=== DIAG START %s ===" % time.strftime("%H:%M:%S"))

# Launch game with --auto-test
proc = subprocess.Popen(
    [GAME, "--path", PROJECT, "--auto-test"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding="utf-8",
    errors="replace",
    bufsize=1,
)

log("Game PID=%d" % proc.pid)

def find_window():
    """Find Godot window by title or class"""
    def cb(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd):
            return True
        # Try multiple name patterns
        title = win32gui.GetWindowText(hwnd)
        cls = win32gui.GetClassName(hwnd)
        if "Pet Extraction" in title or "DEBUG" in title:
            result.append(hwnd)
            return False  # stop on first match
        # Godot Forward+ window class
        if "Godot" in cls:
            result.append(hwnd)
        return True
    result = []
    win32gui.EnumWindows(cb, None)
    return result[0] if result else 0

def get_rect(hwnd):
    r = wintypes.RECT()
    ctypes.windll.user32.GetWindowRect(hwnd, ctypes.byref(r))
    return (r.left, r.top, r.right - r.left, max(r.bottom - r.top, 1))

def screenshot(hwnd, name):
    import win32ui, win32con
    left, top, right, bottom = get_rect(hwnd)
    w = max(right - left, 1)
    h = max(bottom - top, 1)
    
    hwnd_dc = win32gui.GetDC(hwnd)
    mfc_dc = win32ui.CreateDCFromHandle(hwnd_dc)
    save_dc = mfc_dc.CreateCompatibleDC()
    
    bitmap = win32ui.CreateBitmap()
    bitmap.CreateCompatibleBitmap(mfc_dc, w, h)
    save_dc.SelectObject(bitmap)
    result = save_dc.BitBlt((0, 0), (w, h), mfc_dc, (0, 0), win32con.SRCCOPY)
    
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
    
    log("Screenshot: %s (%dx%d)" % (name, w, h))
    return path

# Wait for window
hwnd = 0
for i in range(60):  # 30 seconds
    time.sleep(0.5)
    hwnd = find_window()
    if hwnd:
        log("Window found! hwnd=%d" % hwnd)
        break
    
    # Fallback: find by process ID
    import ctypes
    def cb_pid(h, _):
        r2 = wintypes.RECT()
        ctypes.windll.user32.GetWindowThreadProcessId(h, ctypes.byref(ctypes.c_ulong()))
        pid_val = ctypes.c_ulong()
        ctypes.windll.user32.GetWindowThreadProcessId(h, ctypes.byref(pid_val))
        if win32gui.IsWindowVisible(h) and pid_val.value == proc.pid:
            result.append(h)
            return False
        return True
    result = []
    if not hwnd:
        win32gui.EnumWindows(cb_pid, None)
        if result:
            hwnd = result[0]
            log("Window found by PID! hwnd=%d" % hwnd)
            break

if not hwnd:
    log("ERROR: No window found after 30s!")

# Capture screenshots at key intervals + read stdout
steps = [
    (3, "01_after_3s"),
    (6, "02_after_6s"),
    (10, "03_after_10s"),
    (15, "04_after_15s"),
    (20, "05_after_20s"),
    (25, "06_after_25s"),
]

last_wait = 0
for wait_sec, name in steps:
    delta = wait_sec - last_wait
    time.sleep(delta)
    last_wait = wait_sec
    if hwnd:
        try:
            # Re-find window in case scene change rebuilt it
            if not win32gui.IsWindow(hwnd):
                hwnd = find_window()
            screenshot(hwnd, name)
        except Exception as e:
            log("Screenshot error: %s" % e)

# Read all stdout
log("\n=== READING STDOUT ===")
stdout_lines = []
start_time = time.time()

while time.time() - start_time < 5:
    line = proc.stdout.readline()
    if line:
        stdout_lines.append(line.strip())
    elif proc.poll() is not None:
        break
    else:
        time.sleep(0.1)

if not stdout_lines:
    log("(No stdout captured via readline)")

for line in stdout_lines[-80:]:
    log("STDOUT: %s" % line)

# Final screenshot
if hwnd:
    try:
        screenshot(hwnd, "09_final")
    except:
        pass

log("\n=== DIAG END ===")
log("Process alive? %s" % ("yes" if proc.poll() is None else "no (rc=%d)" % proc.returncode))

print("\nDone. Log saved to", LOG_FILE)
