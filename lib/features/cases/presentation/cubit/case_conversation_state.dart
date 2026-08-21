import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';

part 'case_conversation_state.freezed.dart';

@freezed
class CaseConversationState with _$CaseConversationState {
  /// Waiting for the first case-doc snapshot.
  const factory CaseConversationState.loading() = _Loading;

  /// The case + its conversation. [sending] marks an in-flight reply; [changingStatus]
  /// an in-flight status transition. Both keep the thread on screen.
  const factory CaseConversationState.loaded(
    CaseEntity caseItem,
    List<CaseMessage> messages, {
    @Default(false) bool sending,
    @Default(false) bool changingStatus,
  }) = _Loaded;

  /// The case doc doesn't exist / isn't readable (deleted, or a bad deep-link).
  const factory CaseConversationState.unavailable() = _Unavailable;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] state so the UI never loses the conversation.
  const factory CaseConversationState.error(String message) = _Error;
}
