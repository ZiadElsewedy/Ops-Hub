import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:drop/core/media/media_upload_service.dart';
import 'package:drop/core/network/api_client.dart';
import 'package:drop/core/network/network_config.dart';
import 'package:drop/core/services/case_seen_store.dart';
import 'package:drop/core/services/chat_cleared_store.dart';
import 'package:drop/core/services/notification_preferences_store.dart';
import 'package:drop/core/services/delivered_notifications.dart';
import 'package:drop/core/services/notification_service.dart';
import 'package:drop/core/services/session_store.dart';
import 'package:drop/core/services/task_seen_store.dart';
import 'package:drop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:drop/features/auth/data/datasources/user_remote_datasource.dart';
import 'package:drop/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:drop/features/auth/domain/usecases/sign_out.dart';
import 'package:drop/features/auth/domain/usecases/get_user.dart';
import 'package:drop/features/auth/domain/usecases/forgot_password.dart';
import 'package:drop/features/auth/domain/usecases/change_password.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:drop/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:drop/features/profile/domain/repositories/profile_repository.dart';
import 'package:drop/features/profile/domain/usecases/get_profile.dart';
import 'package:drop/features/profile/domain/usecases/update_profile.dart';
import 'package:drop/features/profile/domain/usecases/upload_profile_image.dart';
import 'package:drop/features/profile/domain/usecases/upload_cover_image.dart';
import 'package:drop/features/profile/domain/usecases/check_username.dart';
import 'package:drop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/task/data/datasources/task_remote_datasource.dart';
import 'package:drop/features/task/data/repositories/task_repository_impl.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/resolve_task_reviewers.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/branch/data/datasources/branch_remote_datasource.dart';
import 'package:drop/features/branch/data/repositories/branch_repository_impl.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/sales/data/datasources/sales_remote_datasource.dart';
import 'package:drop/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/usecases/submit_daily_sales.dart';
import 'package:drop/features/sales/domain/usecases/record_daily_sales.dart';
import 'package:drop/features/sales/domain/usecases/set_branch_monthly_target.dart';
import 'package:drop/features/sales/domain/usecases/approve_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/reject_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/request_sales_correction.dart';
import 'package:drop/features/sales/domain/usecases/resubmit_corrected_sales.dart';
import 'package:drop/features/sales/domain/usecases/edit_approved_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/reopen_sales_submission.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_submission_detail_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';
import 'package:drop/features/admin/data/datasources/user_admin_remote_datasource.dart';
import 'package:drop/features/admin/data/repositories/user_admin_repository_impl.dart';
import 'package:drop/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:drop/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:drop/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:drop/features/statistics/data/repositories/statistics_repository_impl.dart';
import 'package:drop/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/schedule/data/datasources/schedule_remote_datasource.dart';
import 'package:drop/features/schedule/data/datasources/shift_template_remote_datasource.dart';
import 'package:drop/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:drop/features/schedule/data/repositories/shift_template_repository_impl.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/today_coverage_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_template_cubit.dart';
import 'package:drop/features/operations/presentation/cubit/branch_operations_cubit.dart';
import 'package:drop/features/communications/data/datasources/broadcast_remote_datasource.dart';
import 'package:drop/features/communications/data/repositories/broadcast_repository_impl.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_repository.dart';
import 'package:drop/features/communications/domain/usecases/send_broadcast.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:drop/features/communications/data/datasources/broadcast_template_remote_datasource.dart';
import 'package:drop/features/communications/data/repositories/broadcast_template_repository_impl.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_template_repository.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_template_cubit.dart';
import 'package:drop/features/communications/data/datasources/broadcast_schedule_remote_datasource.dart';
import 'package:drop/features/communications/data/repositories/broadcast_schedule_repository_impl.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_schedule_repository.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_schedule_cubit.dart';
import 'package:drop/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:drop/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:drop/features/notifications/domain/usecases/notify_swap_event.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/cases/data/datasources/case_remote_datasource.dart';
import 'package:drop/features/cases/data/repositories/case_repository_impl.dart';
import 'package:drop/features/cases/domain/repositories/case_repository.dart';
import 'package:drop/features/cases/domain/usecases/change_case_status.dart';
import 'package:drop/features/cases/domain/usecases/create_case.dart';
import 'package:drop/features/cases/domain/usecases/send_case_message.dart';
import 'package:drop/features/cases/domain/usecases/upload_case_attachment.dart';
import 'package:drop/features/cases/presentation/cubit/case_conversation_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:drop/features/requests/data/datasources/request_remote_datasource.dart';
import 'package:drop/features/requests/data/repositories/request_repository_impl.dart';
import 'package:drop/features/requests/domain/repositories/request_repository.dart';
import 'package:drop/features/requests/domain/usecases/add_request_comment.dart';
import 'package:drop/features/requests/domain/usecases/change_request_status.dart';
import 'package:drop/features/requests/domain/usecases/create_request.dart';
import 'package:drop/features/requests/domain/usecases/upload_request_attachment.dart';
import 'package:drop/features/requests/presentation/cubit/request_detail_cubit.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:drop/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:drop/features/attendance/data/datasources/attendance_reporting_datasource.dart';
import 'package:drop/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:drop/features/attendance/data/repositories/attendance_reporting_repository_impl.dart';
import 'package:drop/features/attendance/data/services/geolocator_location_service.dart';
import 'package:drop/features/attendance/domain/attendance_service.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_week_review_repository.dart';
import 'package:drop/features/attendance/data/repositories/attendance_week_review_repository_impl.dart';
import 'package:drop/features/attendance/domain/usecases/clock_in.dart';
import 'package:drop/features/attendance/domain/usecases/clock_out.dart';
import 'package:drop/features/attendance/domain/usecases/decide_correction.dart';
import 'package:drop/features/attendance/domain/usecases/request_correction.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:drop/features/attendance/presentation/details/attendance_details_cubit.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_cubit.dart';
import 'package:drop/features/attendance/presentation/admin/admin_attendance_overview_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/audit/data/datasources/audit_remote_datasource.dart';
import 'package:drop/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:drop/features/audit/domain/repositories/audit_repository.dart';
import 'package:drop/features/audit/domain/services/event_tracking_service.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart' show UserEntity;
import 'package:drop/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:drop/features/chat/data/local/chat_database.dart';
import 'package:drop/features/chat/data/local/chat_local_datasource.dart';
import 'package:drop/features/chat/data/realtime/chat_socket_service.dart';
import 'package:drop/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/clear_chat_for_me.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/usecases/get_chat_attachment_url.dart';
import 'package:drop/features/chat/domain/usecases/get_chat_directory.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/get_cached_conversations.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'package:drop/features/chat/presentation/chat_attachment_picker.dart';
import 'package:drop/features/chat/presentation/chat_thread_cache.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/new_chat_cubit.dart';

class AppDependencies {
  AppDependencies._();

  /// The authenticated HTTP seam for the external NestJS API (chat backend).
  /// Built in [init]; consumed by the chat feature's datasource.
  static late final ApiClient apiClient;

  /// Direct (1:1) chat — domain + data layers over the NestJS API (Phase 2).
  static late final ChatRepository chatRepository;

  /// The same instance as [chatRepository], typed — only so sign-out can drop
  /// its cached brokered URLs (a cache concern the port deliberately omits).
  static ChatRepositoryImpl? _chatRepositoryImpl;

  /// Direct chat — the realtime channel (Socket.IO). Read-only delivery; all
  /// writes stay on [chatRepository]. Lazily connected while any thread cubit
  /// has its conversation joined.
  static late final ChatRealtime chatRealtime;

  /// Direct chat — the inbox list cubit (singleton, app-wide), mirroring
  /// [caseListCubit]'s role for Cases.
  static late final ChatListCubit chatListCubit;

  /// The conversation the user is currently viewing (its id), or null. Set by
  /// the open thread screen and read by the in-app notification listener so a
  /// message for the on-screen conversation never raises a redundant banner.
  static final ValueNotifier<String?> activeChatConversation =
      ValueNotifier<String?>(null);

  // Direct chat — read/write use cases, kept so a fresh per-thread
  // [ChatConversationCubit] can be built on demand (one per opened thread).
  static late final GetConversation _getChatConversation;
  static late final DeleteChatMessageForMe _deleteChatMessageForMe;
  static late final DeleteChatMessageForEveryone _deleteChatMessageForEveryone;
  static late final LoadChatHistory _loadChatHistory;
  static late final SendChatMessage _sendChatMessage;
  static late final MarkChatRead _markChatRead;
  static late final GetChatAttachmentUrl _getChatAttachmentUrl;

  /// Builds a fresh thread cubit for [conversationId] (owned + disposed by its
  /// `BlocProvider`; re-created when the opened conversation changes).
  /// [counterpartUserId] — the other participant's backend-internal id — is
  /// passed when known (list rows carry it) so own-message alignment works
  /// before the first send.
  static ChatConversationCubit createChatConversationCubit(
    String conversationId, {
    String? counterpartUserId,
    // The screen's lifecycle observer owns join/leave once mounted, so it opts
    // out of the cubit's own room management to keep one owner of the room.
    bool manageRealtimeRoom = true,
  }) =>
      ChatConversationCubit(
        manageRealtimeRoom: manageRealtimeRoom,
        getConversation: _getChatConversation,
        loadHistory: _loadChatHistory,
        sendMessage: _sendChatMessage,
        markRead: _markChatRead,
        deleteForMe: _deleteChatMessageForMe,
        deleteForEveryone: _deleteChatMessageForEveryone,
        conversationId: conversationId,
        counterpartUserId: counterpartUserId,
        realtime: chatRealtime,
        cache: _chatThreadCache,
        getAttachmentUrl: _getChatAttachmentUrl,
        // The inbox clears this conversation's badge the moment it is opened;
        // the thread's mark-read is what earns that clear. Roll the badge back
        // when the server never acknowledged, so the inbox never shows "read"
        // for a thread the backend still counts as unread.
        onReadSync: (acknowledged) {
          if (acknowledged) {
            chatListCubit.confirmUnreadCleared(conversationId);
            // The server agreed the thread is read — remove this conversation's
            // already-delivered OS notifications (WhatsApp-style), leaving every
            // other conversation's banners untouched (they carry a different
            // thread-id/tag). No-op when nothing is delivered.
            deliveredNotifications.clearConversation(conversationId);
          } else {
            chatListCubit.restoreUnread(conversationId);
          }
        },
      );

  /// Cache of opened threads — lets a re-opened conversation paint its last
  /// messages instantly while it refreshes in the background. Constructed
  /// eagerly (static helpers reference it before [init] runs in tests); its
  /// durable Drift tier is attached during [init] so the instant open survives
  /// a full app restart.
  static final ChatThreadCache _chatThreadCache = ChatThreadCache();

  /// The Drift-backed offline cache for chat (conversations, messages,
  /// reply/attachment metadata, send outbox). The single durable seam; wired
  /// into both [chatRepository] and [_chatThreadCache].
  static late final ChatLocalDataSource _chatLocalDataSource;

  /// Wipes the chat offline cache (both tiers) — the cache-invalidation hook,
  /// called on sign-out so a shared device never leaks one user's conversations
  /// to the next. Best-effort: a failure is swallowed (nothing to recover).
  static Future<void> clearChatCache() async {
    _chatThreadCache.clear();
    // Brokered attachment URLs are short-lived credentials for THIS user's
    // attachments — they must not survive into the next session on a shared
    // device, same reason as the thread cache below.
    _chatRepositoryImpl?.clearAttachmentUrlCache();
    try {
      await _chatLocalDataSource.clearAll();
    } catch (_) {/* cache clear is best-effort */}
  }

  /// The newest message of [conversationId], for an inbox last-message preview.
  /// Prefers the in-memory thread snapshot (instant, covers threads touched
  /// this session — including the caller's own sends, which the socket never
  /// echoes back); otherwise a one-item history fetch. Presentation-only
  /// enrichment (the list endpoint carries no body); null on failure or an
  /// empty thread. Reuses the existing [LoadChatHistory] use case — no new
  /// contract.
  static Future<ChatMessage?> latestChatMessage(String conversationId) async {
    final cached = _chatThreadCache.get(conversationId);
    if (cached != null && cached.messages.isNotEmpty) {
      return cached.messages.last;
    }
    try {
      final page =
          await _loadChatHistory(conversationId: conversationId, limit: 1);
      if (page.items.isEmpty) return null;
      return page.items.reduce((a, b) => a.seq >= b.seq ? a : b);
    } catch (_) {
      return null;
    }
  }

  /// Attachment source for the chat composer (camera/gallery/documents).
  static final ChatAttachmentSource chatAttachmentSource =
      ChatAttachmentPicker();

  /// Chat directory use case — who the caller may message (set in [init] once
  /// the auth repository exists). Shared by the picker and the inbox so both
  /// resolve the same people.
  static late final GetChatDirectory _getChatDirectory;

  /// Builds a fresh new-conversation picker cubit for [user], excluding [user]
  /// themselves. Owned + disposed by its `BlocProvider`.
  static NewChatCubit createNewChatCubit(UserEntity? user) => NewChatCubit(
        getChatDirectory: _getChatDirectory,
        currentUser: user,
      );

  /// Session-cached chat directory (Firebase uid → user), so every widget that
  /// resolves a chat name reads the SAME warm map instead of each doing its own
  /// Firestore read on mount. Empty until the first load; cleared on sign-out.
  static final Map<String, UserEntity> _chatDirectory = {};
  static String? _chatDirectoryUid;
  static DateTime? _chatDirectoryLoadedAt;

  /// Firebase uids of accounts that are **deactivated** (`isActive == false`),
  /// derived from the same read that fills [_chatDirectory]. A positive signal —
  /// a uid is present only when a real document says the account is off — so the
  /// inbox can hide a conversation with a deactivated teammate and the thread can
  /// refuse to open, without ever mistaking an unloaded directory for "everyone
  /// deactivated". Empty until the first [loadChatDirectory]; cleared on
  /// sign-out.
  static final Set<String> _deactivatedChatUids = {};

  /// How long a loaded chat directory is trusted before the next
  /// [loadChatDirectory] re-reads it. The org's people set changes only when an
  /// admin provisions or edits an account (rare), so a few minutes keeps reads
  /// near-zero while still self-healing a teammate created mid-session. Without
  /// it the cache lived until sign-out, so a newly-created employee rendered as
  /// "Teammate" until the app was relaunched. An admin mutation invalidates it
  /// outright ([invalidatePeopleDirectories]); this window covers a change made
  /// on another device.
  static const _chatDirectoryTtl = Duration(minutes: 5);

  /// The cached chat directory as it stands right now — synchronous, so a widget
  /// can seed real names on its FIRST build instead of rendering a "Teammate"
  /// placeholder that only resolves after an async load (the flash the owner
  /// reported). Empty on a cold start, before [loadChatDirectory] has run once.
  static Map<String, UserEntity> get chatDirectorySnapshot => _chatDirectory;

  /// The deactivated-uid set as it stands right now — synchronous, so the inbox
  /// filter and the thread-open guard can read it without awaiting a load. Empty
  /// on a cold start, before [loadChatDirectory] has run once (so nothing is
  /// hidden until we positively know an account is off).
  static Set<String> get deactivatedChatUidsSnapshot => _deactivatedChatUids;

  /// Durable record of which conversations the signed-in user has cleared or
  /// deleted for themselves, so the inbox honours a clear across a refresh AND a
  /// full app restart (the list endpoint keeps reporting the old last message).
  /// Constructed eagerly — the inbox cubit reads it synchronously while
  /// rendering, before [init] resolves in tests.
  static final ChatClearedStore chatClearedStore = ChatClearedStore();

  /// Loads (once) the cleared-conversation store for [uid] and re-emits the
  /// inbox against it, so previously-cleared rows stay hidden the moment the
  /// store is warm. Idempotent — safe to call from every chat surface's mount,
  /// mirroring [loadChatDirectory]. Best-effort; a load failure just leaves the
  /// store empty (nothing hidden).
  static Future<void> loadChatClearedStore(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      await chatClearedStore.load(uid);
      chatListCubit.refilter();
    } catch (_) {
      // Best-effort: a load failure just leaves the store empty (nothing hidden).
    }
  }

  /// The [user]'s chat directory keyed by **Firebase uid**, so the chat UI can
  /// resolve a conversation's `counterpartExternalId` to a real name/avatar/
  /// role. Same set as the picker ([GetChatDirectory]) — so any thread renders
  /// a name rather than a raw id, whoever the counterpart is. Used by the inbox
  /// + thread + home widgets.
  ///
  /// Served from a session cache: a warm cache for the same user returns
  /// immediately (the set changes rarely), so repeat mounts don't re-read or
  /// re-flash. The cache is refreshed whenever the set is (re)loaded.
  static Future<Map<String, UserEntity>> loadChatDirectory(
      UserEntity? user, {bool forceRefresh = false}) async {
    final loadedAt = _chatDirectoryLoadedAt;
    final fresh = loadedAt != null &&
        DateTime.now().difference(loadedAt) < _chatDirectoryTtl;
    if (!forceRefresh &&
        _chatDirectory.isNotEmpty &&
        _chatDirectoryUid == user?.uid &&
        fresh) {
      return _chatDirectory;
    }
    final snapshot = await _getChatDirectory.resolve(user);
    _chatDirectory
      ..clear()
      ..addEntries(snapshot.active.map((u) => MapEntry(u.uid, u)));
    _deactivatedChatUids
      ..clear()
      ..addAll(snapshot.deactivatedUids);
    _chatDirectoryUid = user?.uid;
    _chatDirectoryLoadedAt = DateTime.now();
    // A conversation may have just been hidden (a teammate turned off) or
    // un-hidden (turned back on): re-emit the inbox against the fresh set.
    chatListCubit.refilter();
    return _chatDirectory;
  }

  /// Drops the cached directory — on sign-out, so the next user never resolves a
  /// name against the previous user's directory.
  static void clearChatDirectory() {
    _chatDirectory.clear();
    _deactivatedChatUids.clear();
    _chatDirectoryUid = null;
    _chatDirectoryLoadedAt = null;
  }

  /// Invalidates every in-memory people-directory cache after an admin changes
  /// the user set (create / rename / deactivate / delete / branch or position
  /// change), so a new or renamed teammate resolves to a real name instead of
  /// the "Teammate" (chat) / "Someone" (tasks) fallback — without an app
  /// restart, which was previously the only thing that fixed it. Two separate
  /// caches go stale on such a change:
  ///  * the chat directory here — marked stale but kept warm (stale-while-
  ///    revalidate, so no name flashes to "Teammate"); a proactive force-refresh
  ///    runs now when the signed-in user is known, and every chat surface's own
  ///    next [loadChatDirectory] re-reads regardless;
  ///  * [TaskCubit]'s per-branch member memo — re-enriched immediately from the
  ///    open task set so a just-assigned new employee is named at once.
  static void invalidatePeopleDirectories() {
    _chatDirectoryLoadedAt = null; // stale-while-revalidate: keep the warm map
    final me = authCubit.state.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    if (me != null) unawaited(loadChatDirectory(me, forceRefresh: true));
    taskCubit.refreshDirectory();
  }

  /// Tears down **every app-wide cubit that holds a user-scoped Firestore
  /// stream or cache**, so no listener, timer, or cached list outlives the
  /// session that was allowed to read it.
  ///
  /// The app-wide cubits in `main.dart`'s `MultiBlocProvider` are singletons:
  /// they are built once at `init()` and never disposed while the process
  /// lives. Without this, signing out left their `snapshots()` listeners running
  /// against a signed-out user (permission-denied churn), and the next person to
  /// sign in on the same device saw the previous one's tasks, cases, requests
  /// and attendance until each screen's first refresh landed.
  ///
  /// Called from `AuthCubit`'s pre-sign-out hook, which runs for a deliberate
  /// sign-out **and** for a single-active-session eviction — one path, so an
  /// eviction can never clean up less than the Settings button does.
  ///
  /// Best-effort per cubit: one failure must not stop the rest from clearing.
  static Future<void> clearUserScopedState() async {
    void safely(void Function() clear) {
      try {
        clear();
      } catch (_) {/* best-effort — see doc */}
    }

    safely(taskCubit.reset);
    safely(caseListCubit.reset);
    safely(requestsListCubit.reset);
    safely(attendanceCubit.reset);
    safely(attendanceAdminCubit.reset);
    safely(shiftSwapCubit.reset);
    // App-wide admin/manager cubits holding live user-scoped Firestore streams.
    // Without a teardown here their listeners outlive the session — running
    // against a signed-out user (permission-denied noise) and leaking the
    // previous user's data into the next session on a shared device.
    safely(branchOperationsCubit.reset);
    safely(broadcastCubit.reset);
    try {
      await salesMonthCubit.reset();
    } catch (_) {/* best-effort */}
    // The notification inbox already had its own teardown; route it through the
    // same hook so there is one answer to "what is cleared on sign-out".
    try {
      await notificationCubit.clear();
    } catch (_) {/* best-effort */}
  }

  static late final AuthCubit authCubit;
  static late final ProfileCubit profileCubit;
  static late final TaskCubit taskCubit;

  /// Which tasks this viewer has already opened — drives the one-time
  /// "new task" attention treatment on Employee Home. Client-only and
  /// constructed eagerly: it is read from a widget's `initState`, not from a
  /// cubit, and must be available before [init] completes in tests.
  static final TaskSeenStore taskSeenStore = TaskSeenStore();

  // ─── Admin module (Phase 5) ─────────────────────────────────
  static late final BranchCubit branchCubit;
  static late final AdminUsersCubit adminUsersCubit;

  // ─── Statistics / dashboards (Phase 6) ──────────────────────
  static late final StatisticsCubit statisticsCubit;

  // ─── Weekly schedule + shift swaps (Phase 7) ────────────────
  static late final ScheduleCubit scheduleCubit;
  static late final TodayCoverageCubit todayCoverageCubit;

  /// Shift templates (Schedule V2 · Pillar 5). The repository is shared; the
  /// manager cubit is created on demand by the template sheet.
  static late final ShiftTemplateRepository shiftTemplateRepository;
  static ShiftTemplateCubit createShiftTemplateCubit() =>
      ShiftTemplateCubit(shiftTemplateRepository);
  static late final ShiftSwapCubit shiftSwapCubit;

  // ─── Branch Operations cockpit (task→operations redesign) ───
  static late final BranchOperationsCubit branchOperationsCubit;

  // ─── Communications Center (Phase 1) ────────────────────────
  static late final BroadcastCubit broadcastCubit;

  // ─── Broadcast templates (Phase 2 Commit 2) ─────────────────
  static late final BroadcastTemplateCubit broadcastTemplateCubit;

  // ─── Broadcast schedules (Phase 2 Commit 4) ─────────────────
  static late final BroadcastScheduleCubit broadcastScheduleCubit;

  // ─── Notifications (Notification System Phase 1) ────────────
  static late final NotificationCubit notificationCubit;

  /// FCM foundation (Phase 6) — token registration + foreground handling.
  static late final NotificationService notificationService;

  /// Clears delivered chat notifications from the OS surface when a conversation
  /// is opened + read (and all of them on sign-out). Plain platform-channel
  /// wrapper with no dependencies, so it is constructed eagerly.
  static final DeliveredNotifications deliveredNotifications =
      DeliveredNotifications();

  /// This device's notification switches for the signed-in user. Client-only
  /// and constructed eagerly: it is read from a widget's `initState`, not from
  /// a cubit, and must be available before [init] completes in tests. Nothing
  /// consumes it for delivery yet — see [NotificationPreferencesStore].
  static final NotificationPreferencesStore notificationPreferences =
      NotificationPreferencesStore();

  /// Case Management — the inbox list cubit (singleton, app-wide).
  static late final CaseListCubit caseListCubit;

  // Case Management — repository + write use cases, kept so a fresh per-case
  // [CaseConversationCubit] can be built on demand (one per opened case).
  static late final CaseRepository _caseRepository;
  static late final SendCaseMessage _sendCaseMessage;
  static late final ChangeCaseStatus _changeCaseStatus;
  static late final UploadCaseAttachment _uploadCaseAttachment;

  /// Builds a fresh conversation cubit for [caseId] (owned + disposed by its
  /// `BlocProvider`; re-created when the selected case changes).
  static CaseConversationCubit createCaseConversationCubit(
    String caseId,
    UserEntity? user,
  ) =>
      CaseConversationCubit(
        repository: _caseRepository,
        sendMessage: _sendCaseMessage,
        changeStatus: _changeCaseStatus,
        uploadCaseAttachment: _uploadCaseAttachment,
        user: user,
        caseId: caseId,
      );

  /// Operations Requests — the inbox list cubit (singleton, app-wide).
  static late final RequestsListCubit requestsListCubit;

  // Operations Requests — repository + write use cases, kept so a fresh per-request
  // [RequestDetailCubit] can be built on demand (one per opened request).
  static late final RequestRepository _requestRepository;
  static late final ChangeRequestStatus _changeRequestStatus;
  static late final AddRequestComment _addRequestComment;
  static late final UploadRequestAttachment _uploadRequestAttachment;

  /// Builds a fresh detail cubit for [requestId] (owned + disposed by its
  /// `BlocProvider`; re-created when the selected request changes).
  static RequestDetailCubit createRequestDetailCubit(
    String requestId,
    UserEntity? user,
  ) =>
      RequestDetailCubit(
        repository: _requestRepository,
        changeStatus: _changeRequestStatus,
        addComment: _addRequestComment,
        uploadAttachment: _uploadRequestAttachment,
        user: user,
        requestId: requestId,
        eventTracking: eventTracking,
      );

  /// Attendance (clock in/out) — the employee-facing cubit (singleton, app-wide).
  static late final AttendanceCubit attendanceCubit;

  /// Admin attendance dashboard — the branch-scoped roster × attendance board +
  /// correction queue (singleton, app-wide; a future manager view reuses it).
  static late final AttendanceAdminCubit attendanceAdminCubit;

  // Attendance repository — kept so fresh, per-view History / Details cubits can
  // be built on demand (one per opened ledger / record), the same pattern as the
  // requests detail cubit. The employee/admin cubits above hold it internally.
  static late final AttendanceRepository _attendanceRepository;
  static late final AttendanceReportingRepository _attendanceReportingRepository;
  static late final AttendanceWeekReviewRepository weekReviewRepository;

  /// Branch member directory used by the reporting screens to put a name on a
  /// phantom no-show, which has no attendance record to carry one.
  static late final GetUsersByBranch _reportUsersByBranch;

  // Kept so Daily Review can build its own board cubit for a past day without
  // re-scoping the live board's singleton underneath it.
  static late final ScheduleRepository _scheduleRepositoryRef;
  static late final BranchRepository _branchRepositoryRef;

  /// Branch Sales Target — read-only ledger seam (P1). P3 constructs the sales
  /// cubits and read use cases from this once presentation consumers exist.
  static late final SalesRepository salesRepository;
  /// P3 — the employee Home sales card + submission screen consume this app-wide.
  static late final SalesMonthCubit salesMonthCubit;
  // P3 presentation consumes these write actions when its sales cubits land.
  static late final SubmitDailySales submitDailySales;
  static late final RecordDailySales recordDailySales;
  static late final SetBranchMonthlyTarget setBranchMonthlyTarget;
  static late final ApproveSalesSubmission approveSalesSubmission;
  static late final RejectSalesSubmission rejectSalesSubmission;
  static late final RequestSalesCorrection requestSalesCorrection;
  static late final ResubmitCorrectedSales resubmitCorrectedSales;
  static late final EditApprovedSalesSubmission editApprovedSalesSubmission;
  static late final ReopenSalesSubmission reopenSalesSubmission;

  static SalesManagerDashboardCubit createSalesManagerDashboardCubit() =>
      SalesManagerDashboardCubit(repository: salesRepository, branchRepository: _branchRepositoryRef, approve: approveSalesSubmission, reject: rejectSalesSubmission, requestCorrection: requestSalesCorrection, editApproved: editApprovedSalesSubmission, setTarget: setBranchMonthlyTarget, record: recordDailySales);

  static SalesAdminOverviewCubit createSalesAdminOverviewCubit() =>
      SalesAdminOverviewCubit(repository: salesRepository);

  static SalesSubmissionDetailCubit createSalesSubmissionDetailCubit(String submissionId) =>
      SalesSubmissionDetailCubit(submissionId: submissionId, repository: salesRepository, approve: approveSalesSubmission, reject: rejectSalesSubmission, requestCorrection: requestSalesCorrection, editApproved: editApprovedSalesSubmission, reopen: reopenSalesSubmission);

  /// Builds a fresh Attendance History ledger cubit — the employee's own history
  /// ([AttendanceHistoryMode.self]) or a manager/admin branch review
  /// ([AttendanceHistoryMode.review]). Owned + disposed by its `BlocProvider`.
  static AttendanceHistoryCubit createAttendanceHistoryCubit({
    required AttendanceHistoryMode mode,
    String? userId,
    String? branchId,
    String? initialSearch,
    DateTime? initialStart,
    DateTime? initialEnd,
  }) =>
      AttendanceHistoryCubit(
        repository: _attendanceRepository,
        mode: mode,
        userId: userId,
        branchId: branchId,
        // Review resolves a name search against the whole branch directory, not
        // just days that produced a record; self-history needs no directory.
        getUsersByBranch:
            mode == AttendanceHistoryMode.review ? _reportUsersByBranch : null,
        // A deep link from a report pins the ledger to that report's window, so
        // the rows read the same period the row was tapped in. Both bounds are
        // required — one alone would half-apply a range the resolver would then
        // fall back on anyway.
        query: (initialStart != null && initialEnd != null)
            ? AttendanceHistoryQuery(
                range: AttendanceDateRange.custom,
                customStart: initialStart,
                customEnd: initialEnd,
                text: initialSearch ?? '',
              )
            : AttendanceHistoryQuery(text: initialSearch ?? ''),
      );

  /// Builds a **fresh** attendance board cubit for Daily Review.
  ///
  /// Deliberately not the `attendanceAdminCubit` singleton: that one is pinned
  /// to today for the live board, and Daily Review scopes itself to a past
  /// business day. Sharing the instance would re-scope the live board underneath
  /// whoever else is looking at it.
  static AttendanceAdminCubit createAttendanceDailyReviewCubit() =>
      AttendanceAdminCubit(
        repository: _attendanceRepository,
        scheduleRepository: _scheduleRepositoryRef,
        branchRepository: _branchRepositoryRef,
        getUsersByBranch: _reportUsersByBranch,
        decideCorrection: DecideCorrection(_attendanceRepository),
        service: const AttendanceService(),
      );

  /// Builds the admin cross-branch attendance overview cubit. Ledger-only, like
  /// every reporting read; it fans out one branch range stream per branch and
  /// merges, so it needs no new index (ADR-017).
  static AdminAttendanceOverviewCubit createAdminAttendanceOverviewCubit() =>
      AdminAttendanceOverviewCubit(
        repository: _attendanceReportingRepository,
      );

  /// Builds a fresh Attendance Reporting cubit. Reporting reads only the
  /// `attendance_expectations` ledger; raw attendance and schedules stay out of
  /// this read path by contract (ADR-017).
  static AttendanceReportCubit createAttendanceReportCubit() =>
      AttendanceReportCubit(
        repository: _attendanceReportingRepository,
        // Labels only. A phantom no-show has no attendance record to carry a
        // name, so without this every absence renders as a raw uid. Denominators
        // still come from the ledger alone.
        getUsersByBranch: _reportUsersByBranch,
      );

  /// Builds a fresh Attendance record Details cubit (record + server-derived
  /// audit trail + corrections), seeded from the tapped record for an instant
  /// first paint. Owned + disposed by its `BlocProvider`.
  static AttendanceDetailsCubit createAttendanceDetailsCubit(
    String recordId, {
    AttendanceEntity? seed,
  }) =>
      AttendanceDetailsCubit(
        repository: _attendanceRepository,
        recordId: recordId,
        seed: seed,
      );

  /// Phase 3 task foundation, activated by the Phase 4 [taskCubit] + use cases.
  static late final TaskRepository taskRepository;

  // ─── Event Tracking + Audit Log (immutable audit trail) ─────
  /// The single write seam every feature calls to record an audited business
  /// action. Passed into the producing cubits (TaskCubit, Requests) below.
  static late final EventTrackingService eventTracking;

  /// Read side of the audit trail (kept for a future audit-log admin view). The
  /// repository is the only thing that touches the `audit_logs` collection.
  static late final AuditRepository auditRepository;

  static void init() {
    // ─── NestJS API foundation (chat backend · Phase 1) ─────────
    // Firebase stays the identity provider: every request carries the caller's
    // Firebase ID token (cached by the SDK; force-refreshed once on a 401).
    // Signed out → null → the request goes out bare and the server rejects it.
    Future<String?> nestTokenProvider({bool forceRefresh = false}) async =>
        FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
    apiClient = ApiClient(
      baseUrl: NetworkConfig.apiBaseUrl,
      tokenProvider: nestTokenProvider,
    );

    // Realtime channel (Socket.IO `/chat` namespace) — same identity, same
    // base URL. Connects lazily on the first joined conversation and drops
    // the socket when none remain; REST stays the source of truth.
    chatRealtime = ChatSocketService(
      baseUrl: NetworkConfig.apiBaseUrl,
      tokenProvider: nestTokenProvider,
    );

    // Direct chat. One remote datasource over the shared ApiClient + one Drift
    // local datasource (the offline cache); the repository orchestrates both.
    // The list cubit is an app-wide singleton and thread cubits are built per
    // opened conversation (see createChatConversationCubit).
    _chatLocalDataSource = ChatLocalDataSourceImpl(ChatDatabase.open());
    _chatThreadCache.attachLocal(_chatLocalDataSource);
    chatRepository = _chatRepositoryImpl = ChatRepositoryImpl(
      ChatRemoteDataSourceImpl(apiClient),
      _chatLocalDataSource,
    );
    _getChatConversation = GetConversation(chatRepository);
    _deleteChatMessageForMe = DeleteChatMessageForMe(chatRepository);
    _deleteChatMessageForEveryone = DeleteChatMessageForEveryone(chatRepository);
    _loadChatHistory = LoadChatHistory(chatRepository);
    _sendChatMessage = SendChatMessage(chatRepository);
    _markChatRead = MarkChatRead(chatRepository);
    _getChatAttachmentUrl = GetChatAttachmentUrl(chatRepository);
    chatListCubit = ChatListCubit(
      getConversations: GetConversations(chatRepository),
      startConversation: StartConversation(chatRepository),
      getCachedConversations: GetCachedConversations(chatRepository),
      realtime: chatRealtime,
      // Hide conversations whose counterpart's account was deactivated. Reads
      // the live session cache filled by [loadChatDirectory], so a mid-session
      // deactivation takes effect on the next directory (re)load.
      deactivatedCounterpartUids: () => _deactivatedChatUids,
      // Hide conversations the viewer has cleared/deleted for themselves until a
      // newer message arrives — persisted, so it survives a refresh/restart.
      clearedThroughMillis: chatClearedStore.clearedThroughMillis,
      onConversationCleared: (id, through) =>
          chatClearedStore.markCleared(id, through),
      // Bulk delete-for-me behind the inbox "Delete conversation" action.
      clearConversation: ClearChatForMe(chatRepository).call,
    );

    final authRemoteDataSource = AuthRemoteDataSourceImpl(FirebaseAuth.instance);
    final userRemoteDataSource = UserRemoteDataSourceImpl(FirebaseFirestore.instance);
    final profileRemoteDataSource = ProfileRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
    // Single seam for all media (image/video) uploads to Storage — task
    // evidence and case + request attachments all route through it (adds
    // cache-control metadata + central error translation in one place).
    final mediaUploadService = MediaUploadService(FirebaseStorage.instance);
    final taskRemoteDataSource = TaskRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      mediaUploadService,
    );

    final AuthRepository authRepository =
        AuthRepositoryImpl(authRemoteDataSource, userRemoteDataSource);

    // Chat directory (every active user but the caller — flat, no branch/role)
    // — the picker and the inbox share it.
    _getChatDirectory = GetChatDirectory(authRepository);
    _reportUsersByBranch = GetUsersByBranch(authRepository);

    final ProfileRepository profileRepository =
        ProfileRepositoryImpl(profileRemoteDataSource, authRemoteDataSource);

    taskRepository = TaskRepositoryImpl(taskRemoteDataSource);

    // Branch repository is built early — the TaskCubit needs it for the admin's
    // New Task branch dropdown (the admin module reuses the same instance).
    final branchRemoteDataSource = BranchRemoteDataSourceImpl(
        FirebaseFirestore.instance, FirebaseStorage.instance);
    final BranchRepository branchRepository =
        BranchRepositoryImpl(branchRemoteDataSource);

    // Branch Sales Target — P3 cubits consume this stable read/write seam.
    salesRepository = SalesRepositoryImpl(
      SalesRemoteDataSourceImpl(FirebaseFirestore.instance, FirebaseFunctions.instance),
    );
    submitDailySales = SubmitDailySales(salesRepository);
    recordDailySales = RecordDailySales(salesRepository);
    setBranchMonthlyTarget = SetBranchMonthlyTarget(salesRepository);
    approveSalesSubmission = ApproveSalesSubmission(salesRepository);
    rejectSalesSubmission = RejectSalesSubmission(salesRepository);
    requestSalesCorrection = RequestSalesCorrection(salesRepository);
    resubmitCorrectedSales = ResubmitCorrectedSales(salesRepository);
    editApprovedSalesSubmission = EditApprovedSalesSubmission(salesRepository);
    reopenSalesSubmission = ReopenSalesSubmission(salesRepository);
    salesMonthCubit = SalesMonthCubit(
      repository: salesRepository,
      branchRepository: branchRepository,
      submitDailySales: submitDailySales,
      resubmitCorrectedSales: resubmitCorrectedSales,
    );

    // Notification repository is built early — the TaskCubit needs the
    // NotifyTaskEvent use case for its automatic task-event notifications.
    final NotificationRepository notificationRepository =
        NotificationRepositoryImpl(
      NotificationRemoteDataSourceImpl(
          FirebaseFirestore.instance, FirebaseFunctions.instance),
    );

    // Event Tracking + Audit Log is built early too — its single write seam
    // ([eventTracking]) is injected into the producing cubits (TaskCubit +
    // Requests) below. All audit writes flow through the service; nothing else
    // touches the `audit_logs` collection.
    auditRepository = AuditRepositoryImpl(
      AuditRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    eventTracking = EventTrackingService(auditRepository);

    authCubit = AuthCubit(
      repository: authRepository,
      signInWithEmail: SignInWithEmail(authRepository),
      signOut: SignOut(authRepository),
      getUser: GetUser(authRepository),
      forgotPassword: ForgotPassword(authRepository),
      changePassword: ChangePassword(authRepository),
      // Drop this device's FCM token before Firebase sign-out (while still
      // authenticated), so the signed-out account stops receiving this device's
      // pushes. `notificationService` is a `late final` static assigned later in
      // init(); the closure is invoked only at sign-out, long after it's set.
      // Also wipe the chat offline cache so a shared device never leaks one
      // user's conversations to the next (cache invalidation).
      onPreSignOut: () async {
        await notificationService.forgetUser();
        // Drop this account's delivered OS notifications so the next user on a
        // shared device never sees the previous account's chat banners.
        await deliveredNotifications.clearAll();
        await clearChatCache();
        // Reset the app-wide inbox cubit's in-memory state too: it outlives the
        // sign-out, so without this the next signed-in user would briefly see
        // the previous user's conversations before the network refresh lands.
        chatListCubit.reset();
        clearChatDirectory();
        // Drop this account's cleared-conversation watermarks so the next user
        // on a shared device never inherits them.
        chatClearedStore.clear();
        // Every remaining user-scoped live stream. Runs for a deliberate
        // sign-out AND for a single-active-session eviction, because both go
        // through `AuthCubit._signOutInternal`.
        await clearUserScopedState();
      },
      // Single active session: this device's claim lives in the platform
      // keystore. Supplying the store is what ARMS enforcement — an AuthCubit
      // built without one (every widget test) behaves exactly as before.
      sessionStore: const SecureSessionStore(),
    );

    profileCubit = ProfileCubit(
      getProfile: GetProfile(profileRepository),
      updateProfile: UpdateProfile(profileRepository),
      uploadProfileImage: UploadProfileImage(profileRepository),
      uploadCoverImage: UploadCoverImage(profileRepository),
      checkUsername: CheckUsername(profileRepository),
    );

    // Schedule repository is built early — the TaskCubit needs it to resolve an
    // employee's shift(s) today (Shift Assignment feature) and shift-task
    // notification recipients; reused as-is by scheduleCubit/shiftSwapCubit/
    // branchOperationsCubit below.
    final ScheduleRepository scheduleRepository = ScheduleRepositoryImpl(
      ScheduleRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseFunctions.instance,
      ),
    );

    // Shift templates (Schedule V2 · Pillar 5) — reused by scheduleCubit (to
    // snapshot new weeks + apply scoped hours edits) and the template manager.
    shiftTemplateRepository = ShiftTemplateRepositoryImpl(
      ShiftTemplateRemoteDataSourceImpl(FirebaseFirestore.instance),
    );

    taskCubit = TaskCubit(
      repository: taskRepository,
      branchRepository: branchRepository,
      scheduleRepository: scheduleRepository,
      createTask: CreateTask(taskRepository),
      updateTask: UpdateTask(taskRepository),
      deleteTask: DeleteTask(taskRepository),
      assignTask: AssignTask(taskRepository),
      uploadTaskAttachment: UploadTaskAttachment(taskRepository),
      getUsersByBranch: GetUsersByBranch(authRepository),
      notifyTaskEvent: NotifyTaskEvent(notificationRepository),
      eventTracking: eventTracking,
      // Who is told a task is waiting for review. Without this the submitted
      // notice goes to `task.createdBy` alone, which is silence whenever that
      // account has been deactivated, deleted, demoted, or moved branch — and
      // a generated shift task inherits its TEMPLATE's creator, so that is a
      // daily occurrence once the person who set it up leaves.
      resolveTaskReviewers: ResolveTaskReviewers(authRepository),
    );

    // ─── Case Management (private conversation until resolution) ─────────
    // The list cubit (like TaskCubit): use cases for writes, repository directly
    // for the role-scoped realtime/one-shot case lists. Reuses branchRepository
    // (branch names) + GetUsersByBranch (member directory). The per-case
    // conversation cubit is built on demand via [createCaseConversationCubit].
    // Case notifications are produced server-side.
    final CaseRepository caseRepository = CaseRepositoryImpl(
      CaseRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        mediaUploadService,
      ),
    );
    _caseRepository = caseRepository;
    final uploadCaseAttachment = UploadCaseAttachment(caseRepository);
    _uploadCaseAttachment = uploadCaseAttachment;
    _sendCaseMessage = SendCaseMessage(caseRepository);
    _changeCaseStatus = ChangeCaseStatus(caseRepository);
    caseListCubit = CaseListCubit(
      repository: caseRepository,
      branchRepository: branchRepository,
      createCase: CreateCase(caseRepository),
      uploadCaseAttachment: uploadCaseAttachment,
      getUsersByBranch: GetUsersByBranch(authRepository),
      seenStore: CaseSeenStore(),
    );

    // ─── Operations Requests (in-the-moment approvals) ──────────────────
    // Same hybrid as Cases: the list cubit reads a single role-scoped realtime
    // stream + files new requests (use cases for the write); the per-request
    // detail cubit is built on demand via [createRequestDetailCubit]. Reuses
    // branchRepository for branch names. Notifications are produced server-side
    // by the `onRequest*` Cloud Functions.
    final RequestRepository requestRepository = RequestRepositoryImpl(
      RequestRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        mediaUploadService,
      ),
    );
    _requestRepository = requestRepository;
    _uploadRequestAttachment = UploadRequestAttachment(requestRepository);
    _changeRequestStatus = ChangeRequestStatus(requestRepository);
    _addRequestComment = AddRequestComment(requestRepository);
    requestsListCubit = RequestsListCubit(
      repository: requestRepository,
      branchRepository: branchRepository,
      createRequest: CreateRequest(requestRepository),
      uploadAttachment: _uploadRequestAttachment,
      eventTracking: eventTracking,
    );

    // ─── Attendance (clock in/out + corrections) ────────────────────────
    // The employee-facing cubit reuses the existing schedule seam to resolve
    // today's shift + scheduled window (no attendance re-derivation), drives its
    // whole surface from one realtime history stream (carrying offline/syncing
    // metadata), and gates every clock/correction action through the pure
    // validation engine. Clients write ONLY the record + correction docs; the
    // append-only audit trail, the approved-correction apply, auto-close, and all
    // notifications are derived SERVER-SIDE (onAttendanceWritten /
    // onAttendanceCorrectionWritten / autoCloseAttendance). `AttendanceService`
    // is the config/dark-switch seam. `DecideCorrection` + the manager review
    // cubit are wired when the review UI lands (a later phase).
    final AttendanceRepository attendanceRepository = AttendanceRepositoryImpl(
      AttendanceRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
      ),
    );
    final AttendanceReportingRepository attendanceReportingRepository =
        AttendanceReportingRepositoryImpl(
          AttendanceReportingDataSourceImpl(FirebaseFirestore.instance),
        );
    // Shared with the on-demand History / Details cubit factories.
    _attendanceRepository = attendanceRepository;
    _attendanceReportingRepository = attendanceReportingRepository;
    // The week-review assertion (ADR-019) — a plain client write gated by
    // rules, deliberately outside the ledger-only reporting read path.
    weekReviewRepository = AttendanceWeekReviewRepositoryImpl(
      FirebaseFirestore.instance,
    );
    attendanceCubit = AttendanceCubit(
      repository: attendanceRepository,
      scheduleRepository: scheduleRepository,
      branchRepository: branchRepository,
      service: const AttendanceService(),
      locationService: const GeolocatorLocationService(),
      clockIn: ClockIn(attendanceRepository),
      clockOut: ClockOut(attendanceRepository),
      requestCorrection: RequestCorrection(attendanceRepository),
    );
    _scheduleRepositoryRef = scheduleRepository;
    _branchRepositoryRef = branchRepository;
    attendanceAdminCubit = AttendanceAdminCubit(
      repository: attendanceRepository,
      scheduleRepository: scheduleRepository,
      branchRepository: branchRepository,
      getUsersByBranch: GetUsersByBranch(authRepository),
      decideCorrection: DecideCorrection(attendanceRepository),
      service: const AttendanceService(),
    );

    // ─── Admin module (Phase 5) ───────────────────────────────
    // Account provisioning (create / reset password) goes through admin-only
    // Cloud Functions (Admin SDK), so the datasource also takes FirebaseFunctions.
    final userAdminRemoteDataSource = UserAdminRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseFunctions.instance,
    );
    final UserAdminRepository userAdminRepository =
        UserAdminRepositoryImpl(userAdminRemoteDataSource);

    branchCubit = BranchCubit(branchRepository);
    adminUsersCubit = AdminUsersCubit(
      userAdminRepository,
      branchRepository,
      onUsersChanged: invalidatePeopleDirectories,
    );

    // ─── Statistics / dashboards (Phase 6) ────────────────────
    final StatisticsRepository statisticsRepository = StatisticsRepositoryImpl(
      StatisticsRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    statisticsCubit = StatisticsCubit(statisticsRepository);

    // ─── Weekly schedule + shift swaps (Phase 7) ──────────────
    // (scheduleRepository built earlier, above, so TaskCubit could use it.)
    scheduleCubit = ScheduleCubit(
      scheduleRepository,
      GetUsersByBranch(authRepository),
      shiftTemplateRepository,
    );
    todayCoverageCubit = TodayCoverageCubit(
      scheduleRepository,
      GetUsersByBranch(authRepository),
    );
    shiftSwapCubit = ShiftSwapCubit(
      scheduleRepository,
      NotifySwapEvent(notificationRepository),
      GetUsersByBranch(authRepository),
    );

    // ─── Branch Operations cockpit ────────────────────────────
    // Read/derive cubit composing the task stream × branch members × today's
    // roster; writes still flow through [taskCubit].
    branchOperationsCubit = BranchOperationsCubit(
      taskRepository: taskRepository,
      scheduleRepository: scheduleRepository,
      getUsersByBranch: GetUsersByBranch(authRepository),
    );

    // ─── Communications Center (Phase 1 + Phase 2 send engine) ─
    // Hybrid cubit (like TaskCubit): the SendBroadcast use case for the write
    // (→ the callable `sendBroadcast` Cloud Function), the repository directly
    // for the realtime feed stream (Firestore).
    final BroadcastRepository broadcastRepository = BroadcastRepositoryImpl(
      BroadcastRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseFunctions.instance,
      ),
    );
    broadcastCubit = BroadcastCubit(
      repository: broadcastRepository,
      sendBroadcast: SendBroadcast(broadcastRepository),
      branchRepository: branchRepository,
      getUsersByBranch: GetUsersByBranch(authRepository),
    );

    // ─── Broadcast templates (Phase 2 Commit 2) ───────────────
    final BroadcastTemplateRepository broadcastTemplateRepository =
        BroadcastTemplateRepositoryImpl(
      BroadcastTemplateRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    broadcastTemplateCubit =
        BroadcastTemplateCubit(broadcastTemplateRepository);

    // ─── Broadcast schedules (Phase 2 Commit 4) ───────────────
    final BroadcastScheduleRepository broadcastScheduleRepository =
        BroadcastScheduleRepositoryImpl(
      BroadcastScheduleRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    broadcastScheduleCubit =
        BroadcastScheduleCubit(broadcastScheduleRepository);

    // ─── Notifications (Notification System Phase 1) ──────────
    notificationCubit = NotificationCubit(
      repository: notificationRepository,
      markRead: MarkNotificationRead(notificationRepository),
    );

    notificationService = NotificationService(
      FirebaseMessaging.instance,
      FirebaseFirestore.instance,
    );
  }
}
