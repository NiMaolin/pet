# -*- coding: utf-8 -*-
"""
格子系统 v2 重构 - 完整测试启动脚本
通过 --grid-test 参数驱动 AutoRunner 执行完整测试流程
"""
import subprocess, time, os, sys, ctypes
from ctypes import wintypes
import win32gui

PROJECT_DIR = r"D:\youxi\soudache"
GODOT_EXE = r"C:\Tools\Godot_v4.6.1-stable_win64.exe"
WINDOW_TITLE = "Pet Extraction (DEBUG)"
SCREENSHOT_DIR = os.path.join(PROJECT_DIR, "_test_grid_screenshots")
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

WM_LBUTTONDOWN = 0x0201
WM_LBUTTONUP = 0x0202
WM_LBUTTONDBLCLK = 0x0203
MK_LBUTTON = 0x0001

class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]

def log(msg):
    ts = time.strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    with open(os.path.join(SCREENSHOT_DIR, "grid_test_log.txt"), "a", encoding="utf-8") as f:
        f.write(line + "\n")

def kill_godot():
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)
    def cb(hwnd, lp):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            if WINDOW_TITLE in buf.value:
                user32.PostMessageW(hwnd, 0x0012, 0, 0) # WM_CLOSE
        return True
    user32.EnumWindows(WNDENUMPROC(cb), 0)
    time.sleep(1)

def find_window(timeout=20):
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)
    for i in range(timeout * 10):
        result = ctypes.c_long()
        def cb(hwnd, _):
            if user32.IsWindowVisible(hwnd):
                buf = ctypes.create_unicode_buffer(256)
                user32.GetWindowTextW(hwnd, buf, 256)
                if WINDOW_TITLE in buf.value:
                    result.value = hwnd
                    return False
            return True
        user32.EnumWindows(WNDENUMPROC(cb), 0)
        if result.value:
            return result.value
        time.sleep(0.1)
    return None

def get_rect(hwnd):
    rect = wintypes.RECT()
    if not user32.GetClientRect(hwnd, ctypes.byref(rect)):
        wrect = wintypes.RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(wrect))
        pt = wintypes.POINT(wrect.left, wrect.top)
        user32.ClientToScreen(hwnd, ctypes.byref(pt))
        title_bar = max(abs(wrect.top - pt.y), 32)
        return (wrect.left, wrect.top + title_bar, wrect.right, wrect.bottom)
    return (rect.left, rect.top, rect.right, rect.bottom)

def screenshot(hwnd, name):
    import win32ui, win32con
    left, top, right, bottom = get_rect(hwnd)
    w = max(right - left, 1)
    h = max(bottom - top, 1)
    
    # Use Windows API to capture
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
    img = Image.frombuffer(
        'RGB', (bmpinfo['bmWidth'], bmpinfo['bmHeight']),
        bmpstr, 'raw', 'BGRX', 0, 1)
    
    path = os.path.join(SCREENSHOT_DIR, name)
    img.save(path)
    
    # Cleanup
    win32gui.DeleteObject(bitmap.GetHandle())
    save_dc.DeleteDC()
    mfc_dc.DeleteDC()
    win32gui.ReleaseDC(hwnd, hwnd_dc)
    
    log(f"Screenshot: {name} ({w}x{h})")
    return path

def main():
    log("="*60)
    log("Grid System v2 Test Start")
    log("="*60)
    
    kill_godot()
    time.sleep(1)
    
    cmd = [GODOT_EXE, "--path", PROJECT_DIR, "--grid-test"]
    env = dict(os.environ)
    proc = subprocess.Popen(cmd, cwd=PROJECT_DIR, env=env,
                           creationflags=subprocess.CREATE_NEW_CONSOLE)
    log(f"Godot started PID={proc.pid} with --grid-test")
    
    hwnd = find_window()
    if not hwnd:
        log("FATAL: Window not found!")
        proc.terminate()
        return
    log(f"Window found: {hwnd}")
    
    # 等待基础流程完成（主菜单→准备→出发→副本）约10秒
    time.sleep(12)
    screenshot(hwnd, "01_after_enter_world.png")
    log("Step: Entered game world")
    
    # 等待物资箱打开+搜索完成 约18秒
    time.sleep(15)
    screenshot(hwnd, "02_loot_box_opened.png")
    log("Step: Loot box opened & searching")
    
    # 等待双击拾取+关闭重开 约8秒  
    time.sleep(8)
    screenshot(hwnd, "03_after_reopen.png")
    log("Step: After close & reopen")
    
    # 等待最终验证结果 约12秒
    time.sleep(12)
    screenshot(hwnd, "04_final_result.png")
    log("Step: Final verification complete")
    
    log("")
    log("="*60)
    log("TEST COMPLETE - Check screenshots and verify:")
    log(f"  Screenshots saved to: {SCREENSHOT_DIR}")
    log("  1. Screenshot 02: Should show loot box with items")
    log("  2. Screenshot 04: Should show '完成' not '搜索中...'")
    log("  3. Items should be visible with names and rarity borders")
    log("  4. Bag should have at least 1 picked item")
    log("="*60)
    
    try:
        proc.wait(timeout=600)
    except subprocess.TimeoutExpired:
        pass
    log("Game process ended")

if __name__ == "__main__":
    main()
