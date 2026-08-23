#ifndef RUNNER_TUN_PROCESS_BRIDGE_H_
#define RUNNER_TUN_PROCESS_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>

class TunProcessBridge {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger);

 private:
  static void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // RUNNER_TUN_PROCESS_BRIDGE_H_
