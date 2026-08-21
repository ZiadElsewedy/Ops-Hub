import 'package:opshub/features/branch/domain/entities/branch_entity.dart';

/// The branches a sales surface may show: those that have opted in, by name.
///
/// A branch with `salesTargetEnabled == false` runs no sales workflow, so it is
/// **absent**, not greyed out — the admin overview and the Admin Home summary
/// both go through here so they can never disagree about who is in scope.
///
/// Soft-deleted branches are excluded too: a closed branch's month is history,
/// not something to track against today.
List<BranchEntity> salesEnabledBranches(Iterable<BranchEntity> branches) =>
    [
      for (final branch in branches)
        if (branch.salesTargetEnabled && !branch.isDeleted) branch,
    ]..sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
