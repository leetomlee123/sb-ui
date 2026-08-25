#include "flutter_window.h"

#include <chrono>
#include <optional>

#include <desktop_updater/desktop_updater_plugin_c_api.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <tray_manager/tray_manager_plugin.h>
#include <window_manager/window_manager_plugin.h>

#include "flutter/generated_plugin_registrant.h"
#include "tun_process_bridge.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  const auto t_win_start = std::chrono::high_resolution_clock::now();
  if (!Win32Window::OnCreate()) {
    return false;
  }
  const auto t_win_end = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.window_create_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(t_win_end - t_win_start).count();

  RECT frame = GetClientArea();

  const auto t_engine_start = std::chrono::high_resolution_clock::now();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  const auto t_engine_end = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.engine_init_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(t_engine_end - t_engine_start).count();

  const auto t_plugins_start = std::chrono::high_resolution_clock::now();
  auto registry = flutter_controller_->engine();

  const auto p0 = std::chrono::high_resolution_clock::now();
  DesktopUpdaterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DesktopUpdaterPluginCApi"));
  const auto p1 = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.desktop_updater_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(p1 - p0).count();

  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  const auto p2 = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.screen_retriever_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(p2 - p1).count();

  TrayManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("TrayManagerPlugin"));
  const auto p3 = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.tray_manager_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(p3 - p2).count();

  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  const auto p4 = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.window_manager_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(p4 - p3).count();

  TunProcessBridge::RegisterWithMessenger(flutter_controller_->engine()->messenger());
  const auto p5 = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.tun_bridge_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(p5 - p4).count();

  g_native_startup_timings.plugins_total_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(p5 - t_plugins_start).count();

  const auto t_child_start = std::chrono::high_resolution_clock::now();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();
  const auto t_child_end = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.child_content_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(t_child_end - t_child_start).count();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
