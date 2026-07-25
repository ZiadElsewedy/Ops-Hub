import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';

part 'chat_conversation_state.freezed.dart';

@freezed
class ChatConversationState with _$ChatConversationState {
  /// Waiting for the conversation + first history page.
  const factory ChatConversationState.loading() = _Loading;

  /// The open thread. [messages] are ascending by `seq` (oldest first — render
  /// bottom-anchored). [myUserId] is the caller's **backend-internal** user id
  /// when derivable (from the counterpart, or from the first sent message);
  /// null means own-message alignment isn't resolvable yet — see the identity
  /// note on the cubit.
  ///
  /// [sending] marks an in-flight send (composer busy). [loadingOlder] marks an
  /// in-flight older page (top spinner row). [hasMore] is whether older history
  /// exists (drives the scroll-back load trigger). [deletingMessageId] is the
  /// message with a delete in flight (its bubble dims; one at a time).
  const factory ChatConversationState.loaded(
    ChatConversation conversation,
    List<ChatMessage> messages, {
    String? myUserId,
    @Default(false) bool sending,
    @Default(false) bool loadingOlder,
    @Default(false) bool hasMore,
    String? deletingMessageId,
  }) = _Loaded;

  /// Terminal only when the initial load failed (full-screen retry via
  /// `load()`). After data has arrived it is transient — surfaced as a
  /// snackbar; the cubit immediately re-emits the last-known [loaded] state so
  /// the UI never loses the thread (Cases convention).
  const factory ChatConversationState.error(String message) = _Error;
}
