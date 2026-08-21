import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/chat/domain/chat_realtime.dart';
import 'package:opshub/features/chat/presentation/chat_conversation_presence.dart';

class _FakeRealtime implements ChatRealtime {
  final joined = <String>[];
  final left = <String>[];
  bool connected = true;

  @override
  Stream<ChatRealtimeEvent> get events => const Stream.empty();

  @override
  Future<bool> joinConversation(String conversationId) async {
    if (connected) joined.add(conversationId);
    return connected;
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    if (connected) left.add(conversationId);
  }

  @override
  Future<void> attachInbox() async {}

  @override
  Future<void> detachInbox() async {}

  @override
  Future<void> onAppResumed() async {}
}

void main() {
  test('background clears active thread and resume joins it again', () async {
    final realtime = _FakeRealtime();
    final active = ValueNotifier<String?>(null);
    final presence = ChatConversationPresence(
      conversationId: 'conversation-1',
      realtime: realtime,
      activeConversation: active,
    );

    presence.show();
    await Future<void>.microtask(() {});
    expect(active.value, 'conversation-1');
    expect(realtime.joined, ['conversation-1']);

    presence.onLifecycleChanged(AppLifecycleState.paused);
    await Future<void>.microtask(() {});
    expect(active.value, isNull);
    expect(realtime.left, ['conversation-1']);

    presence.onLifecycleChanged(AppLifecycleState.resumed);
    await Future<void>.microtask(() {});
    expect(active.value, 'conversation-1');
    expect(realtime.joined, ['conversation-1', 'conversation-1']);
  });

  test(
    'inactive, detached, no open thread and disconnected socket are safe',
    () async {
      final realtime = _FakeRealtime()..connected = false;
      final active = ValueNotifier<String?>('other-thread');
      final presence = ChatConversationPresence(
        conversationId: 'conversation-1',
        realtime: realtime,
        activeConversation: active,
      );

      presence.onLifecycleChanged(AppLifecycleState.inactive);
      presence.onLifecycleChanged(AppLifecycleState.hidden);
      presence.onLifecycleChanged(AppLifecycleState.detached);
      await Future<void>.microtask(() {});
      expect(active.value, 'other-thread');
      expect(realtime.left, isEmpty);
      expect(realtime.joined, isEmpty);
    },
  );
}
