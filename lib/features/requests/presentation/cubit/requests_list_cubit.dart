import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/audit/domain/entities/audit_actor.dart';
import 'package:opshub/features/audit/domain/services/event_tracking_service.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/repositories/request_repository.dart';
import 'package:opshub/features/requests/domain/usecases/create_request.dart';
import 'package:opshub/features/requests/domain/usecases/upload_request_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'requests_list_state.dart';

/// Drives the employee approval-requests inbox (the list) for all three roles.
/// Unlike Cases there is **no privacy split**, so every role reads a single
/// realtime stream (no one-shot collectionGroup):
///   admin    → every request (global visibility);
///   manager  → own-branch requests (their approval inbox);
///   employee → their own requests (`requesterId == uid`).
///
/// Filing a request lives here (employees only — approvers never file); the
/// per-request timeline + decisions + admin reopen/delete live in
/// [RequestDetailCubit]. Notifications are produced **server-side** by the
/// `onRequest*` Cloud Functions.
class RequestsListCubit extends Cubit<RequestsListState> {
  final RequestRepository _repository;
  final BranchRepository _branchRepository;
  final CreateRequest _createRequest;
  final UploadRequestAttachment _uploadAttachment;

  /// Immutable audit trail (optional — null in tests that don't exercise it).
  final EventTrackingService? _eventTracking;

  UserEntity? _user;
  StreamSubscription<List<RequestEntity>>? _sub;
  bool _mutating = false;
  final Map<String, String> _branchNames = {};

  Map<String, String> get branchNames => Map.unmodifiable(_branchNames);

  RequestsListCubit({
    required this._repository,
    required this._branchRepository,
    required this._createRequest,
    required this._uploadAttachment,
    this._eventTracking,
  }) : super(const RequestsListState.initial());

  List<RequestEntity> get _requests =>
      state.maybeWhen(loaded: (r, _) => r, orElse: () => const []);

  static String _scopeKey(UserEntity u) =>
      '${u.uid}:${u.role.value}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    final inError = state.maybeWhen(error: (_) => true, orElse: () => false);
    final sameScope = _user != null && _scopeKey(_user!) == _scopeKey(user);
    if (!forceRefresh && !inError && _sub != null && sameScope) return;

    if (!sameScope) _branchNames.clear();
    _user = user;
    _loadBranchNames();

    final hasData =
        state.maybeWhen(loaded: (_, _) => true, orElse: () => false);
    if (!hasData) emit(const RequestsListState.loading());

    await _sub?.cancel();
    _sub = null;

    AppLog.call('requests', 'load', meta: {
      'role': user.role.value,
      'uid': user.uid,
      'branch': user.branchId ?? '-',
    });

    final Stream<List<RequestEntity>> stream;
    if (user.role.isAdmin) {
      stream = _repository.watchAllRequests();
    } else if (user.role.isManager) {
      stream = _repository.watchBranchRequests(user.branchId ?? '');
    } else {
      stream = _repository.watchMyRequests(user.uid);
    }
    _subscribe(stream);
  }

  void _subscribe(Stream<List<RequestEntity>> stream) {
    _sub = stream.listen(
      (requests) => _emitLoaded(requests),
      onError: (Object error, StackTrace st) {
        AppLog.error('requests', 'stream error', error, st);
        emit(const RequestsListState.error(
            'Failed to load requests. Please try again.'));
      },
    );
  }

  void _emitLoaded(List<RequestEntity> requests) {
    if (isClosed) return;
    emit(RequestsListState.loaded(
      requests,
      branchNames: Map.of(_branchNames),
    ));
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user, forceRefresh: true);
  }

  Future<void> _loadBranchNames() async {
    try {
      final list = await _branchRepository.getBranches();
      for (final b in list) {
        _branchNames[b.id] = b.name;
      }
      if (!isClosed) {
        state.mapOrNull(
          loaded: (s) => emit(s.copyWith(branchNames: Map.of(_branchNames))),
        );
      }
    } catch (e) {
      AppLog.warning('requests', 'branch-name enrichment failed: $e');
    }
  }

  // ─── Filing a request (employees only — the UI gates the entry point) ──
  /// Files a new request. Pre-generates the id so opening media uploads under it
  /// BEFORE the doc is written (so `onRequestCreated` sees the attachments when it
  /// builds the opening event). Returns the created request, or null on failure.
  Future<RequestEntity?> submitRequest({
    required RequestType type,
    required Map<String, dynamic> details,
    List<PickedAttachment> attachments = const [],
  }) async {
    final user = _user;
    if (user == null || _mutating) return null;
    _mutating = true;

    try {
      final requestId = _repository.newRequestId();
      final uploaded = <TaskAttachment>[];
      if (attachments.isNotEmpty) {
        uploaded.addAll(await Future.wait([
          for (final a in attachments)
            _uploadAttachment(
              requestId: requestId,
              file: a.file,
              type: a.type,
              uploadedBy: user.uid,
              uploadedByName: user.displayName,
              durationMs: a.durationMs,
            ),
        ]));
      }
      final message = (details['message'] ?? '').toString().trim();
      final entity = RequestEntity(
        id: requestId,
        branchId: user.branchId,
        type: type,
        requesterId: user.uid,
        requesterName: user.displayName,
        requesterRole: user.role,
        details: details,
        attachments: uploaded,
        // Optimistic preview so the row has content before `onRequestCreated`.
        lastEventPreview: message.isNotEmpty ? message : type.label,
      );
      final created = await _createRequest(entity);
      // Audit: an approval request was filed (best-effort, fire-and-forget).
      _eventTracking?.trackEvent(
        type: AuditEventType.requestCreated,
        actor: AuditActor.of(user),
        entityId: created.id,
        branchId: created.branchId,
        metadata: {'requestType': type.value},
      );
      return created;
    } on Failure catch (e) {
      emit(RequestsListState.error(e.message));
      return null;
    } catch (_) {
      emit(const RequestsListState.error(
          'Something went wrong filing your request.'));
      return null;
    } finally {
      _mutating = false;
      _emitLoaded(_requests);
    }
  }

  /// Drops the user-scoped stream and cached branch names, returning the cubit
  /// to [RequestsListState.initial]. Called on sign-out and on
  /// single-active-session eviction — see `AuthCubit._signOutInternal`.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _mutating = false;
    _branchNames.clear();
    _user = null;
    if (!isClosed) emit(const RequestsListState.initial());
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
