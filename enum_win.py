import win32gui, ctypes
from ctypes import wintypes
pid = 48080
result = []
def cb(h, _):
    p = wintypes.DWORD()
    ctypes.windll.user32.GetWindowThreadProcessId(h, ctypes.byref(p))
    t = win32gui.GetWindowText(h)
    vis = win32gui.IsWindowVisible(h)
    if p.value == pid:
        print("HWND=%d Visible=%d Title=[%s]" % (h, vis, t))
win32gui.EnumWindows(cb, None)
