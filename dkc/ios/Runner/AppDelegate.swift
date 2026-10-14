import Flutter
import UIKit
import flutter_background_service_ios

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "dev.flutter.background.refresh"
    excludeAppDataFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Keeps the evidence databases, files and preferences out of iCloud and
  /// computer backups. Keychain items are "this device only" (see secure_store.dart).
  private func excludeAppDataFromBackup() {
    for directory in [FileManager.SearchPathDirectory.documentDirectory, .libraryDirectory] {
      guard var url = FileManager.default.urls(for: directory, in: .userDomainMask).first else { continue }
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? url.setResourceValues(values)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
