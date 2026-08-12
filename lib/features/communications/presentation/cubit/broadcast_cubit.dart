import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/broadcast_audience.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/communications/domain/broadcast_permissions.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_repository.dart';
import 'package:drop/features/communications/domain/usecases/send_broadcast.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_state.dart';

/// Drives the Communications Center. A **hybrid** cubit, matching `TaskCubit`:
/// the write (`send`) goes through the [SendBroadcast] use case (→ the callable
/// `sendBroadcast` Cloud Function), while the live feed subscribes to
/// [BroadcastRepository.watchBroadcasts] directly (the documented stream-access
/// convention).
///
/// The sent broadcast appears in the feed via the same stream — no manual
/// refetch. WHO may send what is validated client-side here ([BroadcastPermissions],
/// defense-in-depth + UI affordance) and enforced authoritatively by the Cloud
/// Function + `firestore.rules`.
class BroadcastCubit extends Cubit<BroadcastState> {
  final BroadcastRepository _repository;
  final SendBroadcast _sendBroadcast;

  /// Picker support for the Compose screen — the branch selector + the
  /// individual-recipient list (mirrors `TaskCubit.branches` / `branchEmployees`,
  /// the documented repo-direct picker convention).
  final BranchRepository _branchRepository;
  final GetUsersByBranch _getUsersByBranch;

  BroadcastCubit({
    required this._repository,
    required this._sendBroadcast,
    required this._branchRepository,
    required this._getUsersByBranch,
  }) : super(const BroadcastState.initial());

  StreamSubscription<List<BroadcastEntity>>? _sub;
  bool _hasSnapshot = false;

  List<BroadcastEntity> get _broadcasts =>
      state.maybeWhen(loaded: (b, _) => b, orElse: () => const []);

  bool get _sending =>
      state.maybeWhen(loaded: (_, sending) => sending, orElse: () => false);

  /// One-shot fetch of a single broadcast by id — the deep-link fallback for
  /// [BroadcastDetailScreen] when the feed hasn't been loaded (a notification tap
  /// opening `/communications/:id` cold). Returns `null` if it's gone or
  /// unreadable; never throws (the caller shows a safe "unavailable" state).
  Future<BroadcastEntity?> fetchById(String id) async {
    // Prefer the already-loaded feed copy (freshest, zero reads).
    for (final b in _broadcasts) {
      if (b.id == id) return b;
    }
    try {
      return await _repository.getBroadcast(id);
    } catch (e, st) {
      AppLog.error('communications', 'fetchById failed', e, st);
      return null;
    }
  }

  /// Subscribes to the live broadcast feed.
  ///
  /// - [branchId] `null` → admin feed (all branches).
  /// - [branchId] set → branch member feed (their branch + all-branches).
  Future<void> load({String? branchId}) async {
    _hasSnapshot = false;
    emit(const BroadcastState.loading());
    await _sub?.cancel();
    _sub = _repository
        .watchBroadcasts(branchId: branchId)
        .listen(
          (broadcasts) {
            _hasSnapshot = true;
            emit(BroadcastState.loaded(broadcasts, sending: _sending));
          },
          onError: (Object e, StackTrace st) {
            AppLog.error('communications', 'feed stream error', e, st);
            // Only surface if no first snapshot arrived; otherwise keep the last
            // good feed visible (mirrors TaskCubit / BranchOperationsCubit).
            if (!_hasSnapshot) emit(BroadcastState.error(_message(e)));
          },
        );
  }

  /// Sends a broadcast from [sender] to [audience]:
  /// - [BroadcastAudience.allBranches] — every user (admin only).
  /// - [BroadcastAudience.branch] — a branch (admin: any via [branchId]; manager:
  ///   their own; [branchId] defaults to the sender's branch).
  /// - [BroadcastAudience.user] — one individual ([targetUserId] required;
  ///   [targetUserBranchId] is the recipient's branch, used to validate a
  ///   manager send). [category] tags the push for client-side routing.
  ///
  /// Returns the **resolved recipient count** on success (the delivery summary
  /// from the engine), or `null` on validation/permission/transport failure. The
  /// new branch/all broadcast surfaces through the feed stream — no refetch.
  Future<int?> send({
    required UserEntity sender,
    required String title,
    required String message,
    BroadcastAudience audience = BroadcastAudience.allBranches,
    String? branchId,
    String? targetUserId,
    String? targetUserBranchId,
    String category = 'general',
    bool sendsPush = true,

    /// Recipient list for a [BroadcastAudience.custom] send.
    List<String> targetUserIds = const [],

    /// Restricts a branch/all send to one role (''/`all` = everyone).
    String roleFilter = '',
  }) async {
    if (_sending) return null;

    final trimmedTitle = title.trim();
    final trimmedMessage = message.trim();
    if (trimmedTitle.isEmpty || trimmedMessage.isEmpty) {
      _emitError('A broadcast needs a title and a message.');
      return null;
    }

    // Branch broadcasts default to the sender's own branch when unspecified.
    final targetBranch = (branchId ?? '').trim().isNotEmpty
        ? branchId!.trim()
        : (sender.branchId ?? '');
    final target = (targetUserId ?? '').trim();

    // Client-side permission guard (the function re-enforces it authoritatively).
    final denial = BroadcastPermissions.validate(
      role: sender.role,
      audience: audience,
      senderBranchId: sender.branchId,
      targetBranchId: targetBranch,
      targetUserBranchId: targetUserBranchId,
    );
    if (denial != null) {
      _emitError(denial);
      return null;
    }
    if (audience == BroadcastAudience.branch && targetBranch.isEmpty) {
      _emitError('Pick a branch to broadcast to.');
      return null;
    }
    if (audience == BroadcastAudience.user && target.isEmpty) {
      _emitError('Pick a recipient.');
      return null;
    }
    if (audience == BroadcastAudience.custom && targetUserIds.isEmpty) {
      _emitError('Pick at least one recipient.');
      return null;
    }

    final broadcast = BroadcastEntity(
      id: '',
      title: trimmedTitle,
      message: trimmedMessage,
      senderId: sender.uid,
      senderName: _senderName(sender),
      senderRole: sender.role,
      audience: audience,
      branchId: audience == BroadcastAudience.branch ? targetBranch : null,
      targetUserId: audience == BroadcastAudience.user ? target : null,
      category: category.trim().isEmpty ? 'general' : category.trim(),
      sendsPush: sendsPush,
    );

    final prev = _broadcasts;
    emit(BroadcastState.loaded(prev, sending: true));
    try {
      final sent = await _sendBroadcast(
        broadcast,
        targetUserIds: audience == BroadcastAudience.custom
            ? targetUserIds
            : const [],
        roleFilter: roleFilter,
      );
      // Keep the feed visible; the stream emits the new broadcast (branch/all).
      emit(BroadcastState.loaded(_broadcasts));
      return sent.recipientCount ?? 0;
    } on Failure catch (e) {
      _emitError(e.message);
      return null;
    } catch (_) {
      _emitError('Could not send the broadcast. Please try again.');
      return null;
    }
  }

  /// Re-sends an existing broadcast as a fresh one (Repeat Now), reusing its
  /// audience / category / priority / channel. Returns the new recipient count,
  /// or null on failure. A manager repeating a direct message targets the same
  /// in-branch recipient, so [targetUserBranchId] defaults to the sender's branch.
  Future<int?> repeatNow({
    required UserEntity sender,
    required BroadcastEntity source,
  }) => send(
    sender: sender,
    title: source.title,
    message: source.message,
    audience: source.audience,
    branchId: source.branchId,
    targetUserId: source.targetUserId,
    targetUserBranchId: sender.role.isManager ? sender.branchId : null,
    category: source.category,
    sendsPush: source.sendsPush,
  );

  /// Archives ([archived] true) / unarchives a broadcast. The feed stream
  /// re-emits with the updated flag; an error keeps the current feed visible.
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _repository.setArchived(id, archived);
    } on Failure catch (e) {
      _emitError(e.message);
    } catch (_) {
      _emitError('Could not update the broadcast. Please try again.');
    }
  }

  /// Applies one lifecycle change to a feed selection. The writes stay on the
  /// existing repository contract (one document per call); failure is surfaced
  /// once and the caller can keep the selection intact for a retry.
  Future<bool> setArchivedMany(Iterable<String> ids, bool archived) async {
    try {
      for (final id in ids) {
        await _repository.setArchived(id, archived);
      }
      return true;
    } on Failure catch (e) {
      _emitError(e.message);
      return false;
    } catch (_) {
      _emitError('Could not update the selected broadcasts. Please try again.');
      return false;
    }
  }

  /// Permanently deletes a broadcast (removes the `broadcasts/{id}` doc). The
  /// feed stream re-emits without it; an error keeps the current feed visible.
  /// Rules permit this only for an admin, the original sender, or the
  /// owning-branch manager.
  Future<void> deleteBroadcast(String id) async {
    try {
      await _repository.delete(id);
    } on Failure catch (e) {
      _emitError(e.message);
    } catch (_) {
      _emitError('Could not delete the broadcast. Please try again.');
    }
  }

  /// Permanently deletes every selected broadcast. This deliberately uses the
  /// repository's existing permission-checked single-document delete instead
  /// of introducing a second backend path.
  Future<bool> deleteBroadcasts(Iterable<String> ids) async {
    try {
      for (final id in ids) {
        await _repository.delete(id);
      }
      return true;
    } on Failure catch (e) {
      _emitError(e.message);
      return false;
    } catch (_) {
      _emitError('Could not delete the selected broadcasts. Please try again.');
      return false;
    }
  }

  /// Surface an error without losing the current feed (when one is loaded).
  void _emitError(String message) {
    final prev = _broadcasts;
    emit(BroadcastState.error(message));
    if (_hasSnapshot) emit(BroadcastState.loaded(prev));
  }

  String _senderName(UserEntity user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email.trim();
    return email.isNotEmpty ? email : 'Drop Operations';
  }

  String _message(Object e) =>
      e is Failure ? e.message : 'Could not load broadcasts. Please try again.';

  // ─── Picker support (Compose screen) ───────────────────────────
  /// Active branches for the admin's audience branch selector.
  Future<List<BranchEntity>> branches() async {
    try {
      final list = await _branchRepository.getBranches();
      return list.where((b) => b.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Active members of [branchId] for the individual-recipient picker.
  Future<List<UserEntity>> branchUsers(String branchId) async {
    if (branchId.trim().isEmpty) return const [];
    try {
      final users = await _getUsersByBranch(branchId.trim());
      return users.where((u) => u.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Drops the live broadcast feed and returns to [BroadcastState.initial]. This
  /// cubit is an app-wide singleton (it outlives the session), so on sign-out /
  /// single-active-session eviction its `watchBroadcasts` listener would keep
  /// running against a signed-out user. Wired into
  /// `AppDependencies.clearUserScopedState()`.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _hasSnapshot = false;
    if (!isClosed) emit(const BroadcastState.initial());
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
