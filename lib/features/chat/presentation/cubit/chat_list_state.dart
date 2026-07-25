import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';

part 'chat_list_state.freezed.dart';

@freezed
class ChatListState with _$ChatListState {
  const factory ChatListState.initial() = _Initial;

  /// First load (full-screen spinner).
  const factory ChatListState.loading() = _Loading;

  /// Conversations loaded, most-recent-activity first. An **empty** list is the
  /// empty state — the UI renders its "no conversations yet" treatment off it.
  ///
  /// [refreshing] marks an in-flight pull-to-refresh (list stays visible).
  /// [loadingMore] marks an in-flight older page (bottom spinner row).
  /// [hasMore] is whether another page exists (drives the load-more affordance).
  /// [starting] marks an in-flight start-conversation (busy overlay analog).
  ///
  /// [previews] and [unreadCounts] are **live, socket-derived enrichment**
  /// keyed by conversation id — the list endpoint itself carries neither, so
  /// both start empty and fill in as `message:new` events arrive (and clear
  /// for a conversation when the user opens it). Absent key → the tile's
  /// honest fallback.
  const factory ChatListState.loaded(
    List<ChatConversationSummary> conversations, {
    @Default(false) bool refreshing,
    @Default(false) bool loadingMore,
    @Default(false) bool hasMore,
    @Default(false) bool starting,
    @Default(<String, String>{}) Map<String, String> previews,
    @Default(<String, int>{}) Map<String, int> unreadCounts,
  }) = _Loaded;

  /// Terminal only when there is no data to show (first load failed —
  /// full-screen retry). With data present it is transient — surfaced as a
  /// snackbar; the cubit immediately re-emits the last-known [loaded] list so
  /// the UI never loses its data (Cases convention).
  const factory ChatListState.error(String message) = _Error;
}
