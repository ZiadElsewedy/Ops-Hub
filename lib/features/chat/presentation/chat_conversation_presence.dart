import 'package:flutter/widgets.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';

/// Keeps the server's conversation-room membership aligned with whether this
/// thread is actually visible to the user. The room controls server-side chat
/// push suppression, so it must not survive the app leaving the foreground.
class ChatConversationPresence {
  ChatConversationPresence({
    required this.conversationId,
    required this._realtime,
    required this._activeConversation,
  });

  final String conversationId;
  final ChatRealtime _realtime;
  final ValueNotifier<String?> _activeConversation;
  bool _visible = false;

  void show() {
    if (_visible) return;
    _visible = true;
    _activeConversation.value = conversationId;
    _realtime.joinConversation(conversationId);
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    if (_activeConversation.value == conversationId) {
      _activeConversation.value = null;
    }
    _realtime.leaveConversation(conversationId);
  }

  void onLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        show();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        hide();
    }
  }

  void dispose() => hide();
}
