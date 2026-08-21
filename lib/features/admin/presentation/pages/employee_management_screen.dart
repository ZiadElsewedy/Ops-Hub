import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/features/admin/domain/entities/user_compensation.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/widgets/app_context_menu.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_search_field.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:opshub/features/admin/presentation/employee_metrics.dart';
import 'package:opshub/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:opshub/features/admin/presentation/widgets/admin_user_sheets.dart';
import 'package:opshub/features/admin/presentation/widgets/compensation_fields.dart';
import 'package:opshub/features/admin/presentation/widgets/employee_card.dart';
import 'package:opshub/features/admin/presentation/widgets/user_inspector_panel.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';

const _kAll = '__all__';
const _kNone = '__none__';

enum _StatusFilter { all, active, inactive }

enum _EmployeeSort { nameAscending, nameDescending, newest, branch }

enum _EmployeeView { list, grid }

/// Admin → Employees. List employees, filter by branch, change branch, activate
/// or deactivate, and view details.
class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  String _branchFilter = _kAll;
  _StatusFilter _statusFilter = _StatusFilter.all;
  // This query is employee-only, so the useful enterprise "Role" facet is the
  // existing job-position field (Cashier, Supervisor, …), not UserRole.
  String _roleFilter = _kAll;
  _EmployeeSort _sort = _EmployeeSort.nameAscending;
  _EmployeeView _view = _EmployeeView.list;
  String _query = '';
  List<BranchEntity> _branches = const [];
  Map<String, String> _branchNames = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersCubit>().load(AdminUserFilter.employees);
      _loadBranches();
      // The admin task stream feeds the Details inspector's performance block.
      // Load it only if it isn't already streaming (it usually is, from Admin
      // Home) so the inspector has data the moment it opens.
      final taskCubit = context.read<TaskCubit>();
      final loaded = taskCubit.state.maybeWhen(
        loaded: (_, _, _, _, _) => true,
        orElse: () => false,
      );
      final user = context.currentUser;
      if (!loaded && user != null) taskCubit.load(user);
    });
  }

  Future<void> _loadBranches() async {
    final branches = await context.read<AdminUsersCubit>().branches();
    if (mounted) {
      setState(() {
        _branches = branches;
        _branchNames = {for (final b in branches) b.id: b.name};
      });
    }
  }

  List<UserEntity> _filter(List<UserEntity> users) {
    Iterable<UserEntity> out = users;
    // Branch.
    switch (_branchFilter) {
      case _kAll:
        break;
      case _kNone:
        out = out.where((u) => u.branchId == null || u.branchId!.isEmpty);
      default:
        out = out.where((u) => u.branchId == _branchFilter);
    }
    // Status.
    switch (_statusFilter) {
      case _StatusFilter.all:
        break;
      case _StatusFilter.active:
        out = out.where((u) => u.isActive);
      case _StatusFilter.inactive:
        out = out.where((u) => !u.isActive);
    }
    // Role / position. The source already contains employees only, so this
    // filters the actual job title rather than offering a no-op access-role UI.
    if (_roleFilter != _kAll) {
      out = out.where((u) => _positionLabel(u) == _roleFilter);
    }
    // Search.
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      out = out.where(
        (u) =>
            (u.displayName ?? '').toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q),
      );
    }
    final result = out.toList(growable: false);
    result.sort(_compareUsers);
    return result;
  }

  int _compareUsers(UserEntity a, UserEntity b) {
    final aName = _displayName(a).toLowerCase();
    final bName = _displayName(b).toLowerCase();
    switch (_sort) {
      case _EmployeeSort.nameAscending:
        return aName.compareTo(bName);
      case _EmployeeSort.nameDescending:
        return bName.compareTo(aName);
      case _EmployeeSort.newest:
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      case _EmployeeSort.branch:
        final byBranch = _branchLabel(a).compareTo(_branchLabel(b));
        return byBranch != 0 ? byBranch : aName.compareTo(bName);
    }
  }

  String _displayName(UserEntity user) {
    final name = user.displayName?.trim() ?? '';
    return name.isNotEmpty ? name : user.email;
  }

  String _branchLabel(UserEntity user) {
    final id = user.branchId?.trim() ?? '';
    if (id.isEmpty) return 'No branch';
    return _branchNames[id] ?? id;
  }

  String _positionLabel(UserEntity user) {
    final position = user.position?.trim() ?? '';
    return position.isNotEmpty ? position : 'Unspecified';
  }

  List<String> _positions(List<UserEntity> users) {
    final positions = <String>{};
    for (final user in users) {
      final position = user.position?.trim() ?? '';
      if (position.isNotEmpty) positions.add(position);
    }
    final result = positions.toList(growable: false);
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminUsersCubit, AdminUsersState>(
      listener: (context, state) =>
          state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
      builder: (context, state) {
        final desktop = context.isDesktop;
        final users = state.maybeWhen(
          loaded: (users, _) => users,
          orElse: () => null,
        );
        return AdaptiveScaffold(
          title: 'Employees',
          subtitle: users == null
              ? 'Manage employee access and operations'
              : _headerSummary(users),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Refresh employees',
              onPressed: () => context.read<AdminUsersCubit>().refresh(),
            ),
            if (desktop) ...[
              const SizedBox(width: AppSpacing.sm),
              PremiumButton(
                label: 'Create Employee',
                icon: Icons.person_add_alt_1_rounded,
                style: PremiumButtonStyle.filled,
                onPressed: () => context.push(RouteNames.adminCreateAccount),
              ),
            ],
          ],
          compactDesktopHeader: true,
          // On desktop the single primary action belongs in the persistent page
          // header. Mobile retains the existing FAB reachability.
          floatingActionButton: desktop
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.push(RouteNames.adminCreateAccount),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    'Create Employee',
                    style: AppTypography.label.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
          body: state.maybeWhen(
            initial: () => const ListSkeleton(cardHeight: 152),
            loading: () => const ListSkeleton(cardHeight: 152),
            loaded: _body,
            orElse: () => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  String _headerSummary(List<UserEntity> users) {
    final active = users.where((user) => user.isActive).length;
    final employeeLabel = users.length == 1 ? 'Employee' : 'Employees';
    final branchLabel = _branches.length == 1 ? 'Branch' : 'Branches';
    return '${users.length} $employeeLabel · $active Active · '
        '${_branches.length} $branchLabel';
  }

  Widget _body(List<UserEntity> users, bool busy) {
    final filtered = _filter(users);
    // The directory itself is identity-only, so it deliberately does not watch
    // the task stream: performance is computed on demand when Details opens.
    // That keeps a large employee list from rebuilding on every task tick.
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        _filterBar(users),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<AdminUsersCubit>().refresh(),
            child: filtered.isEmpty
                ? _empty(users.isEmpty)
                : _employeeDirectory(filtered),
          ),
        ),
      ],
    );
  }

  /// Lazily builds the directory. The earlier eager card grid constructed every
  /// card (and animation controller) at once; this keeps the same data and
  /// actions while remaining responsive for a large employee directory.
  Widget _employeeDirectory(List<UserEntity> users) {
    final useGrid = context.isDesktop && _view == _EmployeeView.grid;
    return CustomScrollView(
      key: const PageStorageKey('admin_employees_directory'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.sm,
            AppSpacing.pagePadding,
            AppSpacing.xxxl,
          ),
          sliver: useGrid
              ? SliverLayoutBuilder(
                  builder: (context, constraints) {
                    // A standard SliverGrid requires a fixed row extent. That
                    // is unsafe here because compact cards intentionally wrap
                    // their action row at narrow widths or larger text scales.
                    // Lazily building two natural-height cards per row retains
                    // the desktop grid affordance without clipping either card.
                    final twoColumns = constraints.crossAxisExtent >= 840;
                    return twoColumns
                        ? _twoColumnEmployeeSliver(users)
                        : _employeeListSliver(users);
                  },
                )
              : _employeeListSliver(users),
        ),
      ],
    );
  }

  Widget _employeeListSliver(List<UserEntity> users) => SliverList.builder(
    itemCount: users.length,
    itemBuilder: (context, index) => Padding(
      padding: EdgeInsets.only(
        bottom: index == users.length - 1 ? 0 : AppSpacing.sm,
      ),
      child: _employeeTile(users[index]),
    ),
  );

  Widget _twoColumnEmployeeSliver(List<UserEntity> users) {
    final rowCount = (users.length + 1) ~/ 2;
    return SliverList.builder(
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        final firstIndex = rowIndex * 2;
        final secondIndex = firstIndex + 1;
        final hasSecond = secondIndex < users.length;
        return Padding(
          padding: EdgeInsets.only(
            bottom: rowIndex == rowCount - 1 ? 0 : AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _employeeTile(users[firstIndex])),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: hasSecond
                    ? _employeeTile(users[secondIndex])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _employeeTile(UserEntity user) {
    return GestureDetector(
      // Right-click remains a complete alternative to the visible action row.
      onSecondaryTapDown: (details) =>
          _showContextMenu(user, details.globalPosition),
      child: EmployeeCard(
        user: user,
        branchLabel: user.branchId == null ? null : _branchNames[user.branchId],
        onTap: () => _showDetails(user),
        actions: _actions(user),
      ),
    );
  }

  Widget _filterBar(List<UserEntity> users) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: AppSearchField(
                hint: 'Search employees',
                height: 40,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _branchFilterMenu(),
            const SizedBox(width: AppSpacing.sm),
            _roleFilterMenu(users),
            const SizedBox(width: AppSpacing.sm),
            _statusFilterMenu(),
            const SizedBox(width: AppSpacing.sm),
            _sortMenu(),
            if (context.isDesktop) ...[
              const SizedBox(width: AppSpacing.sm),
              _viewMenu(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _branchFilterMenu() {
    final label = switch (_branchFilter) {
      _kAll => 'Branch',
      _kNone => 'No branch',
      _ => _branchNames[_branchFilter] ?? 'Branch',
    };
    return _DirectoryMenu<String>(
      label: label,
      tooltip: 'Filter by branch',
      icon: Icons.store_mall_directory_outlined,
      selected: _branchFilter,
      options: [
        const _DirectoryMenuOption(value: _kAll, label: 'All branches'),
        const _DirectoryMenuOption(value: _kNone, label: 'No branch'),
        for (final branch in _branches)
          _DirectoryMenuOption(value: branch.id, label: branch.name),
      ],
      onSelected: (value) => setState(() => _branchFilter = value),
    );
  }

  Widget _roleFilterMenu(List<UserEntity> users) => _DirectoryMenu<String>(
    label: _roleFilter == _kAll ? 'Role' : _roleFilter,
    tooltip: 'Filter by job position',
    icon: Icons.badge_outlined,
    selected: _roleFilter,
    options: [
      const _DirectoryMenuOption(value: _kAll, label: 'All roles'),
      for (final position in _positions(users))
        _DirectoryMenuOption(value: position, label: position),
    ],
    onSelected: (value) => setState(() => _roleFilter = value),
  );

  Widget _statusFilterMenu() => _DirectoryMenu<_StatusFilter>(
    label: switch (_statusFilter) {
      _StatusFilter.all => 'Status',
      _StatusFilter.active => 'Active',
      _StatusFilter.inactive => 'Inactive',
    },
    tooltip: 'Filter by account access status',
    icon: Icons.verified_user_outlined,
    selected: _statusFilter,
    options: const [
      _DirectoryMenuOption(value: _StatusFilter.all, label: 'All statuses'),
      _DirectoryMenuOption(value: _StatusFilter.active, label: 'Active'),
      _DirectoryMenuOption(value: _StatusFilter.inactive, label: 'Inactive'),
    ],
    onSelected: (value) => setState(() => _statusFilter = value),
  );

  Widget _sortMenu() => _DirectoryMenu<_EmployeeSort>(
    label: switch (_sort) {
      _EmployeeSort.nameAscending => 'Sort',
      _EmployeeSort.nameDescending => 'Name Z–A',
      _EmployeeSort.newest => 'Newest',
      _EmployeeSort.branch => 'Branch',
    },
    tooltip: 'Sort employees',
    icon: Icons.sort_rounded,
    selected: _sort,
    options: const [
      _DirectoryMenuOption(
        value: _EmployeeSort.nameAscending,
        label: 'Name A–Z',
      ),
      _DirectoryMenuOption(
        value: _EmployeeSort.nameDescending,
        label: 'Name Z–A',
      ),
      _DirectoryMenuOption(value: _EmployeeSort.newest, label: 'Newest'),
      _DirectoryMenuOption(value: _EmployeeSort.branch, label: 'Branch'),
    ],
    onSelected: (value) => setState(() => _sort = value),
  );

  Widget _viewMenu() => _DirectoryMenu<_EmployeeView>(
    label: _view == _EmployeeView.list ? 'View' : 'Grid',
    tooltip: 'Choose employee view',
    icon: _view == _EmployeeView.list
        ? Icons.view_agenda_outlined
        : Icons.grid_view_rounded,
    selected: _view,
    options: const [
      _DirectoryMenuOption(value: _EmployeeView.list, label: 'List'),
      _DirectoryMenuOption(value: _EmployeeView.grid, label: 'Grid'),
    ],
    onSelected: (value) => setState(() => _view = value),
  );

  List<Widget> _actions(UserEntity user) {
    final cubit = context.read<AdminUsersCubit>();
    return [
      AdminActionButton(
        label: 'Details',
        icon: Icons.info_outline_rounded,
        onPressed: () => _showDetails(user),
      ),
      AdminActionButton(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () =>
            showEditDetailsSheet(context: context, cubit: cubit, user: user),
      ),
      EmployeeOverflowMenu(
        employeeName: _displayName(user),
        actions: _secondaryActions(user),
      ),
    ];
  }

  List<EmployeeOverflowAction> _secondaryActions(UserEntity user) {
    final cubit = context.read<AdminUsersCubit>();
    return [
      EmployeeOverflowAction(
        label: 'Change Branch',
        icon: Icons.store_mall_directory_outlined,
        onSelected: () =>
            showAssignBranchSheet(context: context, cubit: cubit, user: user),
      ),
      EmployeeOverflowAction(
        label: 'Position',
        icon: Icons.badge_outlined,
        onSelected: () =>
            showSetPositionSheet(context: context, cubit: cubit, user: user),
      ),
      EmployeeOverflowAction(
        label: 'Reset Password',
        icon: Icons.lock_reset_rounded,
        onSelected: () =>
            showResetAccountSheet(context: context, cubit: cubit, user: user),
      ),
      EmployeeOverflowAction(
        label: user.isActive ? 'Deactivate' : 'Activate',
        icon: user.isActive
            ? Icons.block_rounded
            : Icons.check_circle_outline_rounded,
        destructive: user.isActive,
        onSelected: () => cubit.setActive(user, !user.isActive),
      ),
      EmployeeOverflowAction(
        label: 'Delete Account',
        icon: Icons.delete_forever_outlined,
        destructive: true,
        onSelected: () =>
            confirmAndDeleteAccount(context: context, cubit: cubit, user: user),
      ),
    ];
  }

  void _showContextMenu(UserEntity user, Offset position) {
    final cubit = context.read<AdminUsersCubit>();
    showAppContextMenu(
      context: context,
      position: position,
      items: [
        AppContextMenuItem(
          icon: Icons.info_outline_rounded,
          label: 'Details',
          onSelected: () => _showDetails(user),
        ),
        AppContextMenuItem(
          icon: Icons.edit_outlined,
          label: 'Edit info',
          onSelected: () =>
              showEditDetailsSheet(context: context, cubit: cubit, user: user),
        ),
        for (final action in _secondaryActions(user))
          AppContextMenuItem(
            icon: action.icon,
            label: action.label,
            destructive: action.destructive,
            onSelected: action.onSelected,
          ),
      ],
    );
  }

  void _showDetails(UserEntity user) {
    // Desktop: the richer slide-over inspector; mobile keeps the dialog.
    if (context.isDesktop) {
      final tasks = context.read<TaskCubit>().state.maybeWhen(
        loaded: (t, _, _, _, _) => t,
        orElse: () => const <TaskEntity>[],
      );
      showUserInspector(
        context: context,
        cubit: context.read<AdminUsersCubit>(),
        user: user,
        branchLabel: user.branchId == null ? null : _branchNames[user.branchId],
        metrics:
            computeEmployeeMetrics(tasks)[user.uid] ?? const EmployeeMetrics(),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(
          (user.displayName != null && user.displayName!.isNotEmpty)
              ? user.displayName!
              : user.email,
          style: AppTypography.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Email', user.email),
            if ((user.phoneNumber ?? '').trim().isNotEmpty)
              _detail('Phone', user.phoneNumber!.trim()),
            if ((user.address ?? '').trim().isNotEmpty)
              _detail('Address', user.address!.trim()),
            if ((user.emergencyContact ?? '').trim().isNotEmpty)
              _detail('Emergency', user.emergencyContact!.trim()),
            _detail('Role', user.role.value),
            if ((user.position ?? '').trim().isNotEmpty)
              _detail('Position', user.position!.trim()),
            _detail(
              'Branch',
              user.branchId == null || user.branchId!.isEmpty
                  ? 'Unassigned'
                  : (_branchNames[user.branchId] ?? user.branchId!),
            ),
            _detail('Status', user.isActive ? 'Active' : 'Inactive'),
            _detail('Employment', user.employmentStatus),
            // Compensation is private data (C2) — fetched on demand from the
            // subdocument, never carried on the user entity.
            FutureBuilder<UserCompensation?>(
              future: context.read<AdminUsersCubit>().compensationFor(user.uid),
              builder: (_, snap) => _compensationRows(snap.data, _detail),
            ),
            if (user.mustChangePassword)
              _detail('First login', 'Pending password change'),
            if (!user.isProfileCompleted)
              _detail('Onboarding', 'Profile not completed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: RichText(
      text: TextSpan(
        style: AppTypography.bodySmall,
        children: [
          TextSpan(
            text: '$label: ',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  /// Renders the Salary / Paid via / Payment no. rows once the private
  /// compensation record resolves (C2 — on-demand load). Nothing renders
  /// while loading or when no record exists, matching the old conditional
  /// rows for a user without compensation.
  static Widget _compensationRows(
    UserCompensation? c,
    Widget Function(String, String) row,
  ) {
    if (c == null || c.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (salarySummary(c.salaryAmount, c.salaryType) != null)
          row('Salary', salarySummary(c.salaryAmount, c.salaryType)!),
        if ((c.paymentMethod ?? '').isNotEmpty)
          row('Paid via', paymentMethodLabel(c.paymentMethod!)),
        if ((c.paymentNumber ?? '').trim().isNotEmpty)
          row('Payment no.', c.paymentNumber!.trim()),
      ],
    );
  }

  Widget _empty(bool noEmployeesAtAll) => LayoutBuilder(
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
                  noEmployeesAtAll
                      ? Icons.groups_outlined
                      : Icons.search_off_rounded,
                  size: 44,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  noEmployeesAtAll
                      ? 'No employees yet.'
                      : 'No employees match these filters.',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Compact desktop toolbar control with a native-feeling hover treatment.
/// Selection and filtering remain owned by the page; this widget only renders
/// the common menu chrome so every directory control feels like one system.
class _DirectoryMenuOption<T> {
  const _DirectoryMenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _DirectoryMenu<T> extends StatefulWidget {
  const _DirectoryMenu({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final T selected;
  final List<_DirectoryMenuOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  State<_DirectoryMenu<T>> createState() => _DirectoryMenuState<T>();
}

class _DirectoryMenuState<T> extends State<_DirectoryMenu<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: '${widget.tooltip}: ${widget.label}',
        child: PopupMenuButton<T>(
          tooltip: widget.tooltip,
          initialValue: widget.selected,
          color: AppColors.darkSurfaceElevated,
          elevation: 6,
          offset: const Offset(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          onSelected: widget.onSelected,
          itemBuilder: (context) => [
            for (final option in widget.options)
              PopupMenuItem<T>(
                value: option.value,
                height: 40,
                child: _DirectoryMenuItem(
                  label: option.label,
                  selected: option.value == widget.selected,
                ),
              ),
          ],
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.darkSurfaceElevated
                  : AppColors.darkSurface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: _hovered
                    ? AppColors.textQuaternary
                    : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryMenuItem extends StatelessWidget {
  const _DirectoryMenuItem({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
