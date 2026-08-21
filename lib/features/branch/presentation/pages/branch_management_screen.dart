import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_dialog.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/responsive_card_grid.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/core/widgets/opshub_empty_state.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/app_search_field.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/branch/presentation/pages/branch_geofence_editor_screen.dart';
import 'package:opshub/features/branch/presentation/widgets/branch_form_sheet.dart';

/// Admin → Branches (Phase 9 redesign). Premium branch cards showing the
/// branch's manager, employee count and status, with create / edit /
/// activate-deactivate / soft-delete and a search field.
class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  String _query = '';

  /// branchId → manager display name (first manager found).
  Map<String, String> _managerByBranch = const {};

  /// branchId → number of employees.
  Map<String, int> _employeesByBranch = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BranchCubit>().load();
      _loadStaff();
    });
  }

  Future<void> _loadStaff() async {
    final cubit = context.read<AdminUsersCubit>();
    final managers = await cubit.usersWithRole(UserRole.manager);
    final employees = await cubit.usersWithRole(UserRole.employee);
    if (!mounted) return;
    final managerMap = <String, String>{};
    for (final m in managers) {
      final b = m.branchId;
      if (b != null && b.isNotEmpty && !managerMap.containsKey(b)) {
        managerMap[b] = (m.displayName != null && m.displayName!.isNotEmpty)
            ? m.displayName!
            : m.email;
      }
    }
    final countMap = <String, int>{};
    for (final e in employees) {
      final b = e.branchId;
      if (b != null && b.isNotEmpty) {
        countMap[b] = (countMap[b] ?? 0) + 1;
      }
    }
    setState(() {
      _managerByBranch = managerMap;
      _employeesByBranch = countMap;
    });
  }

  Future<void> _refresh() async {
    await context.read<BranchCubit>().load(forceRefresh: true);
    await _loadStaff();
  }

  List<BranchEntity> _filtered(List<BranchEntity> branches) {
    if (_query.isEmpty) return branches;
    final q = _query.toLowerCase();
    return branches
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            (b.location ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _confirmDelete(BranchEntity branch) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete branch?',
      message: '"${branch.name}" will be archived (soft delete). Existing '
          'shifts, tasks and user assignments are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed && mounted) {
      context.read<BranchCubit>().deleteBranch(branch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Branches',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: _refresh,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBranchFormSheet(
          context: context,
          cubit: context.read<BranchCubit>(),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Branch',
            style: AppTypography.label.copyWith(color: AppColors.onAccent)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                AppSpacing.md, AppSpacing.pagePadding, AppSpacing.sm),
            child: AppSearchField(
              hint: 'Search branches',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: BlocConsumer<BranchCubit, BranchState>(
              listener: (context, state) =>
                  state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
              builder: (context, state) => state.maybeWhen(
                loading: () => const ListSkeleton(),
                loaded: (branches, busy) => _list(branches, busy),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<BranchEntity> branches, bool busy) {
    final filtered = _filtered(branches);
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: filtered.isEmpty
                ? _empty(branches.isEmpty)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.sm,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl * 2,
                    ),
                    children: [
                      ResponsiveCardGrid(
                        runSpacing: 0, // _card carries its own bottom padding
                        ultrawideColumns: 2, // rich cards read best at 2-up max
                        children: [
                          for (var i = 0; i < filtered.length; i++)
                            EntranceFade(
                              delay: staggerDelay(i),
                              child: _card(filtered[i]),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _card(BranchEntity branch) {
    final cubit = context.read<BranchCubit>();
    final manager = _managerByBranch[branch.id];
    final employees = _employeesByBranch[branch.id] ?? 0;
    final statusColor = branch.isActive ? AppColors.success : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BranchAvatar.fromBranch(branch),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch.name,
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if ((branch.location ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(branch.location!,
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              _StatusPill(active: branch.isActive, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.supervisor_account_outlined,
                  label: 'Manager',
                  value: manager ?? 'Unassigned',
                  muted: manager == null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Metric(
                  icon: Icons.groups_outlined,
                  label: 'Employees',
                  value: '$employees',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _btn('Edit', Icons.edit_outlined,
                  () => showBranchFormSheet(
                      context: context, cubit: cubit, existing: branch)),
              _btn(
                branch.hasGeofence ? 'GPS area' : 'Set GPS area',
                branch.hasGeofence
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        BranchGeofenceEditorScreen(branch: branch),
                  ),
                ),
                color: branch.hasGeofence ? null : AppColors.warning,
              ),
              _btn(
                branch.isActive ? 'Deactivate' : 'Activate',
                branch.isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                () => cubit.setActive(branch, !branch.isActive),
                color: branch.isActive ? AppColors.error : AppColors.success,
              ),
              _btn('Delete', Icons.delete_outline_rounded,
                  () => _confirmDelete(branch),
                  color: AppColors.error),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return PremiumButton(
      label: label,
      icon: icon,
      onPressed: onTap,
      tone: color,
    );
  }

  Widget _empty(bool noBranchesAtAll) => OpsHubEmptyState(
        title: noBranchesAtAll ? 'No branches yet' : 'No matches',
        message: noBranchesAtAll
            ? 'Tap "New Branch" to add your first branch.'
            : 'No branches match "$_query".',
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(active ? 'active' : 'inactive',
          style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                const SizedBox(height: 1),
                Text(value,
                    style: AppTypography.label.copyWith(
                      color: muted
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
