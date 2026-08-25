import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/responsive_card_grid.dart';
import 'package:opshub/core/widgets/app_search_field.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:opshub/features/admin/presentation/widgets/admin_user_card.dart';

typedef AdminUserActions = List<Widget> Function(
    BuildContext context, UserEntity user);

/// Reusable scaffolded list for an admin user slice (managers / pending).
/// Loads the [filter] on init, resolves branch names for display, supports
/// **search** by name/email (Phase 9), and renders each user via [AdminUserCard]
/// with screen-supplied [actionsBuilder]. Loading / empty / no-results states
/// are all handled.
class AdminUsersListView extends StatefulWidget {
  const AdminUsersListView({
    super.key,
    required this.title,
    required this.filter,
    required this.emptyMessage,
    required this.actionsBuilder,
    this.subtitle,
    this.searchHint = 'Search by name or email',
    this.onAdd,
    this.addLabel,
  });

  final String title;
  final String? subtitle;
  final AdminUserFilter filter;
  final String emptyMessage;
  final AdminUserActions actionsBuilder;
  final String searchHint;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  State<AdminUsersListView> createState() => _AdminUsersListViewState();
}

class _AdminUsersListViewState extends State<AdminUsersListView> {
  Map<String, String> _branchNames = const {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersCubit>().load(widget.filter);
      _loadBranchNames();
    });
  }

  Future<void> _loadBranchNames() async {
    final branches = await context.read<AdminUsersCubit>().branches();
    if (mounted) {
      setState(() => _branchNames = {for (final b in branches) b.id: b.name});
    }
  }

  List<UserEntity> _filtered(List<UserEntity> users) {
    if (_query.isEmpty) return users;
    final q = _query.toLowerCase();
    return users.where((u) {
      final name = (u.displayName ?? '').toLowerCase();
      return name.contains(q) || u.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: () => context.read<AdminUsersCubit>().refresh(),
        ),
      ],
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onAdd,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(widget.addLabel ?? 'Add',
                  style: AppTypography.label
                      .copyWith(color: AppColors.onPrimary)),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                AppSpacing.md, AppSpacing.pagePadding, AppSpacing.sm),
            child: AppSearchField(
              hint: widget.searchHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: BlocConsumer<AdminUsersCubit, AdminUsersState>(
              listener: (context, state) =>
                  state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
              builder: (context, state) => state.maybeWhen(
                loading: () => const ListSkeleton(),
                loaded: (users, busy) => _list(users, busy),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<UserEntity> users, bool busy) {
    final filtered = _filtered(users);
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<AdminUsersCubit>().refresh(),
            child: filtered.isEmpty
                ? _empty(users.isEmpty)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.sm,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl * 2,
                    ),
                    children: [
                      ResponsiveCardGrid(
                        runSpacing: 0, // AdminUserCard carries its own bottom margin
                        ultrawideColumns: 2, // rich cards read best at 2-up max
                        children: [
                          for (var i = 0; i < filtered.length; i++)
                            EntranceFade(
                              delay: staggerDelay(i),
                              child: AdminUserCard(
                                user: filtered[i],
                                branchLabel: filtered[i].branchId == null
                                    ? null
                                    : _branchNames[filtered[i].branchId],
                                actions:
                                    widget.actionsBuilder(context, filtered[i]),
                              ),
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

  Widget _empty(bool noUsersAtAll) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        noUsersAtAll
                            ? Icons.groups_outlined
                            : Icons.search_off_rounded,
                        size: 44,
                        color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                        noUsersAtAll
                            ? widget.emptyMessage
                            : 'No matches for "$_query".',
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
