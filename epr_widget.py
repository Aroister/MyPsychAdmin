"""
epr_widget.py - SystmOne EPR Widget for MyPsychAdmin

Embeddable version of epr_app.py that emits captured notes via signals
instead of displaying them in a local table.

States: FIND_SEARCH -> FILL_SEARCH -> SELECT_PATIENT -> DISMISS_DIALOGS
        -> FIND_JOURNAL -> EXPORT_NOTES -> DONE
"""

import csv
import ctypes
import ctypes.wintypes as wt
import io
import os
import subprocess
import sys
import tempfile
import time
from threading import Event

from PySide6.QtCore import Qt, QThread, QTimer, Signal
from PySide6.QtGui import QColor, QCursor, QFont, QImage, QPainter, QPixmap
from PySide6.QtWidgets import (
    QApplication, QGridLayout, QHBoxLayout, QHeaderView, QLabel,
    QLineEdit, QMessageBox, QPushButton, QTableWidget,
    QTableWidgetItem, QTabWidget, QTextEdit, QVBoxLayout, QWidget,
)

# ==================================================================
#  Win32 API
# ==================================================================

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
kernel32 = ctypes.windll.kernel32

HWND = wt.HWND; LPARAM = wt.LPARAM; WPARAM = wt.WPARAM
DWORD = wt.DWORD; BOOL = wt.BOOL; RECT = wt.RECT
POINT = wt.POINT; LONG = wt.LONG; HMENU = wt.HMENU

BM_CLICK = 0x00F5; WM_SETTEXT = 0x000C; SW_RESTORE = 9; SW_MAXIMIZE = 3; SW_MINIMIZE = 6
SM_CXSCREEN = 0; SM_CYSCREEN = 1
INPUT_KEYBOARD = 1; INPUT_MOUSE = 0
MOUSEEVENTF_LEFTDOWN = 0x0002; MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008; MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_ABSOLUTE = 0x8000; MOUSEEVENTF_MOVE = 0x0001
KEYEVENTF_KEYUP = 0x0002; KEYEVENTF_UNICODE = 0x0004
VK_RETURN = 0x0D; VK_TAB = 0x09; VK_MENU = 0x12; VK_ESCAPE = 0x1B
VK_F = 0x46; VK_S = 0x53; VK_O = 0x4F; VK_A = 0x41; VK_C = 0x43; VK_Y = 0x59; VK_L = 0x4C
VK_DOWN = 0x28; VK_UP = 0x26; VK_RIGHT = 0x27; VK_LEFT = 0x25; VK_END = 0x23; VK_HOME = 0x24
SM_CXSCREEN = 0; SM_CYSCREEN = 1; GA_ROOT = 2
BI_RGB = 0; DIB_RGB_COLORS = 0; PW_RENDERFULLCONTENT = 2; SRCCOPY = 0x00CC0020
MN_GETHMENU = 0x01E1; MF_BYPOSITION = 0x0400
GWL_EXSTYLE = -20; WS_EX_TRANSPARENT = 0x00000020; WS_EX_LAYERED = 0x00080000

class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", LONG), ("dy", LONG), ("mouseData", DWORD),
                ("dwFlags", DWORD), ("time", DWORD),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]
class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD),
                ("dwFlags", DWORD), ("time", DWORD),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]
class INPUT(ctypes.Structure):
    class _INPUT(ctypes.Union):
        _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT)]
    _fields_ = [("type", DWORD), ("_input", _INPUT)]
class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", DWORD), ("biWidth", LONG), ("biHeight", LONG),
                ("biPlanes", wt.WORD), ("biBitCount", wt.WORD),
                ("biCompression", DWORD), ("biSizeImage", DWORD),
                ("biXPelsPerMeter", LONG), ("biYPelsPerMeter", LONG),
                ("biClrUsed", DWORD), ("biClrImportant", DWORD)]
class BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", DWORD * 3)]

EnumWindowsProc = ctypes.WINFUNCTYPE(BOOL, HWND, LPARAM)
EnumChildProc = ctypes.WINFUNCTYPE(BOOL, HWND, LPARAM)

user32.GetWindowTextW.argtypes = [HWND, wt.LPWSTR, ctypes.c_int]
user32.GetWindowTextW.restype = ctypes.c_int
user32.GetWindowTextLengthW.argtypes = [HWND]
user32.GetWindowTextLengthW.restype = ctypes.c_int
user32.EnumChildWindows.argtypes = [HWND, EnumChildProc, LPARAM]
user32.EnumChildWindows.restype = BOOL
user32.EnumWindows.argtypes = [EnumWindowsProc, LPARAM]
user32.EnumWindows.restype = BOOL
user32.GetClassNameW.argtypes = [HWND, wt.LPWSTR, ctypes.c_int]
user32.GetClassNameW.restype = ctypes.c_int
user32.SendMessageW.argtypes = [HWND, ctypes.c_uint, WPARAM, LPARAM]
user32.SendMessageW.restype = ctypes.c_long
user32.SetForegroundWindow.argtypes = [HWND]; user32.SetForegroundWindow.restype = BOOL
user32.ShowWindow.argtypes = [HWND, ctypes.c_int]; user32.ShowWindow.restype = BOOL
user32.IsWindowVisible.argtypes = [HWND]; user32.IsWindowVisible.restype = BOOL
user32.IsWindow.argtypes = [HWND]; user32.IsWindow.restype = BOOL
user32.GetWindowRect.argtypes = [HWND, ctypes.POINTER(RECT)]; user32.GetWindowRect.restype = BOOL
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]; user32.SetCursorPos.restype = BOOL
user32.GetCursorPos.argtypes = [ctypes.POINTER(POINT)]; user32.GetCursorPos.restype = BOOL
user32.SendInput.argtypes = [ctypes.c_uint, ctypes.POINTER(INPUT), ctypes.c_int]
user32.SendInput.restype = ctypes.c_uint
user32.GetSystemMetrics.argtypes = [ctypes.c_int]; user32.GetSystemMetrics.restype = ctypes.c_int
user32.WindowFromPoint.argtypes = [POINT]; user32.WindowFromPoint.restype = HWND
user32.GetAncestor.argtypes = [HWND, ctypes.c_uint]; user32.GetAncestor.restype = HWND
user32.GetForegroundWindow.argtypes = []; user32.GetForegroundWindow.restype = HWND
user32.GetWindowThreadProcessId.argtypes = [HWND, ctypes.POINTER(DWORD)]
user32.GetWindowThreadProcessId.restype = DWORD
user32.AttachThreadInput.argtypes = [DWORD, DWORD, BOOL]; user32.AttachThreadInput.restype = BOOL
user32.OpenClipboard.argtypes = [HWND]; user32.OpenClipboard.restype = BOOL
user32.CloseClipboard.argtypes = []; user32.CloseClipboard.restype = BOOL
user32.GetClipboardData.argtypes = [ctypes.c_uint]; user32.GetClipboardData.restype = ctypes.c_void_p
user32.GetDC.argtypes = [HWND]; user32.GetDC.restype = wt.HDC
user32.ReleaseDC.argtypes = [HWND, wt.HDC]; user32.ReleaseDC.restype = ctypes.c_int
user32.PrintWindow.argtypes = [HWND, wt.HDC, ctypes.c_uint]; user32.PrintWindow.restype = BOOL
gdi32.CreateCompatibleDC.argtypes = [wt.HDC]; gdi32.CreateCompatibleDC.restype = wt.HDC
gdi32.CreateCompatibleBitmap.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = wt.HBITMAP
gdi32.SelectObject.argtypes = [wt.HDC, wt.HGDIOBJ]; gdi32.SelectObject.restype = wt.HGDIOBJ
gdi32.GetDIBits.argtypes = [wt.HDC, wt.HBITMAP, ctypes.c_uint, ctypes.c_uint,
                             ctypes.c_void_p, ctypes.POINTER(BITMAPINFO), ctypes.c_uint]
gdi32.GetDIBits.restype = ctypes.c_int
gdi32.DeleteObject.argtypes = [wt.HGDIOBJ]; gdi32.DeleteObject.restype = BOOL
gdi32.DeleteDC.argtypes = [wt.HDC]; gdi32.DeleteDC.restype = BOOL
gdi32.BitBlt.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                          wt.HDC, ctypes.c_int, ctypes.c_int, DWORD]
gdi32.BitBlt.restype = BOOL
user32.GetMenuItemCount.argtypes = [HMENU]; user32.GetMenuItemCount.restype = ctypes.c_int
user32.GetMenuStringW.argtypes = [HMENU, ctypes.c_uint, wt.LPWSTR, ctypes.c_int, ctypes.c_uint]
user32.GetMenuStringW.restype = ctypes.c_int
user32.GetMenuItemRect.argtypes = [HWND, HMENU, ctypes.c_uint, ctypes.POINTER(RECT)]
user32.GetMenuItemRect.restype = BOOL
user32.GetWindowLongW.argtypes = [HWND, ctypes.c_int]; user32.GetWindowLongW.restype = ctypes.c_long
user32.SetWindowLongW.argtypes = [HWND, ctypes.c_int, ctypes.c_long]; user32.SetWindowLongW.restype = ctypes.c_long
user32.MoveWindow.argtypes = [HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, BOOL]
user32.MoveWindow.restype = BOOL
user32.SetParent.argtypes = [HWND, HWND]; user32.SetParent.restype = HWND
user32.SetFocus.argtypes = [HWND]; user32.SetFocus.restype = HWND
user32.GetClientRect.argtypes = [HWND, ctypes.POINTER(RECT)]; user32.GetClientRect.restype = BOOL
user32.SetWindowPos.argtypes = [HWND, HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_uint]
user32.SetWindowPos.restype = BOOL
user32.ClientToScreen.argtypes = [HWND, ctypes.POINTER(POINT)]; user32.ClientToScreen.restype = BOOL
kernel32.GetLastError.argtypes = []; kernel32.GetLastError.restype = DWORD
kernel32.SetLastError.argtypes = [DWORD]; kernel32.SetLastError.restype = None
GWL_STYLE = -16
WS_CHILD = 0x40000000
WS_VISIBLE = 0x10000000
WS_OVERLAPPEDWINDOW = 0x00CF0000

# --- Debug: integrity level helpers ---
_advapi32 = ctypes.windll.advapi32
_TOKEN_QUERY = 0x0008
_TokenIntegrityLevel = 25

def _get_process_integrity(pid=None):
    """Return integrity level string for a process (default: current process)."""
    try:
        import ctypes.wintypes as wt
        HANDLE = wt.HANDLE
        _k32 = ctypes.windll.kernel32
        if pid is None:
            hProc = _k32.GetCurrentProcess()
        else:
            PROCESS_QUERY_INFORMATION = 0x0400
            hProc = _k32.OpenProcess(PROCESS_QUERY_INFORMATION, False, pid)
            if not hProc:
                return f"OpenProcess failed (err={_k32.GetLastError()})"

        hToken = HANDLE()
        if not _advapi32.OpenProcessToken(hProc, _TOKEN_QUERY, ctypes.byref(hToken)):
            err = _k32.GetLastError()
            if pid is not None:
                _k32.CloseHandle(hProc)
            return f"OpenProcessToken failed (err={err})"

        # Get required buffer size
        needed = wt.DWORD()
        _advapi32.GetTokenInformation(hToken, _TokenIntegrityLevel, None, 0, ctypes.byref(needed))
        buf = ctypes.create_string_buffer(needed.value)
        if not _advapi32.GetTokenInformation(hToken, _TokenIntegrityLevel, buf, needed.value, ctypes.byref(needed)):
            err = _k32.GetLastError()
            _k32.CloseHandle(hToken)
            if pid is not None:
                _k32.CloseHandle(hProc)
            return f"GetTokenInformation failed (err={err})"

        # Parse TOKEN_MANDATORY_LABEL — first pointer-sized bytes = SID pointer
        sid_ptr = ctypes.cast(buf, ctypes.POINTER(ctypes.c_void_p)).contents.value
        # GetSidSubAuthorityCount
        count_ptr = _advapi32.GetSidSubAuthorityCount(sid_ptr)
        count = ctypes.cast(count_ptr, ctypes.POINTER(ctypes.c_ubyte)).contents.value
        # GetSidSubAuthority for last sub-authority = integrity RID
        rid_ptr = _advapi32.GetSidSubAuthority(sid_ptr, count - 1)
        rid = ctypes.cast(rid_ptr, ctypes.POINTER(wt.DWORD)).contents.value

        _k32.CloseHandle(hToken)
        if pid is not None:
            _k32.CloseHandle(hProc)

        levels = {0x0000: "Untrusted", 0x1000: "Low", 0x2000: "Medium",
                  0x2100: "MediumPlus", 0x3000: "High", 0x4000: "System"}
        return levels.get(rid, f"Unknown(0x{rid:04X})")
    except Exception as e:
        return f"Error: {e}"

# ==================================================================
#  Win32 helpers
# ==================================================================

def gwt(hwnd):
    n = user32.GetWindowTextLengthW(hwnd)
    if not n: return ""
    b = ctypes.create_unicode_buffer(n + 1); user32.GetWindowTextW(hwnd, b, n + 1); return b.value

def gcn(hwnd):
    b = ctypes.create_unicode_buffer(256); user32.GetClassNameW(hwnd, b, 256); return b.value

def gwr(hwnd):
    r = RECT(); user32.GetWindowRect(hwnd, ctypes.byref(r))
    return r.left, r.top, r.right, r.bottom

def bring_front(hwnd):
    user32.ShowWindow(hwnd, SW_RESTORE)
    fg = user32.GetForegroundWindow()
    ft = user32.GetWindowThreadProcessId(fg, None); ot = kernel32.GetCurrentThreadId()
    if ft != ot: user32.AttachThreadInput(ot, ft, True)
    user32.SetForegroundWindow(hwnd)
    if ft != ot: user32.AttachThreadInput(ot, ft, False)

def find_children(parent, cls=None, txt=None):
    res = []
    def _cb(h, _):
        if cls and cls.lower() not in gcn(h).lower(): return True
        if txt and txt.lower() not in gwt(h).lower(): return True
        res.append(h); return True
    user32.EnumChildWindows(parent, EnumChildProc(_cb), 0); return res

def find_titled(partial, vis=True):
    res = []
    def _cb(h, _):
        if vis and not user32.IsWindowVisible(h): return True
        t = gwt(h)
        if partial.lower() in t.lower(): res.append((h, t))
        return True
    user32.EnumWindows(EnumWindowsProc(_cb), 0); return res

def popup_dialogs():
    res = []
    def _cb(h, _):
        if user32.IsWindowVisible(h) and gcn(h) == "#32770":
            res.append((h, gwt(h)))
        return True
    user32.EnumWindows(EnumWindowsProc(_cb), 0); return res

def click_btn(h): user32.SendMessageW(h, BM_CLICK, 0, 0)
def set_text(h, t): user32.SendMessageW(h, WM_SETTEXT, 0, ctypes.c_wchar_p(t))

def dismiss_ok(hwnd):
    for t in ("OK", "Yes", "Continue", "&OK", "&Yes"):
        bb = find_children(hwnd, cls="Button", txt=t)
        if bb: click_btn(bb[0]); return True
    return False

# -- Input ----------------------------------------------------------

def _ex(): return ctypes.pointer(ctypes.c_ulong(0))

def skey(vk, down=True):
    i = INPUT(); i.type = INPUT_KEYBOARD; i._input.ki.wVk = vk
    i._input.ki.dwFlags = 0 if down else KEYEVENTF_KEYUP; i._input.ki.dwExtraInfo = _ex()
    user32.SendInput(1, ctypes.byref(i), ctypes.sizeof(INPUT))

def pkey(vk): skey(vk, True); time.sleep(0.05); skey(vk, False)

def altkey(vk):
    skey(VK_MENU, True); time.sleep(0.04); skey(vk, True); time.sleep(0.04)
    skey(vk, False); time.sleep(0.04); skey(VK_MENU, False)

def typetxt(text):
    for ch in text:
        for down in (True, False):
            i = INPUT(); i.type = INPUT_KEYBOARD; i._input.ki.wVk = 0
            i._input.ki.wScan = ord(ch)
            i._input.ki.dwFlags = KEYEVENTF_UNICODE | (KEYEVENTF_KEYUP if not down else 0)
            i._input.ki.dwExtraInfo = _ex()
            user32.SendInput(1, ctypes.byref(i), ctypes.sizeof(INPUT)); time.sleep(0.01)
        time.sleep(0.02)

def mclick(x, y, btn="left"):
    user32.SetCursorPos(x, y); time.sleep(0.06)
    sx = int(x * 65535 / user32.GetSystemMetrics(SM_CXSCREEN))
    sy = int(y * 65535 / user32.GetSystemMetrics(SM_CYSCREEN))
    df, uf = (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP) if btn == "left" else (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP)
    for f in (df, uf):
        i = INPUT(); i.type = INPUT_MOUSE; i._input.mi.dx = sx; i._input.mi.dy = sy
        i._input.mi.dwFlags = f | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE
        i._input.mi.dwExtraInfo = _ex()
        user32.SendInput(1, ctypes.byref(i), ctypes.sizeof(INPUT)); time.sleep(0.05)

def mmove(x, y):
    """Move mouse via SendInput so menus detect the hover."""
    user32.SetCursorPos(x, y); time.sleep(0.05)
    sx = int(x * 65535 / user32.GetSystemMetrics(SM_CXSCREEN))
    sy = int(y * 65535 / user32.GetSystemMetrics(SM_CYSCREEN))
    i = INPUT(); i.type = INPUT_MOUSE; i._input.mi.dx = sx; i._input.mi.dy = sy
    i._input.mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE
    i._input.mi.dwExtraInfo = _ex()
    user32.SendInput(1, ctypes.byref(i), ctypes.sizeof(INPUT))

# ==================================================================
#  Full-screen capture (sees EVERYTHING: menus, dialogs, popups)
# ==================================================================

def capture_screen():
    """Capture entire primary monitor via BitBlt. Returns (QPixmap, png_path)."""
    w = user32.GetSystemMetrics(SM_CXSCREEN)
    h = user32.GetSystemMetrics(SM_CYSCREEN)
    if w <= 0 or h <= 0: return None, None
    hdc = user32.GetDC(0)  # 0 = entire screen
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    old = gdi32.SelectObject(mdc, bmp)
    gdi32.BitBlt(mdc, 0, 0, w, h, hdc, 0, 0, SRCCOPY)
    bi = BITMAPINFO(); bi.bmiHeader.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bi.bmiHeader.biWidth = w; bi.bmiHeader.biHeight = -h
    bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(bi), DIB_RGB_COLORS)
    gdi32.SelectObject(mdc, old); gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mdc); user32.ReleaseDC(0, hdc)
    img = QImage(buf, w, h, w * 4, QImage.Format.Format_RGB32).copy()
    pix = QPixmap.fromImage(img)
    if pix.isNull(): return None, None
    p = os.path.join(tempfile.gettempdir(), "epr_capture.png"); pix.save(p, "PNG")
    return pix, p

# ==================================================================
#  Window capture (works even when behind other windows)
# ==================================================================

def capture_window(hwnd):
    """Capture a specific window via PrintWindow (works even when behind other windows)."""
    l, t, r, b = gwr(hwnd)
    w = r - l; h = b - t
    if w <= 0 or h <= 0:
        return None, None, (0, 0)
    hdc = user32.GetDC(hwnd)
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    old = gdi32.SelectObject(mdc, bmp)
    user32.PrintWindow(hwnd, mdc, PW_RENDERFULLCONTENT)
    bi = BITMAPINFO(); bi.bmiHeader.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bi.bmiHeader.biWidth = w; bi.bmiHeader.biHeight = -h
    bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(bi), DIB_RGB_COLORS)
    gdi32.SelectObject(mdc, old); gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mdc); user32.ReleaseDC(hwnd, hdc)
    img = QImage(buf, w, h, w * 4, QImage.Format.Format_RGB32).copy()
    pix = QPixmap.fromImage(img)
    if pix.isNull():
        return None, None, (0, 0)
    p = os.path.join(tempfile.gettempdir(), "epr_capture.png"); pix.save(p, "PNG")
    return pix, p, (l, t)  # returns window offset for coordinate conversion

# ==================================================================
#  OCR
# ==================================================================

_OCR = r'''
$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.SoftwareBitmap,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]
    function Await($t, $r) {
        $m = $asTaskGeneric.MakeGenericMethod($r)
        $n = $m.Invoke($null, @($t)); $n.Wait(-1) | Out-Null; $n.Result
    }
    $ocr = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (-not $ocr) { Write-Error "No OCR"; exit 1 }
    $f = $env:EPR_OCR_IMAGE
    if (-not (Test-Path $f)) { Write-Error "No image"; exit 1 }
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($f)) ([Windows.Storage.StorageFile])
    $stm = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $dec = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stm)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bmp = Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $res = Await ($ocr.RecognizeAsync($bmp)) ([Windows.Media.Ocr.OcrResult])
    foreach ($line in $res.Lines) {
        $words = $line.Words
        if ($words.Count -gt 0) {
            $minX = [double]::MaxValue; $minY = [double]::MaxValue; $maxX = 0; $maxY = 0
            foreach ($w in $words) {
                $r = $w.BoundingRect
                if ($r.X -lt $minX) { $minX = $r.X }; if ($r.Y -lt $minY) { $minY = $r.Y }
                $rx = $r.X + $r.Width; $ry = $r.Y + $r.Height
                if ($rx -gt $maxX) { $maxX = $rx }; if ($ry -gt $maxY) { $maxY = $ry }
            }
            $t = ($words | ForEach-Object { $_.Text }) -join ' '
            Write-Output ("{0:F1}|{1:F1}|{2:F1}|{3:F1}|{4}" -f $minX, $minY, ($maxX-$minX), ($maxY-$minY), $t)
        }
    }
} catch { Write-Error $_.Exception.Message; exit 1 }
'''

def ocr(path):
    env = os.environ.copy(); env['EPR_OCR_IMAGE'] = os.path.abspath(path)
    try:
        r = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', _OCR],
                           capture_output=True, text=True, timeout=30, env=env, creationflags=0x08000000)
    except Exception as e: return [], str(e)
    out = r.stdout or ""
    err = r.stderr or ""
    lines = []
    for ln in out.strip().splitlines():
        p = ln.split('|', 4)
        if len(p) == 5:
            try: lines.append((float(p[0]), float(p[1]), float(p[2]), float(p[3]), p[4]))
            except ValueError: pass
    return lines, err.strip()

def ocr_find(lines, text, bounds=None):
    """Return (img_cx, img_cy) of first match or None.
    bounds=(left,top,right,bottom) restricts to that screen region."""
    tl = text.lower()
    for x, y, w, h, t in lines:
        if tl in t.lower():
            cx, cy = x + w/2, y + h/2
            if bounds:
                bl, bt, br, bb = bounds
                if cx < bl or cx > br or cy < bt or cy > bb:
                    continue
            return (cx, cy)
    return None

def ocr_find_topmost(lines, text, bounds=None):
    """Return (img_cx, img_cy) of the topmost (smallest Y) match or None."""
    tl = text.lower()
    best = None
    for x, y, w, h, t in lines:
        if tl in t.lower():
            cx, cy = x + w/2, y + h/2
            if bounds:
                bl, bt, br, bb = bounds
                if cx < bl or cx > br or cy < bt or cy > bb:
                    continue
            if best is None or cy < best[1]:
                best = (cx, cy)
    return best

def ocr_has(lines, text, bounds=None):
    tl = text.lower()
    for x, y, w, h, t in lines:
        if tl in t.lower():
            if bounds:
                cx, cy = x + w/2, y + h/2
                bl, bt, br, bb = bounds
                if cx < bl or cx > br or cy < bt or cy > bb:
                    continue
            return True
    return False

def ocr_click(lines, text, bounds=None):
    """Click on text found in full-screen OCR. Coords are already screen coords."""
    pos = ocr_find(lines, text, bounds=bounds)
    if not pos: return False
    mclick(int(pos[0]), int(pos[1])); return True

# ==================================================================
#  Menu reading
# ==================================================================

def find_popup_menu():
    menus = []
    def _cb(h, _):
        if user32.IsWindowVisible(h) and gcn(h) == "#32768": menus.append(h)
        return True
    user32.EnumWindows(EnumWindowsProc(_cb), 0)
    return menus[0] if menus else None

def read_menu(mhwnd):
    hm = user32.SendMessageW(mhwnd, MN_GETHMENU, 0, 0)
    if not hm: return []
    n = user32.GetMenuItemCount(hm); items = []
    for i in range(n):
        b = ctypes.create_unicode_buffer(256)
        user32.GetMenuStringW(hm, i, b, 256, MF_BYPOSITION)
        txt = b.value.replace("&", "")
        r = RECT(); user32.GetMenuItemRect(0, hm, i, ctypes.byref(r))
        items.append((i, txt, (r.left+r.right)//2, (r.top+r.bottom)//2))
    return items

def menu_click(mhwnd, search, hover=False):
    for _, txt, cx, cy in read_menu(mhwnd):
        if search.lower() in txt.lower():
            if hover: mmove(cx, cy)
            else: mclick(cx, cy)
            return True
    return False

# ==================================================================
#  State machine worker
# ==================================================================

# States — shared
S_CAPTURE       = "CAPTURE"
S_DONE          = "DONE"
# States — SystmOne
S_FIND_SEARCH   = "FIND_SEARCH"
S_WAIT_DIALOG   = "WAIT_DIALOG"
S_TYPE_NAME     = "TYPE_NAME"
S_SUBMIT        = "SUBMIT"
S_SELECT        = "SELECT"
S_DISMISS       = "DISMISS"
S_FIND_JOURNAL  = "FIND_JOURNAL"
S_RCLICK_NOTES  = "RCLICK_NOTES"
S_READ_MENU     = "READ_MENU"
S_FIND_TABLE    = "FIND_TABLE"
S_FIND_CSV      = "FIND_CSV"
S_SAVE_DIALOG   = "SAVE_DIALOG"
# States — CareNotes
S_CN_CLICK_SEARCH = "CN_CLICK_SEARCH"
S_CN_FIND_NHS   = "CN_FIND_NHS"
S_CN_TYPE_NHS   = "CN_TYPE_NHS"
S_CN_SELECT     = "CN_SELECT"
S_CN_OPEN_NOTES = "CN_OPEN_NOTES"
S_CN_WAIT_LOAD  = "CN_WAIT_LOAD"
S_CN_COPY       = "CN_COPY"

# System types
SYS_S1 = "systmone"
SYS_CN = "carenotes"


class LiveWorker(QThread):
    log = Signal(str)
    preview = Signal(object)
    state_changed = Signal(str)
    csv_ready = Signal(list)  # list of rows (each row is a list of strings)
    set_clickthrough = Signal(bool)  # True=pass clicks through, False=normal
    hide_overlay = Signal(bool)      # True=hide overlay for capture, False=show
    done = Signal(bool, str)

    def __init__(self, hwnd, nhs, system, embedded=False):
        super().__init__()
        self.hwnd = hwnd
        self.nhs = nhs
        self.system = system  # SYS_S1 or SYS_CN
        self.embedded = embedded  # True = window reparented inside MyPsychAdmin
        self._stop = Event()
        self._overlay_event = Event()
        self.state = S_CAPTURE
        self._ocr_lines = []
        self._dismiss_count = 0
        self._scan_count = 0
        self._rclick_count = 0

    def stop(self): self._stop.set()

    def _check(self):
        if self._stop.is_set(): raise InterruptedError("Stopped")

    def _sleep(self, s):
        end = time.time() + s
        while time.time() < end:
            self._check(); time.sleep(min(0.1, end - time.time()))

    def _set(self, s):
        self.state = s
        self.state_changed.emit(s)

    def run(self):
        time.sleep(0.2)
        try:
            while self.state != S_DONE:
                self._check()
                try:
                    self._tick()
                except InterruptedError:
                    raise
                except Exception as e:
                    self.log.emit(f"  Tick error ({self.state}): {e}")
                    self._sleep(0.5)
                self._sleep(0.15)
        except InterruptedError:
            self.done.emit(False, "Stopped by user")
        except Exception as e:
            self.done.emit(False, f"Error: {e}")

    def _tick(self):
        s = self.state

        if s == S_CAPTURE:
            self._do_capture()

        elif s == S_FIND_SEARCH:
            self._do_find_search()

        elif s == S_WAIT_DIALOG:
            self._do_wait_dialog()

        elif s == S_TYPE_NAME:
            self._do_type_name()

        elif s == S_SUBMIT:
            self._do_submit()

        elif s == S_SELECT:
            self._do_select()

        elif s == S_DISMISS:
            self._do_dismiss()

        elif s == S_FIND_JOURNAL:
            self._do_find_journal()

        elif s == S_RCLICK_NOTES:
            self._do_rclick_notes()

        elif s == S_READ_MENU:
            self._do_read_menu()

        elif s == S_FIND_TABLE:
            self._do_find_table()

        elif s == S_FIND_CSV:
            self._do_find_csv()

        elif s == S_SAVE_DIALOG:
            self._do_save_dialog()

        # CareNotes states
        elif s == S_CN_CLICK_SEARCH:
            self._do_cn_click_search()

        elif s == S_CN_FIND_NHS:
            self._do_cn_find_nhs()

        elif s == S_CN_TYPE_NHS:
            self._do_cn_type_nhs()

        elif s == S_CN_SELECT:
            self._do_cn_select()

        elif s == S_CN_OPEN_NOTES:
            self._do_cn_open_notes()

        elif s == S_CN_WAIT_LOAD:
            self._do_cn_wait_load()

        elif s == S_CN_COPY:
            self._do_cn_copy()

    # -- Capture + OCR -------------------------------------------------

    def _scan(self, focus=True):
        """Capture target window and OCR it."""
        if self.embedded:
            # Hide overlay so PrintWindow captures the real EPR content
            self._overlay_event.clear()
            self.hide_overlay.emit(True)
            self._overlay_event.wait(timeout=0.5)
            time.sleep(0.15)  # extra wait for DWM to composite without overlay
            # Embedded mode: capture the reparented window directly
            pix, png, (wx, wy) = capture_window(self.hwnd)
            # Restore overlay
            self.hide_overlay.emit(False)
            if not pix:
                self.log.emit("  Capture failed, retrying ...")
                return False
            self._last_pix = pix
            self._dbg_click = None
            self.preview.emit(pix)
            lines, err = ocr(png)
            if err:
                self.log.emit(f"  OCR error: {err[:120]}")
            if not lines:
                self.log.emit(f"  OCR returned 0 lines, retrying ...")
                return False
            # Convert window-relative coords to screen coords
            self._ocr_lines = [(x + wx, y + wy, w, h, t) for x, y, w, h, t in lines]
            return True
        else:
            # Foreground mode — capture just the S1 window (no bring_front needed,
            # so S1 stays behind other windows and isn't visible on screen)
            pix, png, (wx, wy) = capture_window(self.hwnd)
            if not pix:
                self.log.emit("  Capture failed, retrying ...")
                return False
            self._last_pix = pix
            self._dbg_click = None
            self.preview.emit(pix)
            lines, err = ocr(png)
            if err:
                self.log.emit(f"  OCR error: {err[:120]}")
            if not lines:
                self.log.emit(f"  OCR returned 0 lines, retrying ...")
                return False
            # Convert window-relative coords to screen coords
            self._ocr_lines = [(x + wx, y + wy, w, h, t) for x, y, w, h, t in lines]
            return True

    # -- Focus helpers ---------------------------------------------------

    def _focus_target(self):
        """Ensure target window has focus for click/keyboard interaction."""
        if self.embedded:
            user32.SetFocus(self.hwnd)
            time.sleep(0.1)
        else:
            bring_front(self.hwnd)
            time.sleep(0.15)

    def _unfocus_target(self):
        """No-op for embedded mode; foreground mode does nothing extra."""
        pass

    # -- State handlers ------------------------------------------------

    def _do_capture(self):
        name = "CareNotes" if self.system == SYS_CN else "SystmOne"
        self.log.emit(f"Scanning {name} ...")
        if self._scan():
            self.log.emit(f"  OCR: {len(self._ocr_lines)} lines")
            for _, _, _, _, t in self._ocr_lines[:5]:
                self.log.emit(f"  > {t}")
            if self.system == SYS_CN:
                self._set(S_CN_CLICK_SEARCH)
            else:
                self._set(S_FIND_SEARCH)
        else:
            self._sleep(1)

    def _do_find_search(self):
        # First check: are there any popup dialogs already?
        dlgs = popup_dialogs()
        if dlgs:
            self.log.emit(f"  Dialog found: '{dlgs[0][1]}' - dismissing first")
            self._set(S_DISMISS)
            return

        s1 = self._s1_bounds()
        self.log.emit(f"Looking for Search button inside S1 {s1} ...")
        self.set_clickthrough.emit(True); time.sleep(0.1)
        for term in ("Search", "Find Patient", "Patient Search", "Find"):
            if ocr_click(self._ocr_lines, term, bounds=s1):
                self.log.emit(f"  Clicked '{term}'")
                self.set_clickthrough.emit(False)
                self._sleep(1.5)
                self._set(S_WAIT_DIALOG)
                return
        self.set_clickthrough.emit(False)
        self.log.emit("  Search button not found in S1, rescanning ...")
        self._sleep(1)
        self._scan()

    def _do_wait_dialog(self):
        self.log.emit("Waiting for search dialog ...")
        for _ in range(15):
            self._check()
            dlg = (find_titled("Search") or find_titled("Find Patient")
                   or find_titled("Patient Search"))
            if dlg:
                h, t = dlg[0]
                self.log.emit(f"  Dialog: {t}")
                bring_front(h)
                self._sleep(0.4)
                self._set(S_TYPE_NAME)
                return
            time.sleep(0.5)
        self.log.emit("  Dialog didn't appear, rescanning ...")
        self._set(S_CAPTURE)

    def _do_type_name(self):
        self.log.emit(f"Typing NHS '{self.nhs}' ...")
        typetxt(self.nhs)
        self._sleep(0.3)
        self._set(S_SUBMIT)

    def _do_submit(self):
        self.log.emit("Submitting search ...")
        # Try to find the search dialog and click its Search button
        dlg = (find_titled("Search") or find_titled("Find Patient")
               or find_titled("Patient Search"))
        if dlg:
            h, _ = dlg[0]
            bb = (find_children(h, cls="Button", txt="Search")
                  or find_children(h, cls="Button", txt="Find"))
            if bb:
                click_btn(bb[0])
            else:
                pkey(VK_RETURN)
        else:
            pkey(VK_RETURN)
        self._unfocus_target()
        self._sleep(1.5)
        self._set(S_SELECT)

    def _do_select(self):
        self.log.emit("Alt+S (Select patient) ...")
        self._focus_target()
        altkey(VK_S)
        self._sleep(2)

        # Check for "record in use" warning popup
        self.log.emit("  Checking for 'record in use' warning ...")
        if self._scan():
            if ocr_has(self._ocr_lines, "This patient's record is currently in use by"):
                self.log.emit("  WARNING: Record in use popup detected - pressing Alt+O (Ok) ...")
                self._focus_target()
                altkey(VK_O)
                self._sleep(0.8)
                self.log.emit("  Dismissed 'record in use' warning")
            elif ocr_has(self._ocr_lines, "Warning") and ocr_has(self._ocr_lines, "currently in use"):
                self.log.emit("  WARNING: Record in use popup detected (partial match) - pressing Alt+O ...")
                self._focus_target()
                altkey(VK_O)
                self._sleep(0.8)
                self.log.emit("  Dismissed 'record in use' warning")
            else:
                self.log.emit("  No 'record in use' warning found, proceeding ...")

        self._unfocus_target()
        self._scan_count = 0
        self._set(S_FIND_JOURNAL)

    def _do_dismiss(self):
        # Only used if a real Win32 popup (#32770) blocks us
        dlgs = popup_dialogs()
        if dlgs:
            h, t = dlgs[0]
            self.log.emit(f"  Dialog: '{t}' - dismissing with Alt+O/C/Y/L ...")
            self._focus_target()
            bring_front(h); time.sleep(0.2)
            pl, pt, pr, pb = gwr(h)
            mclick((pl + pr) // 2, (pt + pb) // 2); time.sleep(0.2)
            # Try all common dialog shortcuts — check BEFORE each send
            for vk, name in [(VK_O, "O"), (VK_Y, "Y"), (VK_L, "L"), (VK_C, "C")]:
                if not (user32.IsWindow(h) and user32.IsWindowVisible(h)):
                    break
                bring_front(h); time.sleep(0.1)
                altkey(vk); time.sleep(0.3)
            if user32.IsWindow(h) and user32.IsWindowVisible(h):
                dismiss_ok(h); time.sleep(0.2)
            if user32.IsWindow(h) and user32.IsWindowVisible(h):
                pkey(VK_RETURN); time.sleep(0.2)
            self._unfocus_target()
            self._sleep(0.5)
        # Always go back to find journal
        self._set(S_FIND_JOURNAL)

    def _s1_bounds(self):
        """Return SystmOne window bounds for filtering OCR results."""
        return gwr(self.hwnd)

    def _do_find_journal(self):
        self._scan_count += 1
        self.log.emit(f"Looking for Tabbed Journal (attempt {self._scan_count}) ...")

        # Dismiss any real popup dialogs first
        dlgs = popup_dialogs()
        if dlgs:
            self.log.emit(f"  Popup dialog found, dismissing ...")
            self._set(S_DISMISS)
            return

        # Scan screen
        if not self._scan():
            self._sleep(1); return

        s1 = self._s1_bounds()

        # Look for "Tabbed Journal" directly and click it
        tj = ocr_find(self._ocr_lines, "Tabbed Journal", bounds=s1)
        if tj:
            self.log.emit(f"  Found 'Tabbed Journal' at ({int(tj[0])}, {int(tj[1])}) - clicking it")
            bring_front(self.hwnd)
            time.sleep(0.2)
            mclick(int(tj[0]), int(tj[1]))
            self._sleep(2)
            self._rclick_count = 0
            self._set(S_RCLICK_NOTES)
            return

        # Tabbed Journal not visible yet — dismiss any popups blocking it
        if self._scan_count <= 15:
            # Look for any popup dialog and bring it to front
            dlgs = popup_dialogs()
            if dlgs:
                h, t = dlgs[0]
                self.log.emit(f"  Popup found: '{t}' - clicking it ...")
                bring_front(h)
                self._sleep(0.3)
                pl, pt, pr, pb = gwr(h)
                mclick((pl + pr) // 2, (pt + pb) // 2)
                self._sleep(0.3)
            else:
                bring_front(self.hwnd)
                self._sleep(0.3)
                wl, wt_c, wr, wb = gwr(self.hwnd)
                mclick((wl + wr) // 2, (wt_c + wb) // 2)
                self._sleep(0.3)

            if self._scan_count % 2 == 1:
                self.log.emit("  Pressing Alt+O ...")
                altkey(VK_O)
            else:
                self.log.emit("  Pressing Alt+C (close) ...")
                altkey(VK_C)
            self._sleep(1.5)
        else:
            self.log.emit("  Cannot find Tabbed Journal after 15 attempts")
            self._set(S_DONE)
            self.done.emit(False, "Could not find Tabbed Journal")

    def _do_rclick_notes(self):
        self._rclick_count += 1
        self.log.emit(f"Looking for Local Data (attempt {self._rclick_count}) ...")

        # Scan to find "Local Data" text — proves Tabbed Journal loaded
        if not self._scan():
            self._sleep(1); return

        s1 = self._s1_bounds()
        ld = ocr_find(self._ocr_lines, "Local Data", bounds=s1)

        if not ld:
            # Local Data not visible — Tabbed Journal may not have loaded yet
            # Go back and click Tabbed Journal again
            if self._rclick_count <= 10:
                self.log.emit("  'Local Data' not found — clicking Tabbed Journal again ...")
                self._scan_count = 0
                self._set(S_FIND_JOURNAL)
            else:
                self.log.emit("  'Local Data' not found after 10 attempts, giving up")
                self._set(S_DONE)
                self.done.emit(False, "Could not find Local Data in Tabbed Journal")
            return

        # Found Local Data — right-click 50px below it for context menu
        nx = int(ld[0])
        ny = int(ld[1]) + 50
        self.log.emit(f"  Found 'Local Data' at ({int(ld[0])}, {int(ld[1])}), right-clicking 50px below at ({nx}, {ny})")

        # Make our window click-through so it doesn't intercept mouse events
        self.set_clickthrough.emit(True)
        self._sleep(0.2)

        bring_front(self.hwnd)
        self._sleep(0.3)

        # Left-click to focus notes area
        mclick(nx, ny, btn="left")
        self._sleep(0.5)

        # Right-click for context menu
        self.log.emit(f"  Right-clicking at ({nx}, {ny}) ...")
        mclick(nx, ny, btn="right")
        self._sleep(1.0)

        # Restore normal click behaviour
        self.set_clickthrough.emit(False)

        # Keyboard navigation: Down x10 to "Table"
        self.log.emit("  Menu open - Down x10 to Table ...")
        for _ in range(10):
            pkey(VK_DOWN); time.sleep(0.1)
        self._sleep(0.3)
        self._set(S_FIND_TABLE)

    def _do_read_menu(self):
        self._set(S_FIND_TABLE)

    def _do_find_table(self):
        # Right arrow to open Table submenu — RTF is already highlighted
        self.log.emit("  Right arrow (Table submenu) then Enter (Open as RTF) ...")
        pkey(VK_RIGHT)
        self._sleep(0.3)
        pkey(VK_RETURN)
        self._unfocus_target()
        self._sleep(2.5)
        self._set(S_SAVE_DIALOG)

    def _do_find_csv(self):
        # Kept for state machine but now unused — go straight to save
        self._set(S_SAVE_DIALOG)

    def _do_save_dialog(self):
        # File opened in Excel or Word — find whichever appeared, select all, copy
        self.log.emit("Looking for Excel or Word ...")

        app_win = None
        app_type = None  # "excel" or "word"
        for _ in range(20):
            self._check()
            # Check Excel first
            for term in ("Excel", ".csv", "CSV"):
                hits = find_titled(term)
                if hits:
                    app_win = hits[0]; app_type = "excel"; break
            if app_win: break
            # Check Word / RTF
            for term in ("Word", ".rtf", ".doc"):
                hits = find_titled(term)
                if hits:
                    app_win = hits[0]; app_type = "word"; break
            if app_win: break
            time.sleep(0.5)

        if not app_win:
            self.log.emit("  Neither Excel nor Word found, trying clipboard ...")
        else:
            h, t = app_win
            self.log.emit(f"  Found {app_type}: {t}")
            bring_front(h)
            self._sleep(0.8)

            if app_type == "excel":
                # Ctrl+Home -> Ctrl+A x2 -> Ctrl+C
                self.log.emit("  Excel: Ctrl+Home, Ctrl+A x2, Ctrl+C ...")
                skey(0x11, True); time.sleep(0.05)
                pkey(VK_HOME)
                skey(0x11, False)
                self._sleep(0.3)
                for _ in range(2):
                    skey(0x11, True); time.sleep(0.05)
                    pkey(VK_A)
                    skey(0x11, False); time.sleep(0.2)
                self._sleep(0.3)
            else:
                # Word: wait for document to finish loading
                self.log.emit("  Waiting for Word to finish loading ...")
                for _w in range(30):  # up to 15 seconds
                    self._check()
                    t_now = gwt(h)
                    if "Opening" not in t_now:
                        break
                    time.sleep(0.5)
                bring_front(h)
                self._sleep(1.0)
                # Word: Ctrl+A to select all
                self.log.emit("  Word: Ctrl+A ...")
                skey(0x11, True); time.sleep(0.05)
                pkey(VK_A)
                skey(0x11, False)
                self._sleep(0.3)

            # Ctrl+C (copy)
            self.log.emit("  Ctrl+C (copy) ...")
            skey(0x11, True); time.sleep(0.05)
            pkey(VK_C)
            skey(0x11, False)
            self._sleep(0.5)

        # Read clipboard
        self.log.emit("  Reading clipboard ...")
        rows = self._read_clipboard()

        if rows:
            self.log.emit(f"  Got {len(rows)} rows from clipboard")
        else:
            self.log.emit("  Clipboard empty or not text")

        # Close the app: Alt+F4, then dismiss "Don't Save"
        self._close_app(app_win, app_type)

        # Check if we got enough data (>=10 rows)
        MIN_ROWS = 10
        if len(rows) < MIN_ROWS:
            self._export_retries = getattr(self, '_export_retries', 0) + 1
            if self._export_retries >= 5:
                self.log.emit(f"  Only {len(rows)} rows after {self._export_retries} attempts, giving up")
                self._set(S_DONE)
                if rows:
                    self.csv_ready.emit(rows)
                    self.done.emit(True, f"Loaded {len(rows)} rows (after {self._export_retries} attempts)")
                else:
                    self.done.emit(False, "Could not read enough data")
                return
            self.log.emit(f"  Only {len(rows)} rows (<{MIN_ROWS}), retrying (attempt {self._export_retries}) ...")
            self._sleep(1)
            # Go back to S1 and retry the right-click -> export flow
            if not self.embedded:
                bring_front(self.hwnd)
                self._sleep(0.5)
            self._set(S_RCLICK_NOTES)
            return

        # Success — enough rows
        self.csv_ready.emit(rows)
        self._set(S_DONE)
        self.done.emit(True, f"Loaded {len(rows)} rows into app")

    def _close_app(self, app_win, app_type):
        """Close Excel or Word without saving."""
        if not app_win:
            return
        h, _ = app_win
        if not user32.IsWindow(h):
            return
        self.log.emit(f"  Closing {app_type} (Alt+F4) ...")
        bring_front(h); self._sleep(0.3)
        skey(VK_MENU, True); time.sleep(0.05)
        pkey(0x73)  # VK_F4
        skey(VK_MENU, False)
        self._sleep(1)

        # "Don't Save" - try button click, then 'N' key
        for attempt in range(3):
            dlgs = popup_dialogs()
            if dlgs:
                dh, dt = dlgs[0]
                self.log.emit(f"  Save dialog: '{dt}' - dismissing ...")
                bring_front(dh); time.sleep(0.3)
                bb = find_children(dh, cls="Button", txt="Don")
                if bb:
                    click_btn(bb[0]); break
                bb2 = find_children(dh, cls="Button", txt="No")
                if bb2:
                    click_btn(bb2[0]); break
                pkey(0x4E); break  # 'N'
            hits2 = find_titled("Excel") or find_titled("Word") or find_titled(".csv") or find_titled(".rtf")
            if hits2:
                bring_front(hits2[0][0]); time.sleep(0.3)
                pkey(0x4E); break  # 'N' for Don't Save
            time.sleep(0.5)
        self._unfocus_target()
        self._sleep(0.5)

    def _read_clipboard(self):
        """Read table from Windows clipboard.
        Prefers HTML format (preserves table structure from Word),
        falls back to plain text tab-separated."""
        import re as _re

        CF_UNICODETEXT = 13
        # Register HTML clipboard format
        cf_html = ctypes.windll.user32.RegisterClipboardFormatW("HTML Format")

        user32.OpenClipboard(0)
        try:
            # --- Try HTML format first (from Word) ---
            if cf_html:
                h = user32.GetClipboardData(cf_html)
                if h:
                    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
                    kernel32.GlobalLock.restype = ctypes.c_void_p
                    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
                    kernel32.GlobalSize.argtypes = [ctypes.c_void_p]
                    kernel32.GlobalSize.restype = ctypes.c_size_t
                    ptr = kernel32.GlobalLock(h)
                    if ptr:
                        sz = kernel32.GlobalSize(h)
                        raw = ctypes.string_at(ptr, sz)
                        kernel32.GlobalUnlock(h)
                        # HTML clipboard is UTF-8 with a header
                        html = raw.decode('utf-8', errors='replace')
                        rows = self._parse_html_table(html)
                        if rows:
                            return rows

            # --- Fallback: plain text ---
            h = user32.GetClipboardData(CF_UNICODETEXT)
            if not h: return []
            kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
            kernel32.GlobalLock.restype = ctypes.c_wchar_p
            kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
            text = kernel32.GlobalLock(h)
            if not text:
                return []
            data = str(text)
            kernel32.GlobalUnlock(h)
        finally:
            user32.CloseClipboard()
        # Parse tab-separated text into rows
        rows = []
        for line in data.splitlines():
            if line.strip():
                rows.append(line.split('\t'))
        return rows

    def _parse_html_table(self, html):
        """Extract rows from HTML table in clipboard data."""
        import re as _re
        # Find the HTML content (skip clipboard header lines)
        start = html.find('<')
        if start < 0: return []
        html = html[start:]
        # Find all table rows
        rows = []
        for tr_match in _re.finditer(r'<tr[^>]*>(.*?)</tr>', html, _re.DOTALL | _re.IGNORECASE):
            tr = tr_match.group(1)
            cells = []
            for td_match in _re.finditer(r'<t[dh][^>]*>(.*?)</t[dh]>', tr, _re.DOTALL | _re.IGNORECASE):
                cell_html = td_match.group(1)
                # Strip HTML tags, decode entities, collapse whitespace
                txt = _re.sub(r'<[^>]+>', ' ', cell_html)
                txt = txt.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
                txt = txt.replace('&nbsp;', ' ').replace('&#160;', ' ')
                txt = _re.sub(r'\s+', ' ', txt).strip()
                cells.append(txt)
            if cells:
                rows.append(cells)
        return rows

    # -- CareNotes state handlers --------------------------------------

    def _do_cn_click_search(self):
        """Click 'Patient Search' in the CareNotes left sidebar."""
        self._scan_count = getattr(self, '_cn_search_count', 0) + 1
        self._cn_search_count = self._scan_count
        self.log.emit(f"CareNotes: Looking for 'Patient Search' (attempt {self._scan_count}) ...")

        if not self._scan():
            self._sleep(1)
            return

        cn = self._s1_bounds()
        self.set_clickthrough.emit(True)
        time.sleep(0.1)
        self._focus_target()

        for term in ("Patient Search", "Patient search"):
            if ocr_click(self._ocr_lines, term, bounds=cn):
                self.log.emit(f"  Clicked '{term}'")
                self.set_clickthrough.emit(False)
                self._unfocus_target()
                self._sleep(1.5)
                self._scan_count = 0
                self._set(S_CN_FIND_NHS)
                return

        self.set_clickthrough.emit(False)
        self._unfocus_target()

        if self._scan_count >= 10:
            self.log.emit("  'Patient Search' not found after 10 attempts")
            self._set(S_DONE)
            self.done.emit(False, "Could not find Patient Search in CareNotes sidebar")
        else:
            self._sleep(1)

    def _do_cn_find_nhs(self):
        """Tab x3 to reach the NHS Number field in CareNotes."""
        self.log.emit("CareNotes: Tab x3 to NHS Number field ...")
        self._focus_target()
        bring_front(self.hwnd)
        self._sleep(0.3)
        # Tab 3 times to reach the NHS Number input
        for i in range(3):
            pkey(VK_TAB); time.sleep(0.2)
        self._sleep(0.2)
        self._set(S_CN_TYPE_NHS)

    def _do_cn_type_nhs(self):
        """Type the NHS number and press Enter to search."""
        self.log.emit(f"CareNotes: Typing NHS '{self.nhs}' ...")
        typetxt(self.nhs)
        self._sleep(0.3)
        self.log.emit("  Pressing Enter to search ...")
        pkey(VK_RETURN)
        self._unfocus_target()
        self._sleep(2)
        self._scan_count = 0
        self._set(S_CN_SELECT)

    def _do_cn_select(self):
        """Select the patient in CareNotes search results.
        Find the results table header row (Surname, Forename, DOB, etc.)
        and click 50px below it to hit the first data row."""
        self._scan_count += 1
        self.log.emit(f"CareNotes: Looking for results header (attempt {self._scan_count}) ...")

        if not self._scan():
            self._sleep(1); return

        cn = self._s1_bounds()

        # Find the header row by looking for column headers
        header_terms = ("Surname", "Forename", "DOB", "Postcode", "NHS Number",
                        "NHS number", "Local ID", "CPA Level", "GP Practice")
        header_y = None
        header_x = None
        for term in header_terms:
            for x, y, w, h, t in self._ocr_lines:
                if term.lower() in t.lower():
                    cx, cy = x + w / 2, y + h / 2
                    if cn:
                        bl, bt, br, bb = cn
                        if cx < bl or cx > br or cy < bt or cy > bb:
                            continue
                    header_y = y + h  # bottom edge of header text
                    header_x = cx
                    self.log.emit(f"  Found header '{term}' at ({int(cx)}, {int(cy)})")
                    break
            if header_y is not None:
                break

        if header_y is not None:
            # Click 50px below the header to hit the first data row
            click_y = int(header_y) + 50
            click_x = int(header_x)
            self._dbg_click = (click_x, click_y)
            self.preview.emit(self._last_pix if hasattr(self, '_last_pix') else None)
            self.log.emit(f"  Clicking patient row at ({click_x}, {click_y}) [header bottom={int(header_y)}]")
            self.set_clickthrough.emit(True); time.sleep(0.1)
            self._focus_target()
            mclick(click_x, click_y)
            mclick(click_x, click_y)  # double-click to open
            self.set_clickthrough.emit(False)
            self._unfocus_target()
            self._sleep(2)
            self._scan_count = 0
            self._set(S_CN_OPEN_NOTES)
            return

        # Log OCR for debugging
        if self._scan_count <= 2:
            self.log.emit("  OCR lines in CareNotes:")
            for _, _, _, _, t in self._ocr_lines[:30]:
                self.log.emit(f"    > {t}")

        if self._scan_count >= 10:
            self.log.emit("  Results header not found after 10 attempts")
            self._set(S_DONE)
            self.done.emit(False, "Could not find patient results in CareNotes")
        else:
            self._sleep(1)

    def _do_cn_open_notes(self):
        """Press Alt+S to open dropdown, then find and click 'Clinical Notes (All)'."""
        self.log.emit("CareNotes: Alt+S to open dropdown ...")
        self._focus_target()
        bring_front(self.hwnd)
        self._sleep(0.2)
        altkey(VK_S)
        self._sleep(0.8)

        # Scan for "Clinical Notes" in the dropdown
        self.set_clickthrough.emit(True); time.sleep(0.1)
        if not self._scan(focus=False):
            self.set_clickthrough.emit(False)
            self._unfocus_target()
            self._sleep(1); return

        cn = self._s1_bounds()
        pos = None
        for term in ("Clinical Notes (All)", "Clinical Notes"):
            pos = ocr_find(self._ocr_lines, term, bounds=cn)
            if pos:
                self.log.emit(f"  Found '{term}' at ({int(pos[0])}, {int(pos[1])})")
                break

        if pos:
            mclick(int(pos[0]), int(pos[1]))
            self.set_clickthrough.emit(False)
            self._unfocus_target()
            self.log.emit("  Clicked Clinical Notes - waiting for load ...")
            self._sleep(2)
            self._scan_count = 0
            self._set(S_CN_WAIT_LOAD)
        else:
            self.set_clickthrough.emit(False)
            self._unfocus_target()
            self._scan_count += 1
            if self._scan_count <= 2:
                self.log.emit("  Dropdown OCR lines:")
                for _, _, _, _, t in self._ocr_lines[:20]:
                    self.log.emit(f"    > {t}")
            if self._scan_count >= 5:
                self.log.emit("  Could not find Clinical Notes in dropdown")
                self._set(S_DONE)
                self.done.emit(False, "Clinical Notes not found in dropdown")
            else:
                self._sleep(1)

    def _do_cn_wait_load(self):
        """Wait for notes to load by checking area below Alert.
        Keep doing Ctrl+A -> Ctrl+C -> check clipboard until we get real content."""
        self._scan_count += 1
        self.log.emit(f"CareNotes: Waiting for notes to load (attempt {self._scan_count}) ...")

        self._focus_target()
        bring_front(self.hwnd)
        self._sleep(0.5)

        # Ctrl+A to select all
        skey(0x11, True); time.sleep(0.05)
        pkey(VK_A)
        skey(0x11, False)
        self._sleep(0.5)

        # Ctrl+C to copy
        skey(0x11, True); time.sleep(0.05)
        pkey(VK_C)
        skey(0x11, False)
        self._unfocus_target()
        self._sleep(0.5)

        # Check clipboard
        rows = self._read_clipboard()
        self.log.emit(f"  Clipboard: {len(rows)} rows")

        MIN_ROWS = 10
        if len(rows) >= MIN_ROWS:
            self.log.emit(f"  Notes loaded! Got {len(rows)} rows")
            self._set(S_CN_COPY)
            return

        if self._scan_count >= 30:
            # Give up after 30 attempts (~60+ seconds)
            self.log.emit("  Timed out waiting for notes to load")
            if rows:
                self._set(S_CN_COPY)
            else:
                self._set(S_DONE)
                self.done.emit(False, "Notes did not load in time")
            return

        # Not ready yet — wait and retry
        self._sleep(2)

    def _do_cn_copy(self):
        """Final copy — clipboard should already have content from wait_load polling."""
        self.log.emit("CareNotes: Final Ctrl+A, Ctrl+C ...")
        self._focus_target()
        bring_front(self.hwnd)
        self._sleep(0.3)

        # One more Ctrl+A -> Ctrl+C to be sure
        skey(0x11, True); time.sleep(0.05)
        pkey(VK_A)
        skey(0x11, False)
        self._sleep(0.5)

        skey(0x11, True); time.sleep(0.05)
        pkey(VK_C)
        skey(0x11, False)
        self._unfocus_target()
        self._sleep(0.5)

        rows = self._read_clipboard()

        if rows:
            self.csv_ready.emit(rows)
            self.log.emit(f"  Got {len(rows)} rows from clipboard")
            self._set(S_DONE)
            self.done.emit(True, f"Loaded {len(rows)} rows from CareNotes")
        else:
            self.log.emit("  Clipboard empty")
            self._set(S_DONE)
            self.done.emit(False, "Could not copy notes from CareNotes")


# ==================================================================
#  Window Picker
# ==================================================================

class PickerBtn(QPushButton):
    picked = Signal(int, str)
    def __init__(self):
        super().__init__("[+]"); self.setFixedSize(40, 30)
        self.setStyleSheet(
            "QPushButton{font-weight:bold;font-size:14px;border:2px solid #000;"
            "border-radius:4px;background:#fff176;color:#000}"
            "QPushButton:hover{border-color:#f57f17}")
        self._d = False
    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self._d = True; self.setCursor(QCursor(Qt.CrossCursor)); self.grabMouse()
    def mouseMoveEvent(self, e): pass
    def mouseReleaseEvent(self, e):
        if self._d:
            self._d = False; self.releaseMouse(); self.setCursor(QCursor(Qt.ArrowCursor))
            pt = POINT(); user32.GetCursorPos(ctypes.byref(pt))
            h = user32.WindowFromPoint(pt)
            if h:
                h = user32.GetAncestor(h, GA_ROOT)
                self.picked.emit(int(h), gwt(h))


# ==================================================================
#  EPR Embed Panel (embedded in MyPsychAdmin workspace)
# ==================================================================

class EPREmbedPanel(QWidget):
    notes_captured = Signal(list)
    automation_done = Signal(bool, str, str)  # ok, msg, system_type

    def __init__(self, nhs_number="", parent=None):
        super().__init__(parent)
        self.hwnd = None
        self.worker = None
        self._system = SYS_S1
        self._orig_style = None  # saved window style before reparenting
        self._orig_rect = None   # saved window rect before reparenting
        self._build()
        if nhs_number:
            self.e_nhs.setText(nhs_number)

    def _build(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # -- Control bar (yellow, ~36px) --
        bar = QWidget()
        bar.setFixedHeight(36)
        bar.setStyleSheet(
            "QWidget{background:#ffd600;color:#000}"
            "QLineEdit{background:#fff9c4;color:#000;border:1px solid #000;border-radius:3px;padding:2px 4px;font-size:10px}"
            "QLineEdit:focus{border-color:#f57f17}"
            "QPushButton{background:#fff176;color:#000;border:1px solid #000;border-radius:3px;padding:2px 6px;font-size:10px;font-weight:bold}"
            "QPushButton:hover{background:#ffee58}"
            "QPushButton:disabled{color:#999;background:#e0e0e0}"
            "QLabel{background:transparent;color:#000}"
        )
        blay = QHBoxLayout(bar)
        blay.setContentsMargins(4, 2, 4, 2)
        blay.setSpacing(4)

        self.pk = PickerBtn()
        self.pk.picked.connect(self._picked)

        self.e_nhs = QLineEdit()
        self.e_nhs.setPlaceholderText("NHS Number")
        self.e_nhs.setFixedWidth(120)

        self.go = QPushButton("Go")
        self.go.setFixedWidth(36)
        self.go.setStyleSheet("QPushButton{background:#388e3c;color:white;font-weight:bold;border-radius:3px}")
        self.go.clicked.connect(self._start)

        self.stp = QPushButton("Stop")
        self.stp.setFixedWidth(40)
        self.stp.setStyleSheet("QPushButton{background:#c62828;color:white;border-radius:3px}")
        self.stp.clicked.connect(self._stop)
        self.stp.setEnabled(False)

        self.sys_lbl = QLabel()
        self.sys_lbl.setStyleSheet("font-size:10px;font-weight:bold;")
        self.state_lbl = QLabel()
        self.state_lbl.setStyleSheet("color:#b71c1c;font-size:10px;font-weight:bold;")
        self.status = QLabel("Drag [+] onto EPR window, enter NHS, click Go")
        self.status.setStyleSheet("font-size:10px;")

        blay.addWidget(self.pk)
        blay.addWidget(self.e_nhs)
        blay.addWidget(self.go)
        blay.addWidget(self.stp)
        blay.addWidget(self.sys_lbl)
        blay.addWidget(self.state_lbl)
        blay.addWidget(self.status, 1)

        root.addWidget(bar)

        # -- Stacked wrapper: container (for Win32 embed) + overlay on top --
        self._wrapper = QWidget()
        grid = QGridLayout(self._wrapper)
        grid.setContentsMargins(0, 0, 0, 0)
        self._container = QWidget()
        self._container.setAttribute(Qt.WA_NativeWindow, True)
        self._container.setStyleSheet("background:#1a1a2e;")
        self._overlay = self._build_overlay()
        grid.addWidget(self._container, 0, 0)
        grid.addWidget(self._overlay, 0, 0)  # same cell = stacked on top
        self._overlay.raise_()
        root.addWidget(self._wrapper, 1)

    def _build_overlay(self):
        """Build the progress overlay with live EPR preview image."""
        w = QWidget()
        w.setStyleSheet("background:#1a1a2e;")
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)

        # Live EPR screenshot (fills most of the overlay)
        self._ov_img = QLabel()
        self._ov_img.setAlignment(Qt.AlignCenter)
        self._ov_img.setStyleSheet("background:#1a1a2e;")
        self._ov_img.setScaledContents(False)
        lay.addWidget(self._ov_img, 1)

        # Bottom bar with status + log
        bottom = QWidget()
        bottom.setStyleSheet("background:rgba(13,17,23,200);")
        blay = QVBoxLayout(bottom)
        blay.setContentsMargins(12, 6, 12, 6)
        blay.setSpacing(4)

        self._ov_state = QLabel("Drag [+] onto EPR window")
        self._ov_state.setAlignment(Qt.AlignLeft)
        self._ov_state.setStyleSheet(
            "color:#e0e0e0; font-size:14px; font-weight:bold; background:transparent;")
        blay.addWidget(self._ov_state)

        self._ov_detail = QLabel("Then enter NHS number and click Go")
        self._ov_detail.setAlignment(Qt.AlignLeft)
        self._ov_detail.setStyleSheet(
            "color:#90caf9; font-size:11px; background:transparent;")
        blay.addWidget(self._ov_detail)

        self._ov_log = QTextEdit()
        self._ov_log.setReadOnly(True)
        self._ov_log.setFixedHeight(100)
        self._ov_log.setStyleSheet(
            "background:#0d1117; color:#39d353; border:1px solid #30363d;"
            "border-radius:4px; font-family:Consolas,monospace; font-size:11px;"
            "padding:4px;")
        blay.addWidget(self._ov_log)

        lay.addWidget(bottom)

        return w

    # -- Window embedding -----------------------------------------------

    def _detect_system(self, title):
        tl = title.lower()
        if "carenotes" in tl or "care notes" in tl:
            return SYS_CN
        return SYS_S1

    def _picked(self, h, t):
        # Reject picking our own application window (compare process IDs)
        target_pid = DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(target_pid))
        my_pid = kernel32.GetCurrentProcessId()
        if target_pid.value == my_pid:
            self.status.setText("Cannot pick MyPsychAdmin — pick the EPR window")
            self._addlog(f"Rejected self-pick (PID {my_pid}): {t}")
            return
        self.hwnd = h
        self._system = self._detect_system(t)
        sys_name = "CareNotes" if self._system == SYS_CN else "SystmOne"
        self.sys_lbl.setText(sys_name)
        s = (t[:30] + "...") if len(t) > 30 else t
        self.status.setText(f"Target: {s}")
        self._addlog(f"Target ({sys_name}): {t}")
        self._ov_state.setText("Window captured")
        self._ov_detail.setText("Enter NHS number and click Go")
        # No embedding — we work with the external window directly

    def _embed_window(self, hwnd):
        """Reparent target window as a child of our container.
        Falls back to overlay mode if SetParent fails (e.g. UIPI on NHS machines)."""
        self._embedded_ok = False
        try:
            # --- DEBUG: Integrity levels ---
            my_integrity = _get_process_integrity()
            target_pid = DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(target_pid))
            target_integrity = _get_process_integrity(target_pid.value)
            self._addlog(f"=== EMBED DEBUG ===")
            self._addlog(f"MyPsychAdmin PID={kernel32.GetCurrentProcessId()}, integrity={my_integrity}")
            self._addlog(f"Target PID={target_pid.value}, integrity={target_integrity}")
            self._addlog(f"Target HWND={hwnd} (0x{hwnd:X})")
            self._addlog(f"Target class: {gcn(hwnd)}")
            self._addlog(f"Target title: {gwt(hwnd)}")

            # Save original style and rect for restoration
            self._orig_style = user32.GetWindowLongW(hwnd, GWL_STYLE)
            r = RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(r))
            self._orig_rect = (r.left, r.top, r.right - r.left, r.bottom - r.top)
            self._addlog(f"Original style=0x{self._orig_style:08X}, rect=({r.left},{r.top},{r.right},{r.bottom})")

            # Get container HWND
            container_hwnd = int(self._container.winId())
            self._addlog(f"Container HWND={container_hwnd} (0x{container_hwnd:X})")
            self._addlog(f"Container valid={user32.IsWindow(container_hwnd)}")

            # Check last error before SetParent
            kernel32.SetLastError(0)

            # Attempt reparent
            result = user32.SetParent(hwnd, container_hwnd)
            last_err = kernel32.GetLastError()
            self._addlog(f"SetParent({hwnd}, {container_hwnd}) => result={result}, GetLastError={last_err}")

            if not result:
                # SetParent failed — likely UIPI / integrity level mismatch
                self._addlog(f"SetParent FAILED (error {last_err}) — using overlay mode")
                self._addlog(f"Error 5=ACCESS_DENIED, Error 87=INVALID_PARAMETER")
                self.status.setText(f"Cannot embed (err {last_err}) — using overlay mode")
                self._orig_style = None
                self._orig_rect = None
                self._use_overlay_mode(hwnd)
                return

            # Strip decorations
            style = self._orig_style & ~WS_OVERLAPPEDWINDOW | WS_CHILD | WS_VISIBLE
            user32.SetWindowLongW(hwnd, GWL_STYLE, style)

            # Apply style change
            SWP_FRAMECHANGED = 0x0020
            SWP_NOMOVE = 0x0002
            SWP_NOSIZE = 0x0001
            SWP_NOZORDER = 0x0004
            user32.SetWindowPos(hwnd, 0, 0, 0, 0, 0,
                                SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER)

            # Deferred resize
            self._embedded_ok = True
            self._embed_ready = True
            QTimer.singleShot(100, self._resize_embedded)
            QTimer.singleShot(300, self._resize_embedded)
            self._addlog(f"Embedded HWND {hwnd} into container")
        except Exception as e:
            self._addlog(f"Embed exception: {e}")
            self.status.setText(f"Embed failed — using overlay mode")
            self._use_overlay_mode(hwnd)

    def _use_overlay_mode(self, hwnd):
        """Fallback: position target window over our container area instead of reparenting."""
        self._embedded_ok = False
        self._embed_ready = True
        self._addlog("Overlay mode: positioning target window over container")
        # Move target window to cover our container area on screen
        self._reposition_overlay()
        QTimer.singleShot(100, self._reposition_overlay)
        QTimer.singleShot(300, self._reposition_overlay)

    def _reposition_overlay(self):
        """Move the target window to cover the container's screen position."""
        if not self.hwnd or not user32.IsWindow(self.hwnd):
            return
        if self._embedded_ok:
            return  # don't reposition if truly embedded
        # Map container's top-left to screen coords
        container_hwnd = int(self._container.winId())
        cr = RECT()
        user32.GetClientRect(container_hwnd, ctypes.byref(cr))
        pt = POINT()
        pt.x = cr.left
        pt.y = cr.top
        user32.ClientToScreen(container_hwnd, ctypes.byref(pt))
        w = cr.right - cr.left
        h = cr.bottom - cr.top
        if w > 0 and h > 0:
            user32.MoveWindow(self.hwnd, pt.x, pt.y, w, h, True)
            self._addlog(f"Overlay: moved to ({pt.x},{pt.y}) {w}x{h}")

    def _release_window(self):
        """Restore target window back to the desktop."""
        if not self.hwnd or not user32.IsWindow(self.hwnd):
            return
        # Restore to desktop (parent = 0)
        user32.SetParent(self.hwnd, 0)
        # Restore original style
        if self._orig_style is not None:
            user32.SetWindowLongW(self.hwnd, GWL_STYLE, self._orig_style)
        # Minimize so it doesn't smother the app
        SW_MINIMIZE = 6
        user32.ShowWindow(self.hwnd, SW_MINIMIZE)
        self._addlog(f"Released HWND {self.hwnd} back to desktop (minimized)")
        self.hwnd = None
        self._orig_style = None
        self._orig_rect = None

    def _resize_embedded(self):
        """Resize the embedded window to fill the container."""
        if not self.hwnd or not user32.IsWindow(self.hwnd):
            return
        if not getattr(self, '_embed_ready', False):
            return
        # Use Win32 GetClientRect for accurate native size
        container_hwnd = int(self._container.winId())
        cr = RECT()
        user32.GetClientRect(container_hwnd, ctypes.byref(cr))
        w = cr.right - cr.left
        h = cr.bottom - cr.top
        if w > 0 and h > 0:
            user32.MoveWindow(self.hwnd, 0, 0, w, h, True)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._resize_embedded()

    # -- Automation -----------------------------------------------------

    def _addlog(self, m):
        try:
            print(f"[EPR] {m}")
        except UnicodeEncodeError:
            print(f"[EPR] {m.encode('ascii', 'replace').decode()}")
        try:
            import datetime
            logpath = os.path.join(os.path.expanduser("~"), "Desktop", "epr_debug.txt")
            with open(logpath, "a", encoding="utf-8") as f:
                f.write(f"[{datetime.datetime.now():%H:%M:%S}] {m}\n")
        except Exception:
            pass
        # Append to overlay log
        try:
            self._ov_log.append(m)
            sb = self._ov_log.verticalScrollBar()
            sb.setValue(sb.maximum())
        except Exception:
            pass

    def _set_clickthrough(self, on):
        """No-op for embedded panel — clicks go directly to the child window."""
        pass

    def _on_hide_overlay(self, hide):
        """Hide/show overlay so PrintWindow captures the real EPR content."""
        if hide:
            self._overlay.hide()
        else:
            self._overlay.show()
            self._overlay.raise_()
        if self.worker:
            self.worker._overlay_event.set()

    def _onprev(self, px):
        """Update the in-app EPR preview image."""
        if px is None or (isinstance(px, QPixmap) and px.isNull()):
            return
        # Scale to fit the image label area
        target_size = self._ov_img.size()
        if target_size.width() < 10 or target_size.height() < 10:
            return
        scaled = px.scaled(target_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self._ov_img.setPixmap(scaled)

    _STATE_MSGS = {
        S_CAPTURE:       "Scanning screen...",
        S_FIND_SEARCH:   "Looking for search box...",
        S_WAIT_DIALOG:   "Waiting for search dialog...",
        S_TYPE_NAME:     "Entering patient name...",
        S_SUBMIT:        "Submitting search...",
        S_SELECT:        "Selecting patient...",
        S_DISMISS:       "Dismissing dialog...",
        S_FIND_JOURNAL:  "Opening journal...",
        S_RCLICK_NOTES:  "Right-clicking notes...",
        S_READ_MENU:     "Reading menu...",
        S_FIND_TABLE:    "Reading notes...",
        S_FIND_CSV:      "Reading notes...",
        S_SAVE_DIALOG:   "Exporting notes...",
        S_CN_CLICK_SEARCH: "Opening Patient Search...",
        S_CN_FIND_NHS:   "Looking for NHS field...",
        S_CN_TYPE_NHS:   "Entering NHS number...",
        S_CN_SELECT:     "Selecting patient...",
        S_CN_OPEN_NOTES: "Opening notes...",
        S_CN_WAIT_LOAD:  "Loading notes...",
        S_CN_COPY:       "Copying notes...",
        S_DONE:          "Complete!",
    }

    def _onstate(self, s):
        nice = self._STATE_MSGS.get(s, s.replace("_", " ").title())
        self.state_lbl.setText(nice)
        self._ov_state.setText(nice)

    def _start(self):
        nhs = self.e_nhs.text().strip()
        if not nhs:
            QMessageBox.warning(self, "No NHS", "Enter an NHS number.")
            return

        # Auto-find the EPR window if not already picked
        if not self.hwnd or not user32.IsWindow(self.hwnd):
            found = find_titled("SystmOne") or find_titled("CareNotes")
            if found:
                self.hwnd = found[0][0]
                title = found[0][1]
                self._system = self._detect_system(title)
                self._addlog(f"Auto-found EPR: {title}")
            else:
                QMessageBox.warning(self, "No EPR",
                    "SystmOne/CareNotes window not found.\n"
                    "Open your EPR and try again, or drag [+] onto it.")
                return

        self._addlog("=" * 40)
        self.go.setEnabled(False)
        self.stp.setEnabled(True)
        sys_name = "CareNotes" if self._system == SYS_CN else "SystmOne"
        self.status.setText(f"Running ({sys_name}) ...")
        self._ov_state.setText("Starting...")
        self._ov_state.setStyleSheet(
            "color:#e0e0e0; font-size:22px; font-weight:bold; background:transparent;")
        self._ov_detail.setText(f"Automating {sys_name}")
        self._ov_log.clear()
        self.status.setStyleSheet("color:#b71c1c;font-size:10px;font-weight:bold;")
        # Run in external (non-embedded) mode — no reparenting
        self.worker = LiveWorker(self.hwnd, nhs, self._system, embedded=False)
        self.worker.log.connect(self._addlog)
        self.worker.preview.connect(self._onprev)
        self.worker.state_changed.connect(self._onstate)
        self.worker.csv_ready.connect(self._oncsv)
        self.worker.set_clickthrough.connect(self._set_clickthrough)
        self.worker.hide_overlay.connect(self._on_hide_overlay)
        self.worker.done.connect(self._ondone)
        self.worker.start()

    def _stop(self):
        if self.worker and self.worker.isRunning():
            self.worker.stop()
            self._addlog("Stopping ...")

    def _oncsv(self, rows):
        if not rows:
            return
        self._last_rows = rows
        self._export_word(rows)
        self.notes_captured.emit(rows)
        self._detected_system = self._system
        self._addlog(f"Captured {len(rows)} rows ({self._system}), emitted to notes panel")

    def _export_word(self, rows=None):
        """Export captured rows to a Word doc on the Desktop for debugging."""
        if rows is None:
            rows = getattr(self, '_last_rows', None)
        if not rows:
            return
        html = "<html><body><h2>MyPsychAdmin EPR Export</h2>"
        html += f"<p>Total rows (incl. header): {len(rows)}</p>"
        html += "<table border='1' cellpadding='4' cellspacing='0'>"
        if rows:
            html += "<tr>"
            for val in rows[0]:
                html += f"<th>{val}</th>"
            html += "</tr>"
        for row in rows[1:]:
            html += "<tr>"
            for val in row:
                html += f"<td>{val}</td>"
            html += "</tr>"
        html += "</table></body></html>"
        dst = os.path.join(os.path.expanduser("~"), "Desktop", "EPR_Export.doc")
        try:
            with open(dst, "w", encoding="utf-8") as f:
                f.write(html)
            self._addlog(f"Exported {len(rows)-1} data rows to {dst}")
        except Exception as e:
            self._addlog(f"Export failed: {e}")

    def _ondone(self, ok, msg):
        self.go.setEnabled(True)
        self.stp.setEnabled(False)
        self._addlog(f"{'OK' if ok else 'FAILED'}: {msg}")
        self.status.setText(msg)
        self.status.setStyleSheet(f"color:{'#1b5e20' if ok else '#b71c1c'};font-size:10px;font-weight:bold;")
        self.state_lbl.setText("")
        self._ov_state.setText("Complete!" if ok else "Failed")
        self._ov_state.setStyleSheet(
            f"color:{'#66bb6a' if ok else '#ef5350'}; font-size:22px; font-weight:bold; background:transparent;")
        self._ov_detail.setText(msg)
        sys_type = getattr(self, '_detected_system', self._system)
        # Release the embedded window back to desktop
        self._release_window()
        self.automation_done.emit(ok, msg, sys_type)

    def closeEvent(self, e):
        if self.worker and self.worker.isRunning():
            self.worker.stop()
            self.worker.wait(2000)
        self._release_window()
        e.accept()
