import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/services/delivered_notifications.dart';

/// Pins the platform-channel contract for clearing delivered OS notifications
/// (the WhatsApp-style "open the chat → its notifications disappear" behaviour).
/// The native handlers live in the iOS/Android runners and are device-verified;
/// here we prove the Dart side sends the right method + args and never throws
/// when no native channel is present (desktop / tests).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('drop/notifications');
  final calls = <MethodCall>[];

  void handleWith(Future<Object?>? Function(MethodCall)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  setUp(() {
    calls.clear();
    handleWith((call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => handleWith(null));

  test('clearConversation sends the conversation id to the channel', () async {
    await DeliveredNotifications().clearConversation('conv-1');
    expect(calls.single.method, 'clearConversation');
    expect(calls.single.arguments, {'conversationId': 'conv-1'});
  });

  test('clearAll invokes the channel with no args', () async {
    await DeliveredNotifications().clearAll();
    expect(calls.single.method, 'clearAll');
    expect(calls.single.arguments, isNull);
  });

  test('a missing native channel is swallowed, not thrown', () async {
    handleWith(null); // no handler → MissingPluginException
    await DeliveredNotifications().clearConversation('conv-1');
    expect(calls, isEmpty);
  });
}
