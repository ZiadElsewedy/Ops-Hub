import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/audit/domain/entities/audit_actor.dart';
import 'package:opshub/features/audit/domain/services/event_tracking_service.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/requests/domain/repositories/request_repository.dart';
import 'package:opshub/features/requests/domain/request_access.dart';
import 'package:opshub/features/requests/domain/usecases/add_request_comment.dart';
import 'package:opshub/features/requests/domain/usecases/change_request_status.dart';
import 'package:opshub/features/requests/domain/usecases/upload_request_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'request_detail_state.dart';

/// Drives ONE open request — created per selected request (desktop) or per pushed
/// detail route (mobile). Streams **both** the request doc (header / status /
/// terminal read-only gate) and its `requests/{id}/events` timeline in realtime,
/// so every role sees decisions + comments live. A comment is a single event
/// `add` (no whole-array rewrite). The approve/reject decision is guarded by the
/// pure [canDecideRequest] predicate so the cubit never issues a write the
/// Firestore rule would reject.
class RequestDetailCubit extends Cubit<RequestDetailState> {
  final RequestRepository _repository;
  final ChangeRequestStatus _changeStatus;
  final AddRequestComment _addComment;
  final UploadRequestAttachment _uploadAttachment;
  final UserEntity? _user;
  final String requestId;

  /// Immutable audit trail (optional — null in tests that don't exercise it).
  final EventTrackingService? _eventTracking;

  StreamSubscription<RequestEntity?>? _requestSub;
  StreamSubscription<List<RequestEvent>>? _eventsSub;
  RequestEntity? _request;
  List<RequestEvent> _events = const [];
  bool _requestArrived = false;
  bool _busy = false;

  RequestDetailCubit({
    required this._repository,
    required this._changeStatus,
    required this._addComment,
    required this._uploadAttachment,
    required this._user,
    required this.requestId,
    this._eventTracking,
  }) : super(const RequestDetailState.loading()) {
    _start();
  }

  RequestEntity? get request => _request;

  void _start() {
    _requestSub = _repository.watchRequest(requestId).listen(
      (r) {
        _requestArrived = true;
        _request = r;
        _emit();
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('requests', 'watchRequest error', e, st);
        emit(const RequestDetailState.error('Failed to load the request.'));
        _emit();
      },
    );
    _eventsSub = _repository.watchEvents(requestId).listen(
      (events) {
        _events = events;
        _emit();
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('requests', 'watchEvents error', e, st);
      },
    );
  }

  void _emit() {
    if (isClosed) return;
    final r = _request;
    if (r == null) {
      if (_requestArrived) emit(const RequestDetailState.unavailable());
      return;
    }
    emit(RequestDetailState.loaded(r, _events, busy: _busy));
  }

  // ─── Approver decisions (approve / reject) ─────────────────────
  Future<void> _transition(RequestStatus to) async {
    final user = _user;
    final r = _request;
    if (user == null || r == null || _busy) return;
    if (!r.status.approverNext.contains(to)) return;
    if (!canDecideRequest(user, r)) return;
    _busy = true;
    _emit();
    try {
      await _changeStatus(
        requestId,
        to,
        decidedBy: to.isDecision ? user.uid : null,
        decidedByName: to.isDecision ? user.displayName : null,
      );
      // Audit: the approver's decision (best-effort, fire-and-forget).
      if (to.isDecision) {
        _eventTracking?.trackEvent(
          type: to.isApproved
              ? AuditEventType.requestApproved
              : AuditEventType.requestRejected,
          actor: AuditActor.of(user),
          entityId: requestId,
          branchId: r.branchId,
          metadata: {'requestType': r.type.value},
        );
      }
    } on Failure catch (e) {
      emit(RequestDetailState.error(e.message));
    } catch (_) {
      emit(const RequestDetailState.error('Failed to update the request.'));
    } finally {
      _busy = false;
      _emit();
    }
  }

  Future<void> approve() => _transition(RequestStatus.approved);
  Future<void> reject() => _transition(RequestStatus.rejected);

  /// Admin-only: send a decided request back to Pending (clears the decision,
  /// stamps who reopened; the `reopened` timeline event is written server-side).
  Future<void> reopen() async {
    final user = _user;
    final r = _request;
    if (user == null || r == null || _busy) return;
    if (!canReopenRequest(user, r)) return;
    _busy = true;
    _emit();
    try {
      await _changeStatus(
        requestId,
        RequestStatus.pending,
        decidedBy: user.uid,
        decidedByName: user.displayName,
      );
    } on Failure catch (e) {
      emit(RequestDetailState.error(e.message));
    } catch (_) {
      emit(const RequestDetailState.error('Failed to reopen the request.'));
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// Admin-only SOFT delete. Returns whether it succeeded so the screen can pop.
  Future<bool> deleteRequest() async {
    final user = _user;
    final r = _request;
    if (user == null || r == null || _busy) return false;
    if (!canDeleteRequest(user)) return false;
    _busy = true;
    _emit();
    try {
      await _repository.deleteRequest(requestId);
      return true;
    } on Failure catch (e) {
      emit(RequestDetailState.error(e.message));
      return false;
    } catch (_) {
      emit(const RequestDetailState.error('Failed to delete the request.'));
      return false;
    } finally {
      _busy = false;
      _emit();
    }
  }

  // ─── Comment (single event create) ─────────────────────────────
  /// Returns whether the comment was posted. The composer keys its input-clearing
  /// off this, so a failed send never loses what the user typed.
  Future<bool> addComment(
    String text, {
    List<PickedAttachment> attachments = const [],
  }) async {
    final trimmed = text.trim();
    final user = _user;
    final r = _request;
    if (user == null || r == null || _busy) return false;
    if (!canCommentOnRequest(user, r)) return false;
    if (trimmed.isEmpty && attachments.isEmpty) return false;

    final isRequester = viewerIsRequester(user, r);
    _busy = true;
    _emit();
    try {
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
      await _addComment(
        requestId,
        RequestEvent(
          id: '',
          authorId: user.uid,
          authorName: user.displayName,
          actor: isRequester
              ? RequestEventActor.requester
              : RequestEventActor.approver,
          kind: uploaded.isNotEmpty && trimmed.isEmpty
              ? RequestEventKind.attachmentAdded
              : RequestEventKind.comment,
          text: trimmed.isEmpty ? null : trimmed,
          attachments: uploaded,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    } on Failure catch (e) {
      emit(RequestDetailState.error(e.message));
      return false;
    } catch (_) {
      emit(const RequestDetailState.error('Failed to post your comment.'));
      return false;
    } finally {
      _busy = false;
      _emit();
    }
  }

  @override
  Future<void> close() {
    _requestSub?.cancel();
    _eventsSub?.cancel();
    return super.close();
  }
}
