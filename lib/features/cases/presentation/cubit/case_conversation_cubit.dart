import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/case_status.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/cases/domain/case_participation.dart';
import 'package:drop/features/cases/domain/entities/case_entity.dart';
import 'package:drop/features/cases/domain/entities/case_identity.dart';
import 'package:drop/features/cases/domain/entities/case_message.dart';
import 'package:drop/features/cases/domain/repositories/case_repository.dart';
import 'package:drop/features/cases/domain/usecases/change_case_status.dart';
import 'package:drop/features/cases/domain/usecases/send_case_message.dart';
import 'package:drop/features/cases/domain/usecases/upload_case_attachment.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/core/media/picked_attachment.dart';
import 'case_conversation_state.dart';

/// Drives ONE open case — created per selected case (desktop) or per pushed
/// detail route (mobile). Streams **both** the case doc (header / status /
/// read-only gate) and the `cases/{id}/messages` subcollection in realtime, so
/// every role — including employees, who previously had no stream — sees replies
/// live. A reply is a single message `add` (no whole-array rewrite): the
/// structural fix for the old reply-sending bug.
class CaseConversationCubit extends Cubit<CaseConversationState> {
  final CaseRepository _repository;
  final SendCaseMessage _sendMessage;
  final ChangeCaseStatus _changeStatus;
  final UploadCaseAttachment _uploadCaseAttachment;
  final UserEntity? _user;
  final String caseId;

  StreamSubscription<CaseEntity?>? _caseSub;
  StreamSubscription<List<CaseMessage>>? _messagesSub;
  CaseEntity? _case;
  List<CaseMessage> _messages = const [];
  bool _caseArrived = false;
  bool _sending = false;
  bool _changing = false;

  CaseConversationCubit({
    required this._repository,
    required this._sendMessage,
    required this._changeStatus,
    required this._uploadCaseAttachment,
    required this._user,
    required this.caseId,
  }) : super(const CaseConversationState.loading()) {
    _start();
  }

  void _start() {
    _caseSub = _repository.watchCase(caseId).listen(
      (c) {
        _caseArrived = true;
        _case = c;
        _emit();
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('cases', 'watchCase error', e, st);
        emit(const CaseConversationState.error('Failed to load the case.'));
        _emit();
      },
    );
    _messagesSub = _repository.watchMessages(caseId).listen(
      (m) {
        _messages = m;
        _emit();
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('cases', 'watchMessages error', e, st);
      },
    );
  }

  void _emit() {
    if (isClosed) return;
    final c = _case;
    if (c == null) {
      if (_caseArrived) emit(const CaseConversationState.unavailable());
      return;
    }
    emit(CaseConversationState.loaded(c, _messages,
        sending: _sending, changingStatus: _changing));
  }

  // ─── Send a reply (single message create) ──────────────────────
  /// Returns whether the message was sent. The composer keys its input-clearing
  /// off this, so a failed send never loses what the user typed.
  Future<bool> sendMessage(
    String text, {
    List<PickedAttachment> attachments = const [],
  }) async {
    final trimmed = text.trim();
    final c = _case;
    if (_user == null || c == null || c.isClosed || _sending) return false;
    if (trimmed.isEmpty && attachments.isEmpty) return false;

    final isReporter = viewerIsReporter(_user.role, c);
    final hide = isReporter && c.privacy.isConfidential;

    _sending = true;
    _emit();
    try {
      final uploaded = <TaskAttachment>[];
      if (attachments.isNotEmpty) {
        uploaded.addAll(await Future.wait([
          for (final a in attachments)
            _uploadCaseAttachment(
              caseId: caseId,
              file: a.file,
              type: a.type,
              uploadedBy: hide ? '' : _user.uid,
              uploadedByName: hide ? c.senderLabel : _user.displayName,
              durationMs: a.durationMs,
            ),
        ]));
      }
      await _sendMessage(
        caseId,
        CaseMessage(
          id: '',
          authorId: hide ? '' : _user.uid,
          authorName: hide ? c.senderLabel : _user.displayName,
          authorRole:
              isReporter ? CaseAuthorRole.reporter : CaseAuthorRole.recipient,
          kind: CaseMessageKind.message,
          text: trimmed.isEmpty ? null : trimmed,
          attachments: uploaded,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    } on Failure catch (e) {
      emit(CaseConversationState.error(e.message));
      return false;
    } catch (_) {
      emit(const CaseConversationState.error('Failed to send your message.'));
      return false;
    } finally {
      _sending = false;
      _emit();
    }
  }

  // ─── Status control (recipient only — header) ──────────────────
  Future<void> changeStatus(CaseStatus to) async {
    final c = _case;
    if (_user == null || c == null || _changing) return;
    if (c.status == to || !c.status.canTransitionTo(to)) return;
    _changing = true;
    _emit();
    try {
      await _changeStatus(caseId, to);
    } on Failure catch (e) {
      emit(CaseConversationState.error(e.message));
    } catch (_) {
      emit(const CaseConversationState.error('Failed to update the case.'));
    } finally {
      _changing = false;
      _emit();
    }
  }

  /// Reopen a closed case → back into discussion.
  Future<void> reopen() => changeStatus(CaseStatus.inDiscussion);

  /// Reads the private reporter identity — an admin revealing a confidential
  /// sender. Returns null on failure/absence.
  Future<CaseIdentity?> revealReporter() async {
    try {
      return await _repository.revealReporter(caseId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() {
    _caseSub?.cancel();
    _messagesSub?.cancel();
    return super.close();
  }
}
