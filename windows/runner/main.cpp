#include <chrono>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "splash_window.h"
#include "tun_process_bridge.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const auto t0 = std::chrono::high_resolution_clock::now();
  const auto native_start_time = std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::system_clock::now().time_since_epoch()).count();
  g_native_startup_timings.native_start_epoch_ms = native_start_time;

  // Attach to console when present (e.g., 'flutter run' or PowerShell/cmd launch)
  // or create a new console when running with a debugger.
  if (::AttachConsole(ATTACH_PARENT_PROCESS)) {
    // Only redirect standard streams to CONOUT$ if not already redirected to a pipe/file.
    DWORD stdout_type = ::GetFileType(::GetStdHandle(STD_OUTPUT_HANDLE));
    if (stdout_type != FILE_TYPE_PIPE && stdout_type != FILE_TYPE_DISK) {
      FILE *unused;
      freopen_s(&unused, "CONOUT$", "w", stdout);
    }
    DWORD stderr_type = ::GetFileType(::GetStdHandle(STD_ERROR_HANDLE));
    if (stderr_type != FILE_TYPE_PIPE && stderr_type != FILE_TYPE_DISK) {
      FILE *unused;
      freopen_s(&unused, "CONOUT$", "w", stderr);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  } else if (::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const auto t1 = std::chrono::high_resolution_clock::now();
  g_native_startup_timings.com_init_ms =
      std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();

  // Show native splash card immediately (0-3ms) unless launched minimized
  std::wstring cmd_str(command_line ? command_line : L"");
  bool is_minimized = (show_command == SW_HIDE || show_command == SW_MINIMIZE ||
                       show_command == SW_SHOWMINNOACTIVE ||
                       cmd_str.find(L"--minimized") != std::wstring::npos ||
                       cmd_str.find(L"-m") != std::wstring::npos);
  if (!is_minimized) {
    ShowNativeSplash(instance);
  }

  flutter::DartProject project(L"data");

  // Force Skia rendering engine by default instead of Impeller (OpenGLESSDF).
  // In Flutter 3.47+, Impeller on Windows causes 1.5s~3s upfront shader compilation latency.
  // Skia provides instant cold start (~50-100ms engine init) and rock-solid stability.
  bool enable_impeller = (cmd_str.find(L"--enable-impeller") != std::wstring::npos);
  project.set_impeller_switch(enable_impeller ? flutter::ImpellerSwitch::Enabled
                                              : flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  command_line_arguments.push_back("--native-start-epoch-ms=" + std::to_string(native_start_time));

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Center window on primary display initially (1020x680)
  int screen_width = ::GetSystemMetrics(SM_CXSCREEN);
  int screen_height = ::GetSystemMetrics(SM_CYSCREEN);
  int origin_x = (screen_width - 1020) / 2;
  int origin_y = (screen_height - 680) / 2;
  if (origin_x < 0) origin_x = 10;
  if (origin_y < 0) origin_y = 10;
  Win32Window::Point origin(origin_x, origin_y);
  // Matches WindowOptions in lib/main.dart so the Dart side does not resize
  // the window right after the first frame.
  Win32Window::Size size(1020, 680);
  if (!window.Create(L"Singular", origin, size)) {
    CloseNativeSplash();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
