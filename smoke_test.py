# -*- coding: utf-8 -*-
"""Quick smoke test - launch without --grid-test, capture stdout"""
import subprocess, time, os, ctypes
from ctypes import wintypes
import win32gui

PROJECT_DIR = r"D:\youxi\soudache"
GODOT_EXE = r"C:\Tools\Godot_v4.6.1-stable_win64.exe"
WINDOW_TITLE = "Pet Extraction (DEBUG)"
SCREENSHOT_DIR = os.path.join(PROJECT_DIR, "_test_grid_screenshots_v3")
os.makedirs(SCREENSHOT_DIR, exist_ok=True)
user32 = ctypes.windll.user32

def kill_all():
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)
    def cb(hwnd, lp):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            if WINDOW_TITLE in buf.value:
                pid = wintypes.DWORD()
                user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                try:
                    h = win32api.OpenProcess(0x0001, False, pid.value)
                    win32api.TerminateProcess(h, 0)
                    win32api.CloseHandle(h)
                except: pass
        return True
    user32.EnumWindows(WNDENUMPROC(cb), 0); time.sleep(1.5)

kill_all(); time.sleep(1)

# Launch WITHOUT --grid-test, capture stderr/stdout  
cmd = [GODOT_EXE, "--path", PROJECT_DIR]
proc = subprocess.Popen(cmd, cwd=PROJECT_DIR,
                       creationflags=subprocess.CREATE_NEW_CONSOLE,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
print("PID:", proc.pid)

# Find window
hwnd = None
for i in range(200):
    result = ctypes.c_long()
    def cb(h, _):
        if user32.IsWindowVisible(h):
            b = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(h, b, 256)
            if WINDOW_TITLE in b.value: result.value = h; return False
        return True
    user32.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)(cb), 0)
    if result.value: hwnd = result.value; break
    time.sleep(0.1)

if not hwnd:
    print("FATAL: No window!")
else:
    print("Window:", hwnd)
    user32.SetForegroundWindow(hwnd)

# Wait for main menu -> prepare -> map select -> world (~12s)
time.sleep(14)

# Screenshot using PIL
try:
    from PIL import ImageGrab
    wrect = wintypes.RECT(); user32.GetWindowRect(hwnd, ctypes.byref(wrect))
    pt = wintypes.POINT(wrect.left, wrect.top); user32.ClientToScreen(hwnd, ctypes.byref(pt))
    tb = max(abs(wrect.top - pt.y), 30)
    img = ImageGrab.grab(bbox=(wrect.left, wrect.top+tb, wrect.right, wrect.bottom))
    path = os.path.join(SCREENSHOT_DIR, "smoke_test.png")
    img.save(path)
    print("Screenshot saved: %s (%dx%d)" % (path, img.size[0], img.size[1]))
except Exception as e:
    print("Screenshot error:", e)

# Check for errors in output
print("\n--- Checking for Godot errors ---")
try:
    outs, errs = proc.communicate(timeout=2)
    if outs: print("STDOUT:", outs[:2000].decode('utf-8', errors='replace'))
    if errs: print("STDERR:", errs[:2000].decode('utf-8', errors='replace'))
except: pass

print("\nDone - keeping process running for manual check")
try: proc.wait(timeout=600)
except: pass
