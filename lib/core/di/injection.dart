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
import 'package:drop/core/services/notification_service.dart';
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
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/branch/data/datasources/branch_remote_datasource.dart';
import 'package:drop/features/branch/data/repositories/branch_repository_impl.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
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
  }) =>
      ChatConversationCubit(
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
        onReadSync: (acknowledged) => acknowledged
            ? chatListCubit.confirmUnreadCleared(conversationId)
            : chatListCubit.restoreUnread(conversationId),
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

  /// The cached chat directory as it stands right now — synchronous, so a widget
  /// can seed real names on its FIRST build instead of rendering a "Teammate"
  /// placeholder that only resolves after an async load (the flash the owner
  /// reported). Empty on a cold start, before [loadChatDirectory] has run once.
  static Map<String, UserEntity> get chatDirectorySnapshot => _chatDirectory;

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
      UserEntity? user) async {
    if (_chatDirectory.isNotEmpty && _chatDirectoryUid == user?.uid) {
      return _chatDirectory;
    }
    final users = await _getChatDirectory(user);
    _chatDirectory
      ..clear()
      ..addEntries(users.map((u) => MapEntry(u.uid, u)));
    _chatDirectoryUid = user?.uid;
    return _chatDirectory;
  }

  /// Drops the cached directory — on sign-out, so the next user never resolves a
  /// name against the previous user's directory.
  static void clearChatDirectory() {
    _chatDirectory.clear();
    _chatDirectoryUid = null;
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

  /// Branch member directory used by the reporting screens to put a name on a
  /// phantom no-show, which has no attendance record to carry one.
  static late final GetUsersByBranch _reportUsersByBranch;

  /// Builds a fresh Attendance History ledger cubit — the employee's own history
  /// ([AttendanceHistoryMode.self]) or a manager/admin branch review
  /// ([AttendanceHistoryMode.review]). Owned + disposed by its `BlocProvider`.
  static AttendanceHistoryCubit createAttendanceHistoryCubit({
    required AttendanceHistoryMode mode,
    String? userId,
    String? branchId,
    String? initialSearch,
  }) =>
      AttendanceHistoryCubit(
        repository: _attendanceRepository,
        mode: mode,
        userId: userId,
        branchId: branchId,
        query: AttendanceHistoryQuery(text: initialSearch ?? ''),
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
    chatRepository = ChatRepositoryImpl(
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
        await clearChatCache();
        // Reset the app-wide inbox cubit's in-memory state too: it outlives the
        // sign-out, so without this the next signed-in user would briefly see
        // the previous user's conversations before the network refresh lands.
        chatListCubit.reset();
        clearChatDirectory();
      },
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
    adminUsersCubit = AdminUsersCubit(userAdminRepository, branchRepository);

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
