import Flutter
import UIKit
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "sw1.local_ai/resources",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "checkNativeRuntime" {
          let process = dlopen(nil, RTLD_NOW)
          let available = process.flatMap {
            dlsym($0, "llama_model_load_from_file")
          } != nil
          result(available)
          return
        }
        guard call.method == "read" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let values = try? FileManager.default.attributesOfFileSystem(
          forPath: NSHomeDirectory()
        )
        let free = (values?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        result([
          "architecture": "ios-arm64",
          "ramBytes": Int64(ProcessInfo.processInfo.physicalMemory),
          "freeStorageBytes": free,
        ])
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
