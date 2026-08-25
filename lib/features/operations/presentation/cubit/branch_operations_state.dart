import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/operations/domain/branch_workload.dart';
import 'package:opshub/features/operations/domain/shift_filter.dart';

part 'branch_operations_state.freezed.dart';

/// State for the Branch Operations cockpit. The cubit keeps the raw inputs
/// (tasks · branch users · today's roster) privately and re-derives the
/// [BranchWorkload] on every task-stream tick **and** on every shift-filter
/// change — so flipping the filter never refetches.
@freezed
class BranchOperationsState with _$BranchOperationsState {
  const factory BranchOperationsState.initial() = _Initial;

  /// First load (header + cards skeleton).
  const factory BranchOperationsState.loading() = _Loading;

  /// Derived cockpit for [branchId] under [filter]. [branchName] / [directory]
  /// are passed through for the UI (title + assignee resolution); they fill in
  /// once the branch users have loaded.
  const factory BranchOperationsState.loaded({
    required String branchId,
    required BranchWorkload workload,
    @Default(ShiftFilter.all) ShiftFilter filter,
    String? branchName,
    @Default(<String, UserEntity>{}) Map<String, UserEntity> directory,
  }) = _Loaded;

  /// Transient/fatal load failure (surfaced as a message; the screen offers a
  /// retry). Stream errors after a first good emit are logged, not surfaced.
  const factory BranchOperationsState.error(String message) = _Error;
}
