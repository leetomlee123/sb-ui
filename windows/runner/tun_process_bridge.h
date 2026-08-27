#ifndef RUNNER_TUN_PROCESS_BRIDGE_H_
#define RUNNER_TUN_PROCESS_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>

struct NativeStartupTimings {
  int64_t native_start_epoch_ms = 0;
  int64_t com_init_ms = 0;
  int64_t window_create_ms = 0;
  int64_t engine_init_ms = 0;
  int64_t plugins_total_ms = 0;
  int64_t desktop_updater_ms = 0;
  int64_t tray_manager_ms = 0;
  int64_t window_manager_ms = 0;
  int64_t tun_bridge_ms = 0;
  int64_t child_content_ms = 0;
};

extern NativeStartupTimings g_native_startup_timings;

class TunProcessBridge {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger);

 private:
  static void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // RUNNER_TUN_PROCESS_BRIDGE_H_
