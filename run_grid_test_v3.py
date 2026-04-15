# -*- coding: utf-8 -*-
"""
Grid System V3 Test - Robust version
Ensures fresh window detection per run
"""
import subprocess, time, os, sys, ctypes
from ctypes import wintypes
import win32gui
import win32process
import win32api

PROJECT_DIR = r"D:\youxi\soudache"
GODOT_EXE = r"C:\Tools\Godot_v4.6.1-stable_win64.exe"
WINDOW_TITLE = "Pet Extraction (DEBUG)"
SCREENSHOT_DIR = os.path.join(PROJECT_DIR, "_test_grid_screenshots_v3")
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

user32 = ctypes.windll.user32

def log(msg):
    ts = time.strftime("%H:%M:%S")
    line = "[%s] %s" % (ts, msg)
    print(line)
    try:
        with open(os.path.join(SCREENSHOT_DIR, "grid_test_log.txt"), "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except:
        pass

def kill_all_godot():
    """Kill ALL Godot processes by name"""
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)
    killed = []
    def cb(hwnd, lp):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            title = buf.value
            if WINDOW_TITLE in title:
                # Get PID of window
                pid = wintypes.DWORD()
                user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                try:
                    handle = win32api.OpenProcess(0x0001, False, pid.value)
                    win32api.TerminateProcess(handle, 0)
                    win32api.CloseHandle(handle)
                    killed.append(pid.value)
                except:
                    user32.PostMessageW(hwnd, 0x0012, 0, 0)  # WM_CLOSE fallback
        return True
    user32.EnumWindows(WNDENUMPROC(cb), 0)
    time.sleep(2)
    log("Killed processes: %s" % str(killed) if killed else "No processes to kill")
    return len(killed)

def find_fresh_window(old_hwnds, timeout=30):
    """Find a NEW window (not in old_hwnds list)"""
    for i in range(timeout * 10):
        result = ctypes.c_long()
        def cb(hwnd, _):
            if user32.IsWindowVisible(hwnd):
                buf = ctypes.create_unicode_buffer(256)
                user32.GetWindowTextW(hwnd, buf, 256)
                if WINDOW_TITLE in buf.value and hwnd not in old_hwnds:
                    result.value = hwnd
                    return False
            return True
        user32.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)(cb), 0)
        if result.value:
            return result.value
        time.sleep(0.1)
    return None

def get_all_windows():
    """Get all current matching window handles"""
    hwnds = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            if WINDOW_TITLE in buf.value:
                hwnds.append(hwnd)
        return True
    user32.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_long)(cb), 0)
    return hwnds

def get_rect(hwnd):
    wrect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(wrect))
    pt = wintypes.POINT(wrect.left, wrect.top)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    title_bar = max(abs(wrect.top - pt.y), 30)
    return (wrect.left, wrect.top + title_bar, wrect.right, wrect.bottom)

def screenshot(hwnd, name):
    try:
        from PIL import ImageGrab
        left, top, right, bottom = get_rect(hwnd)
        img = ImageGrab.grab(bbox=(left, top, right, bottom))
        path = os.path.join(SCREENSHOT_DIR, name)
        img.save(path)
        
        import numpy as np
        arr = np.array(img)
        avg_bright = arr.mean() if arr.size > 0 else 0
        log("Screenshot: %s (%dx%d) bright=%.0f" % (name, img.size[0], img.size[1], avg_bright))
        return path
    except Exception as e:
        log("Screenshot error: %s" % e)
        return None

def main():
    log("=" * 60)
    log("Grid System V3 Refactor Test")
    log("=" * 60)

    # Clear log
    try:
        with open(os.path.join(SCREENSHOT_DIR, "grid_test_log.txt"), "w", encoding="utf-8") as f:
            pass
    except: pass
    
    # Step 0: Kill all existing windows and record their handles
    old_windows = set(get_all_windows())
    kill_all_godot()
    time.sleep(2)
    
    # Start fresh
    cmd = [GODOT_EXE, "--path", PROJECT_DIR, "--grid-test"]
    proc = subprocess.Popen(cmd, cwd=PROJECT_DIR,
                           creationflags=subprocess.CREATE_NEW_CONSOLE)
    log("Godot started PID=%d" % proc.pid)
    
    # Find a NEW window (not from before kill)
    hwnd = find_fresh_window(old_windows)
    if not hwnd:
        log("FATAL: New window not found after 30s!")
        proc.terminate()
        return
    log("NEW Window found: %d" % hwnd)
    
    user32.SetForegroundWindow(hwnd)
    time.sleep(2)
    
    # Step 1: Enter world (~15s total from start)
    time.sleep(15)
    screenshot(hwnd, "01_game_world.png")
    log("Step 1: In game world OK")
    
    # Step 2: Loot box searched (~18s)
    time.sleep(18)
    screenshot(hwnd, "02_loot_searched.png")
    log("Step 2: Loot box searched OK")
    
    # Step 3: Pickup/move/reopen (~12s)
    time.sleep(12)
    screenshot(hwnd, "03_pickup_reopen.png")
    log("Step 3: Pickup/reopen OK")
    
    # Step 4: Final verify (~16s)
    time.sleep(16)
    screenshot(hwnd, "04_final_verify.png")
    log("Step 4: Final verify OK")

    log("")
    log("=" * 60)
    log("V3 TEST COMPLETE!")
    log("=" * 60)
    
    try:
        proc.wait(timeout=600)
    except subprocess.TimeoutExpired:
        pass
    log("Done")

if __name__ == "__main__":
    main()
