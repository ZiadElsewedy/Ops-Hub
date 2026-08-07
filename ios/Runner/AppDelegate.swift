import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Bridge for clearing delivered chat notifications (WhatsApp-style) when a
    // conversation is opened + read. The chat push stamps each message with
    // `aps.thread-id = conversationId`, which iOS surfaces as the delivered
    // notification's `threadIdentifier`, so a conversation's notifications can
    // be removed as a group without tracking individual notification ids.
    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "DropNotifications")?.messenger()
    {
      let channel = FlutterMethodChannel(
        name: "drop/notifications", binaryMessenger: messenger)
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "clearConversation":
          guard
            let args = call.arguments as? [String: Any],
            let conversationId = args["conversationId"] as? String, !conversationId.isEmpty
          else {
            result(
              FlutterError(
                code: "bad_args", message: "conversationId required", details: nil))
            return
          }
          Self.clearDelivered(threadId: conversationId, result: result)
        case "clearAll":
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// Removes every delivered notification whose `threadIdentifier` matches
  /// [threadId] (the conversation id). `getDeliveredNotifications` completes on a
  /// background queue, so the Flutter reply is dispatched back to the main queue.
  private static func clearDelivered(
    threadId: String, result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { delivered in
      let ids =
        delivered
        .filter { $0.request.content.threadIdentifier == threadId }
        .map { $0.request.identifier }
      if !ids.isEmpty {
        center.removeDeliveredNotifications(withIdentifiers: ids)
      }
      DispatchQueue.main.async { result(nil) }
    }
  }
}
