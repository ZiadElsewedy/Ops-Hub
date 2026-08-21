import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'branch_state.dart';

/// Admin branch management (Phase 5). Calls [BranchRepository] directly (the
/// admin module has no use-case layer — see PROJECT_CONTEXT). Keeps the list
/// visible during mutations and restores it on error.
class BranchCubit extends Cubit<BranchState> {
  final BranchRepository _repository;

  BranchCubit(this._repository) : super(const BranchState.initial());

  List<BranchEntity> get _branches =>
      state.maybeWhen(loaded: (b, _) => b, orElse: () => const []);

  /// Resolves a branchId → its [BranchEntity] from the loaded list (the app-wide
  /// **branch directory**, so any surface can show a [BranchAvatar] / name from
  /// just an id). Null until [load]/[loadIfNeeded] completes or if not found.
  BranchEntity? branchById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final b in _branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Loads the branch list once if it isn't already loaded — cheap (the repo
  /// caches it). Lets branch-identity surfaces resolve ids without each owning a
  /// fetch; safe to call from anywhere on entry.
  Future<void> loadIfNeeded() async {
    final hasData =
        state.maybeWhen(loaded: (_, _) => true, orElse: () => false);
    if (!hasData) await load();
  }

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  Future<void> load({bool forceRefresh = false}) async {
    emit(const BranchState.loading());
    try {
      emit(BranchState.loaded(
          await _repository.getBranches(forceRefresh: forceRefresh)));
    } on Failure catch (e) {
      emit(BranchState.error(e.message));
    } catch (_) {
      emit(const BranchState.error('Failed to load branches.'));
    }
  }

  Future<void> createBranch({
    required String name,
    String? location,
    bool managersCanClock = true,
    bool salesTargetEnabled = false,
  }) =>
      _mutate(() => _repository.createBranch(
            BranchEntity(
              id: '',
              name: name,
              location: location,
              managersCanClock: managersCanClock,
              salesTargetEnabled: salesTargetEnabled,
            ),
          ));

  Future<void> editBranch(BranchEntity branch) =>
      _mutate(() => _repository.updateBranch(branch));

  Future<void> setActive(BranchEntity branch, bool isActive) =>
      _mutate(() => _repository.setBranchActive(branch.id, isActive));

  Future<void> deleteBranch(BranchEntity branch) =>
      _mutate(() => _repository.deleteBranch(branch.id));

  /// Sets a branch's attendance [geofence] (the admin GPS-area editor). Written
  /// via the dedicated `setGeofence` path so it never clobbers other branch
  /// fields; the list refreshes so the employee flow resolves it immediately.
  Future<void> setGeofence(String branchId, BranchGeofence geofence) =>
      _mutate(() => _repository.setGeofence(branchId, geofence));

  /// Uploads a branch logo/cover (§8 Branch Media), then refreshes the list so
  /// the new media shows everywhere. Returns the download URL (the form sheet
  /// updates its live preview with it), or null on failure (error surfaced via
  /// state). Does not block the list with `busy` — the upload UI owns its own
  /// spinner.
  Future<String?> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  }) async {
    try {
      final url =
          await _repository.uploadBranchImage(branchId, file, isLogo: isLogo);
      await load(forceRefresh: true);
      return url;
    } on Failure catch (e) {
      emit(BranchState.error(e.message));
      emit(BranchState.loaded(_branches));
      return null;
    } catch (_) {
      emit(const BranchState.error('Failed to upload image. Please try again.'));
      emit(BranchState.loaded(_branches));
      return null;
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = _branches;
    emit(BranchState.loaded(prev, busy: true));
    try {
      await action();
      emit(BranchState.loaded(await _repository.getBranches()));
    } on Failure catch (e) {
      emit(BranchState.error(e.message));
      emit(BranchState.loaded(prev));
    } catch (_) {
      emit(const BranchState.error('Something went wrong. Please try again.'));
      emit(BranchState.loaded(prev));
    }
  }
}
