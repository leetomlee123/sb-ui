#include "splash_window.h"

#include <dwmapi.h>
#include "resource.h"

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

namespace {

HWND g_splash_hwnd = nullptr;
constexpr const wchar_t kSplashClassName[] = L"SINGULAR_SPLASH_WINDOW";

LRESULT CALLBACK SplashWndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  switch (msg) {
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint(hwnd, &ps);
      RECT rc;
      GetClientRect(hwnd, &rc);

      // Dark sleek card background #0F172A (slate-900)
      HBRUSH bg_brush = CreateSolidBrush(RGB(15, 23, 42));
      FillRect(hdc, &rc, bg_brush);
      DeleteObject(bg_brush);

      // Subtle modern border #334155 (slate-700)
      HPEN border_pen = CreatePen(PS_SOLID, 1, RGB(51, 65, 85));
      HPEN old_pen = (HPEN)SelectObject(hdc, border_pen);
      HBRUSH null_brush = (HBRUSH)GetStockObject(NULL_BRUSH);
      HBRUSH old_brush = (HBRUSH)SelectObject(hdc, null_brush);
      Rectangle(hdc, rc.left, rc.top, rc.right, rc.bottom);
      SelectObject(hdc, old_brush);
      SelectObject(hdc, old_pen);
      DeleteObject(border_pen);

      // Center app icon (64x64)
      int width = rc.right - rc.left;
      HICON icon = (HICON)LoadImageW(
          GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON),
          IMAGE_ICON, 64, 64, LR_DEFAULTCOLOR);
      if (icon != nullptr) {
        DrawIconEx(hdc, (width - 64) / 2, 45, icon, 64, 64, 0, nullptr, DI_NORMAL);
        DestroyIcon(icon);
      }

      // App title "Singular"
      SetBkMode(hdc, TRANSPARENT);
      SetTextColor(hdc, RGB(241, 245, 249)); // #F1F5F9 (slate-100)
      HFONT font = CreateFontW(
          22, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
          DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
          CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
      HFONT old_font = (HFONT)SelectObject(hdc, font);
      RECT rc_title = {0, 125, width, 160};
      DrawTextW(hdc, L"Singular", -1, &rc_title, DT_CENTER | DT_SINGLELINE | DT_VCENTER);
      SelectObject(hdc, old_font);
      DeleteObject(font);

      // Subtitle "Starting..."
      HFONT sub_font = CreateFontW(
          13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
          DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
          CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
      HFONT old_sub = (HFONT)SelectObject(hdc, sub_font);
      SetTextColor(hdc, RGB(148, 163, 184)); // #94A3B8 (slate-400)
      RECT rc_sub = {0, 165, width, 195};
      DrawTextW(hdc, L"Starting...", -1, &rc_sub, DT_CENTER | DT_SINGLELINE | DT_VCENTER);
      SelectObject(hdc, old_sub);
      DeleteObject(sub_font);

      EndPaint(hwnd, &ps);
      return 0;
    }
    case WM_DESTROY:
      g_splash_hwnd = nullptr;
      return 0;
    default:
      return DefWindowProcW(hwnd, msg, wparam, lparam);
  }
}

}  // namespace

void ShowNativeSplash(HINSTANCE instance) {
  if (g_splash_hwnd != nullptr) return;

  WNDCLASSEXW wc = {sizeof(WNDCLASSEXW)};
  wc.lpfnWndProc = SplashWndProc;
  wc.hInstance = instance;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = nullptr;
  wc.lpszClassName = kSplashClassName;
  RegisterClassExW(&wc);

  int splash_w = 320;
  int splash_h = 230;
  int screen_w = GetSystemMetrics(SM_CXSCREEN);
  int screen_h = GetSystemMetrics(SM_CYSCREEN);
  int x = (screen_w - splash_w) / 2;
  int y = (screen_h - splash_h) / 2;

  g_splash_hwnd = CreateWindowExW(
      WS_EX_TOOLWINDOW,
      kSplashClassName,
      L"Singular",
      WS_POPUP | WS_VISIBLE,
      x, y, splash_w, splash_h,
      nullptr, nullptr, instance, nullptr);

  if (g_splash_hwnd != nullptr) {
    // Windows 11 rounded corners
    DWM_WINDOW_CORNER_PREFERENCE corner = (DWM_WINDOW_CORNER_PREFERENCE)DWMWCP_ROUND;
    DwmSetWindowAttribute(g_splash_hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));

    // Dark mode
    BOOL dark = TRUE;
    DwmSetWindowAttribute(g_splash_hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));

    ShowWindow(g_splash_hwnd, SW_SHOW);
    UpdateWindow(g_splash_hwnd);
  }
}

void CloseNativeSplash() {
  if (g_splash_hwnd != nullptr) {
    HWND hwnd = g_splash_hwnd;
    g_splash_hwnd = nullptr;
    DestroyWindow(hwnd);
    UnregisterClassW(kSplashClassName, GetModuleHandleW(nullptr));
  }
}
