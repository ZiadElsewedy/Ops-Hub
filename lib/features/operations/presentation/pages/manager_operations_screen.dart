import 'package:flutter/material.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/features/operations/presentation/pages/branch_operations_screen.dart';

/// The manager's Operations tab — the Branch Operations cockpit scoped to their
/// own branch. A thin wrapper that resolves the signed-in manager's `branchId`
/// and hands it to [BranchOperationsScreen] (which surfaces a friendly error if
/// the account has no branch assigned yet). Admins reach the same cockpit from
/// the branch overview drill instead.
class ManagerOperationsScreen extends StatelessWidget {
  const ManagerOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return BranchOperationsScreen(branchId: user?.branchId ?? '');
  }
}
