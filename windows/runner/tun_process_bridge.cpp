#include "tun_process_bridge.h"

#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <string>
#include <sstream>

NativeStartupTimings g_native_startup_timings;

namespace {

static HANDLE g_elevatedProcessHandle = NULL;
static DWORD g_elevatedPid = 0;

std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
  return wstrTo;
}

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

bool CheckIfCurrentProcessElevated() {
  bool isElevated = false;
  HANDLE hToken = NULL;
  if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken)) {
    TOKEN_ELEVATION elevation;
    DWORD cbSize = sizeof(TOKEN_ELEVATION);
    if (GetTokenInformation(hToken, TokenElevation, &elevation, sizeof(elevation), &cbSize)) {
      isElevated = elevation.TokenIsElevated != 0;
    }
    CloseHandle(hToken);
  }
  return isElevated;
}

bool CheckProcessAlive(HANDLE hProcess) {
  if (hProcess == NULL) return false;
  DWORD exitCode = 0;
  if (GetExitCodeProcess(hProcess, &exitCode)) {
    return exitCode == STILL_ACTIVE;
  }
  return false;
}

void KillProcessTree(DWORD pid) {
  HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (hSnapshot != INVALID_HANDLE_VALUE) {
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    if (Process32First(hSnapshot, &pe)) {
      do {
        if (pe.th32ParentProcessID == pid) {
          KillProcessTree(pe.th32ProcessID);
        }
      } while (Process32Next(hSnapshot, &pe));
    }
    CloseHandle(hSnapshot);
  }

  HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
  if (hProc != NULL) {
    TerminateProcess(hProc, 0);
    CloseHandle(hProc);
  }
}

void KillSingBoxByImageName() {
  HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (hSnapshot != INVALID_HANDLE_VALUE) {
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    if (Process32First(hSnapshot, &pe)) {
      do {
        if (_wcsicmp(pe.szExeFile, L"sing-box.exe") == 0 || _wcsicmp(pe.szExeFile, L"sing-box") == 0) {
          HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
          if (hProc != NULL) {
            TerminateProcess(hProc, 0);
            CloseHandle(hProc);
          }
        }
      } while (Process32Next(hSnapshot, &pe));
    }
    CloseHandle(hSnapshot);
  }
}

}  // namespace

void TunProcessBridge::RegisterWithMessenger(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.example.sb_ui/tun_process",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

void TunProcessBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "isCurrentProcessElevated") {
    bool elevated = CheckIfCurrentProcessElevated();
    result->Success(flutter::EncodableValue(elevated));
    return;
  }

  if (method == "startSingBoxAsAdmin") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGUMENTS", "Expected map arguments");
      return;
    }

    std::string binaryPath;
    std::string configPath;
    std::string workingDir;

    auto itBinary = args->find(flutter::EncodableValue("binaryPath"));
    if (itBinary != args->end() && std::holds_alternative<std::string>(itBinary->second)) {
      binaryPath = std::get<std::string>(itBinary->second);
    }

    auto itConfig = args->find(flutter::EncodableValue("configPath"));
    if (itConfig != args->end() && std::holds_alternative<std::string>(itConfig->second)) {
      configPath = std::get<std::string>(itConfig->second);
    }

    auto itDir = args->find(flutter::EncodableValue("workingDir"));
    if (itDir != args->end() && std::holds_alternative<std::string>(itDir->second)) {
      workingDir = std::get<std::string>(itDir->second);
    }

    if (binaryPath.empty() || configPath.empty()) {
      result->Error("INVALID_ARGUMENTS", "binaryPath and configPath are required");
      return;
    }

    std::wstring wBinary = Utf8ToWide(binaryPath);
    std::wstring wConfig = Utf8ToWide(configPath);
    std::wstring wWorkingDir = Utf8ToWide(workingDir);

    // Verify binary existence
    DWORD binaryAttr = GetFileAttributesW(wBinary.c_str());
    if (binaryAttr == INVALID_FILE_ATTRIBUTES) {
      flutter::EncodableMap response;
      response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
      response[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(false);
      response[flutter::EncodableValue("errorCode")] = flutter::EncodableValue((int64_t)ERROR_FILE_NOT_FOUND);
      response[flutter::EncodableValue("error")] = flutter::EncodableValue("FILE_NOT_FOUND");
      response[flutter::EncodableValue("message")] = flutter::EncodableValue("未找到 sing-box 可执行文件: " + binaryPath);
      result->Success(flutter::EncodableValue(response));
      return;
    }

    // Verify config existence
    DWORD configAttr = GetFileAttributesW(wConfig.c_str());
    if (configAttr == INVALID_FILE_ATTRIBUTES) {
      flutter::EncodableMap response;
      response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
      response[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(false);
      response[flutter::EncodableValue("errorCode")] = flutter::EncodableValue((int64_t)ERROR_FILE_NOT_FOUND);
      response[flutter::EncodableValue("error")] = flutter::EncodableValue("CONFIG_NOT_FOUND");
      response[flutter::EncodableValue("message")] = flutter::EncodableValue("未找到配置文件: " + configPath);
      result->Success(flutter::EncodableValue(response));
      return;
    }

    // If an elevated instance was already recorded, stop it first
    if (g_elevatedProcessHandle != NULL) {
      if (CheckProcessAlive(g_elevatedProcessHandle)) {
        TerminateProcess(g_elevatedProcessHandle, 0);
      }
      CloseHandle(g_elevatedProcessHandle);
      g_elevatedProcessHandle = NULL;
      g_elevatedPid = 0;
    }

    // Prepare ShellExecuteExW with lpVerb = L"runas" for UAC prompt
    std::wstring params = L"run -c \"" + wConfig + L"\"";

    SHELLEXECUTEINFOW sei = { sizeof(sei) };
    sei.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI;
    sei.lpVerb = L"runas";  // Request Administrator UAC elevation
    sei.lpFile = wBinary.c_str();
    sei.lpParameters = params.c_str();
    sei.lpDirectory = wWorkingDir.empty() ? NULL : wWorkingDir.c_str();
    sei.nShow = SW_HIDE;  // Hidden window for background daemon execution

    BOOL success = ShellExecuteExW(&sei);

    if (success && sei.hProcess != NULL) {
      g_elevatedProcessHandle = sei.hProcess;
      g_elevatedPid = GetProcessId(sei.hProcess);

      flutter::EncodableMap response;
      response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
      response[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(false);
      response[flutter::EncodableValue("pid")] = flutter::EncodableValue((int64_t)g_elevatedPid);
      response[flutter::EncodableValue("message")] = flutter::EncodableValue("sing-box 管理员权限启动成功");
      result->Success(flutter::EncodableValue(response));
      return;
    }

    DWORD err = GetLastError();
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
    response[flutter::EncodableValue("errorCode")] = flutter::EncodableValue((int64_t)err);

    if (err == ERROR_CANCELLED) {
      // User clicked "No" or closed UAC modal
      response[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(true);
      response[flutter::EncodableValue("error")] = flutter::EncodableValue("UAC_CANCELLED");
      response[flutter::EncodableValue("message")] = flutter::EncodableValue("TUN 开启失败：用户取消了管理员授权 (UAC)");
    } else {
      response[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(false);
      response[flutter::EncodableValue("error")] = flutter::EncodableValue("START_FAILED");
      response[flutter::EncodableValue("message")] = flutter::EncodableValue("启动失败，Windows 错误代码: " + std::to_string(err));
    }

    result->Success(flutter::EncodableValue(response));
    return;
  }

  if (method == "stopSingBox") {
    if (g_elevatedProcessHandle != NULL) {
      if (CheckProcessAlive(g_elevatedProcessHandle)) {
        TerminateProcess(g_elevatedProcessHandle, 0);
      }
      CloseHandle(g_elevatedProcessHandle);
      g_elevatedProcessHandle = NULL;
    }
    if (g_elevatedPid != 0) {
      KillProcessTree(g_elevatedPid);
      g_elevatedPid = 0;
    }

    // Safety cleanup of orphan sing-box.exe instances
    KillSingBoxByImageName();

    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    result->Success(flutter::EncodableValue(response));
    return;
  }

  if (method == "isSingBoxRunning") {
    bool running = false;
    DWORD exitCode = 0;
    if (g_elevatedProcessHandle != NULL) {
      if (GetExitCodeProcess(g_elevatedProcessHandle, &exitCode)) {
        running = (exitCode == STILL_ACTIVE);
      }
    }

    flutter::EncodableMap response;
    response[flutter::EncodableValue("running")] = flutter::EncodableValue(running);
    response[flutter::EncodableValue("pid")] = flutter::EncodableValue((int64_t)g_elevatedPid);
    response[flutter::EncodableValue("exitCode")] = flutter::EncodableValue((int64_t)exitCode);
    result->Success(flutter::EncodableValue(response));
    return;
  }

  if (method == "getNativeStartupTimings") {
    flutter::EncodableMap response;
    response[flutter::EncodableValue("nativeStartEpochMs")] = flutter::EncodableValue(g_native_startup_timings.native_start_epoch_ms);
    response[flutter::EncodableValue("comInitMs")] = flutter::EncodableValue(g_native_startup_timings.com_init_ms);
    response[flutter::EncodableValue("windowCreateMs")] = flutter::EncodableValue(g_native_startup_timings.window_create_ms);
    response[flutter::EncodableValue("engineInitMs")] = flutter::EncodableValue(g_native_startup_timings.engine_init_ms);
    response[flutter::EncodableValue("pluginsTotalMs")] = flutter::EncodableValue(g_native_startup_timings.plugins_total_ms);
    response[flutter::EncodableValue("desktopUpdaterMs")] = flutter::EncodableValue(g_native_startup_timings.desktop_updater_ms);
    response[flutter::EncodableValue("screenRetrieverMs")] = flutter::EncodableValue(g_native_startup_timings.screen_retriever_ms);
    response[flutter::EncodableValue("trayManagerMs")] = flutter::EncodableValue(g_native_startup_timings.tray_manager_ms);
    response[flutter::EncodableValue("windowManagerMs")] = flutter::EncodableValue(g_native_startup_timings.window_manager_ms);
    response[flutter::EncodableValue("tunBridgeMs")] = flutter::EncodableValue(g_native_startup_timings.tun_bridge_ms);
    response[flutter::EncodableValue("childContentMs")] = flutter::EncodableValue(g_native_startup_timings.child_content_ms);
    result->Success(flutter::EncodableValue(response));
    return;
  }

  result->NotImplemented();
}
