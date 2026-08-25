import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/notification_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/swap_status.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/notifications/domain/usecases/notify_swap_event.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/schedule/domain/swap_eligibility.dart';
import 'shift_swap_state.dart';

/// Drives the shift-swap workflow (Phase 7, **realtime** since 2026-06-26). An
/// employee requests a swap on one of their slots; the target coworker approves;
/// the branch manager approves — which rewrites the schedule (via the
/// `approveSwap` Cloud Function). The cubit **subscribes to a live Firestore
/// stream** scoped to the view: an employee sees swaps involving them
/// ([loadMine]); a manager sees their branch's queue ([loadBranch]); an admin
/// every branch ([loadAll]). So an accept / reject / approve reflects on every
/// open surface instantly — no manual refresh. Calls [ScheduleRepository]
/// directly (no use-case layer).
enum SwapScope { mine, branch, all }

class ShiftSwapCubit extends Cubit<ShiftSwapState> {
  final ScheduleRepository _repository;
  final NotifySwapEvent _notifySwap;
  final GetUsersByBranch _getUsersByBranch;

  /// Subscription context — which slice of swaps is being streamed.
  SwapScope _scope = SwapScope.mine;
  String _key = '';

  StreamSubscription<List<ShiftSwapEntity>>? _sub;

  /// Identity of the active subscription (`scope:key`) — the idempotency guard.
  String? _subKey;

  /// Last streamed list + in-flight flag, preserved across a mutation's emits.
  List<ShiftSwapEntity> _latest = const [];
  bool _busy = false;

  ShiftSwapCubit(this._repository, this._notifySwap, this._getUsersByBranch)
      : super(const ShiftSwapState.initial());

  String _scopeKey(SwapScope s, String k) => '${s.name}:$k';

  /// Employee view — swaps where [uid] is requester or target.
  Future<void> loadMine(String uid, {bool force = false}) =>
      _subscribe(SwapScope.mine, uid, force);

  /// Manager view — the branch's swap queue.
  Future<void> loadBranch(String branchId, {bool force = false}) =>
      _subscribe(SwapScope.branch, branchId, force);

  /// Admin view — every branch's swap queue.
  Future<void> loadAll({bool force = false}) =>
      _subscribe(SwapScope.all, '', force);

  /// Re-subscribe the current scope (pull-to-refresh / error retry).
  Future<void> refresh() => _subscribe(_scope, _key, true);

  /// True when there's nothing to stream — an empty key for the mine/branch
  /// scopes (the all scope needs no key).
  bool _noTarget(SwapScope scope, String key) =>
      scope != SwapScope.all && key.isEmpty;

  Future<void> _subscribe(SwapScope scope, String key, bool force) async {
    final newKey = _scopeKey(scope, key);
    final errored = state.maybeWhen(error: (_) => true, orElse: () => false);
    // Idempotent: already streaming this exact scope (and not in an error state)
    // → no-op, so revisiting a screen never re-subscribes or flashes a skeleton.
    if (!force && _subKey == newKey && _sub != null && !errored) return;

    _scope = scope;
    _key = key;
    _subKey = newKey;

    await _sub?.cancel();
    _sub = null;

    if (_noTarget(scope, key)) {
      _latest = const [];
      _busy = false;
      emit(const ShiftSwapState.loaded([]));
      return;
    }

    emit(const ShiftSwapState.loading());
    _sub = _streamFor(scope, key).listen(
      (swaps) {
        _latest = swaps;
        emit(ShiftSwapState.loaded(swaps, busy: _busy));
      },
      onError: (Object e) {
        emit(ShiftSwapState.error(
            e is Failure ? e.message : 'Failed to load swap requests.'));
      },
    );
  }

  Stream<List<ShiftSwapEntity>> _streamFor(SwapScope scope, String key) {
    switch (scope) {
      case SwapScope.mine:
        return _repository.watchEmployeeSwaps(key);
      case SwapScope.branch:
        return _repository.watchBranchSwaps(key);
      case SwapScope.all:
        return _repository.watchAllSwaps();
    }
  }

  // ── Employee actions ───────────────────────────────────────────
  Future<void> requestSwap({
    required String branchId,
    required DateTime weekStart,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String requesterId,
    String? requesterName,
    required String targetId,
    String? targetName,
    String? note,
  }) async {
    // Guard: can't swap with yourself.
    if (requesterId == targetId) {
      _reject("You can't swap a shift with yourself.");
      return;
    }
    // Guard: one open request at a time (no simultaneous pending swaps).
    final hasOpen = _latest
        .any((s) => s.requesterId == requesterId && !s.status.isResolved);
    if (hasOpen) {
      _reject('You already have a pending swap request. '
          'Resolve it before requesting another.');
      return;
    }
    // Authoritative client gate (spec §2): no swaps for past/in-progress shifts.
    if (!SwapEligibility.isRequestable(weekStart, day, shift)) {
      _reject(SwapEligibility.pastShiftMessage);
      return;
    }
    await _mutate(() async {
      final created = await _repository.createSwap(ShiftSwapEntity(
        id: '',
        branchId: branchId,
        weekStart: weekStart,
        day: day,
        shift: shift,
        requesterId: requesterId,
        requesterName: requesterName,
        targetId: targetId,
        targetName: targetName,
        note: note,
      ));
      // Notify the coworker their slot was requested.
      await _notifySwap(
        swap: created,
        type: NotificationType.swapRequested,
        actorId: requesterId,
        recipients: [targetId],
      );
    });
  }

  /// One-shot fetch of every **open** swap request (not resolved), across all
  /// branches — a non-emitting helper kept for callers that want a snapshot count
  /// without subscribing (the live admin surfaces use [loadAll] + the stream).
  Future<List<ShiftSwapEntity>> pendingSwaps() async {
    try {
      final all = await _repository.getAllSwaps();
      return all.where((s) => !s.status.isResolved).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Target coworker accepts → awaiting manager. Notifies the branch's
  /// manager(s) that a swap needs review (the spec's "pending swap approval").
  Future<void> coworkerApprove(ShiftSwapEntity swap) => _mutate(() async {
        await _repository.updateSwapStatus(
            swapId: swap.id, status: SwapStatus.employeeApproved);
        final managers = await _branchManagers(swap.branchId);
        await _notifySwap(
          swap: swap,
          type: NotificationType.swapAccepted,
          actorId: swap.targetId,
          recipients: managers,
        );
      });

  /// Decline the swap (coworker declines, or manager rejects). [actorId] is the
  /// rejector (excluded from the notification); both employees are told.
  Future<void> reject(ShiftSwapEntity swap, {required String actorId}) =>
      _mutate(() async {
        await _repository.updateSwapStatus(
            swapId: swap.id, status: SwapStatus.rejected);
        await _notifySwap(
          swap: swap,
          type: NotificationType.swapRejected,
          actorId: actorId,
          recipients: [swap.requesterId, swap.targetId],
        );
      });

  /// Requester withdraws their own pending request → `cancelled` (distinct from a
  /// reject). No notification — they're cancelling their own ask.
  Future<void> cancelSwap(ShiftSwapEntity swap) => _mutate(() => _repository
      .updateSwapStatus(swapId: swap.id, status: SwapStatus.cancelled));

  // ── Manager action ─────────────────────────────────────────────
  /// Manager/admin approves → the `approveSwap` callable exchanges the schedule
  /// **and writes both employees' `swapApproved` notifications itself**.
  ///
  /// Deliberately no client-side [NotifySwapEvent] here: the server owns the
  /// roster exchange, so it must own the notice. Sending it from here as well
  /// would notify both employees twice, and sending it *only* from here meant a
  /// manager whose app died after the callable returned left two schedules
  /// swapped and nobody told.
  Future<void> managerApprove(ShiftSwapEntity swap) =>
      _mutate(() => _repository.managerApproveSwap(swap));

  /// The branch's manager uids (the swap reviewers). Best-effort.
  Future<List<String>> _branchManagers(String branchId) async {
    try {
      final users = await _getUsersByBranch(branchId);
      return users.where((u) => u.role.isManager).map((u) => u.uid).toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Internals ──────────────────────────────────────────────────
  /// Emits a one-shot error (for the snackbar listener) then restores the list.
  void _reject(String message) {
    emit(ShiftSwapState.error(message));
    emit(ShiftSwapState.loaded(_latest, busy: _busy));
  }

  /// Runs a write [action]; the live stream reflects the result (no refetch).
  /// [_busy] gates concurrent writes + drives the inline progress bar.
  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    emit(ShiftSwapState.loaded(_latest, busy: true));
    try {
      await action();
    } on Failure catch (e) {
      emit(ShiftSwapState.error(e.message));
    } catch (_) {
      emit(const ShiftSwapState.error('Something went wrong. Please try again.'));
    } finally {
      _busy = false;
      emit(ShiftSwapState.loaded(_latest, busy: false));
    }
  }

  /// Drops the user-scoped swap stream and its cached page, returning the cubit
  /// to [ShiftSwapState.initial]. Called on sign-out and on
  /// single-active-session eviction. `_subKey` is cleared too, so the next
  /// user's first `watch` is not short-circuited as "already subscribed to this
  /// scope".
  void reset() {
    _sub?.cancel();
    _sub = null;
    _subKey = null;
    _scope = SwapScope.mine;
    _key = '';
    _latest = const [];
    _busy = false;
    if (!isClosed) emit(const ShiftSwapState.initial());
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
