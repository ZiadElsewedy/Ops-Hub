import 'package:flutter/services.dart';
import 'package:opshub/core/utils/app_logger.dart';

/// Clears already-delivered chat notifications from the OS surface (iOS
/// Notification Center / Android status bar) so opening a conversation removes
/// exactly *its* notifications — WhatsApp-style — while other conversations'
/// notifications stay put.
///
/// **Why native.** `firebase_messaging` exposes no way to enumerate or remove
/// delivered notifications, so this bridges to a tiny platform channel
/// (`drop/notifications`): iOS `UNUserNotificationCenter`, Android
/// `NotificationManager`. Each matches on the per-conversation grouping the chat
/// push already stamps — the APNs `thread-id` and the Android notification `tag`,
/// both set to the conversation id by the backend (`chat-push.subscriber`), so
/// no per-message id bookkeeping is needed on the client.
///
/// **Best-effort and silent.** On a platform without the channel (macOS, and
/// unit tests with no mock handler) the call is a no-op — a `MissingPlugin
/// Exception` is swallowed, so this needs no `dart:io` platform gate and stays
/// unit-testable. Any other failure is logged, never thrown: a notification that
/// lingers is a cosmetic annoyance, not a reason to fail a read.
class DeliveredNotifications {
  DeliveredNotifications([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('drop/notifications');

  final MethodChannel _channel;

  /// Removes every delivered notification for [conversationId]. Idempotent —
  /// clearing a conversation with nothing delivered does nothing.
  Future<void> clearConversation(String conversationId) => _invoke(
        'clearConversation',
        {'conversationId': conversationId},
      );

  /// Removes all delivered notifications — used on sign-out so the next account
  /// on a shared device never inherits the previous user's banners.
  Future<void> clearAll() => _invoke('clearAll');

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // No native channel on this platform (desktop/tests) — nothing to clear.
    } catch (e) {
      AppLog.warning('fcm', 'notifications $method failed: $e');
    }
  }
}
