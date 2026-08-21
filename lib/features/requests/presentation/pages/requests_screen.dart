import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/opshub_empty_state.dart';
import 'package:drop/core/widgets/opshub_loading_state.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/requests/domain/entities/request_entity.dart';
import 'package:drop/features/requests/domain/request_metrics.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:drop/features/requests/presentation/request_format.dart';
import 'package:drop/features/requests/presentation/widgets/request_card.dart';

/// The employee approval-requests inbox — shared by every role, self-scoping
/// (admin: all branches · manager: own branch · employee: own requests).
///
/// The flow is deliberately one-directional: an **employee** files a request,
/// their **branch manager** approves or rejects it, and the **admin** has global
/// visibility and may decide when necessary. Only employees get the "New
/// request" FAB — approvers never file requests, so self-approval can't happen
/// structurally (no extra guard logic needed). Managers and admins get a KPI
/// strip that doubles as status filters (tap Pending → see only pending).
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  RequestStatus? _statusFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final user = context.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RequestsListCubit>().load(user),
      );
    }
  }

  bool get _isApprover => context.isAdmin || context.isManager;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return AdaptiveScaffold(
      title: 'Requests',
      subtitle: context.isManager
          ? 'Approval requests from your branch'
          : context.isAdmin
              ? 'Approval requests across every branch'
              : 'Your approval requests',
      // Employees only — approvers (manager/admin) never file requests, so a
      // request can never be decided by its own author.
      floatingActionButton: _isApprover
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(RouteNames.requestsCreate),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New request'),
            ),
      body: BlocBuilder<RequestsListCubit, RequestsListState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const OpsHubLoadingState(message: 'Loading requests…'),
          loaded: (requests, branchNames) => _Body(
            requests: requests,
            branchNames: branchNames,
            user: user,
            isApprover: _isApprover,
            statusFilter: _statusFilter,
            query: _query,
            onFilter: (s) => setState(() =>
                _statusFilter = _statusFilter == s ? null : s),
            onQuery: (q) => setState(() => _query = q),
          ),
          error: (message) => _ErrorState(
            message: message,
            onRetry: () {
              final u = context.currentUser;
              if (u != null) context.read<RequestsListCubit>().refresh();
            },
          ),
          orElse: () => const OpsHubLoadingState(message: 'Loading requests…'),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.requests,
    required this.branchNames,
    required this.user,
    required this.isApprover,
    required this.statusFilter,
    required this.query,
    required this.onFilter,
    required this.onQuery,
  });

  final List<RequestEntity> requests;
  final Map<String, String> branchNames;
  final UserEntity? user;
  final bool isApprover;
  final RequestStatus? statusFilter;
  final String query;
  final ValueChanged<RequestStatus?> onFilter;
  final ValueChanged<String> onQuery;

  bool _matches(RequestEntity r) {
    if (statusFilter != null && r.status != statusFilter) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      r.type.label,
      r.summary,
      r.requesterName ?? '',
      r.refLabel,
      branchNames[r.branchId ?? ''] ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = RequestMetrics.from(requests);
    final filtered = requests.where(_matches).toList();

    return RefreshIndicator(
      onRefresh: () => context.read<RequestsListCubit>().refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.huge),
        children: [
          if (isApprover) ...[
            _KpiStrip(
                metrics: metrics, active: statusFilter, onFilter: onFilter),
            const SizedBox(height: AppSpacing.md),
          ],
          AppSearchField(
            hint: 'Search requests',
            onChanged: onQuery,
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            _EmptyState(hasAny: requests.isNotEmpty)
          else
            ..._rows(context, filtered),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, List<RequestEntity> list) {
    final widgets = <Widget>[];
    var archiveDividerShown = false;
    for (final r in list) {
      if (r.isTerminal && !archiveDividerShown) {
        archiveDividerShown = true;
        widgets.add(const _ArchiveDivider());
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: RequestCard(
          request: r,
          branchName: branchNames[r.branchId ?? ''],
          showRequester: isApprover,
          onTap: () => context.push(RouteNames.requestDetail(r.id)),
        ),
      ));
    }
    return widgets;
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.metrics,
    required this.active,
    required this.onFilter,
  });
  final RequestMetrics metrics;
  final RequestStatus? active;
  final ValueChanged<RequestStatus?> onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Kpi(
          value: metrics.pending,
          label: 'Pending',
          status: RequestStatus.pending,
          active: active,
          onTap: onFilter,
        ),
        const SizedBox(width: AppSpacing.sm),
        _Kpi(
          value: metrics.approved,
          label: 'Approved',
          status: RequestStatus.approved,
          active: active,
          onTap: onFilter,
        ),
        const SizedBox(width: AppSpacing.sm),
        _Kpi(
          value: metrics.rejected,
          label: 'Rejected',
          status: RequestStatus.rejected,
          active: active,
          onTap: onFilter,
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.value,
    required this.label,
    required this.status,
    required this.active,
    required this.onTap,
  });
  final int value;
  final String label;
  final RequestStatus status;
  final RequestStatus? active;
  final ValueChanged<RequestStatus?> onTap;

  @override
  Widget build(BuildContext context) {
    final color = RequestFormat.statusColor(status);
    final isActive = active == status;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(status),
          borderRadius: AppRadius.mdAll,
          child: Ink(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isActive ? color.withAlpha(28) : AppColors.darkSurface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                  color: isActive ? color.withAlpha(120) : AppColors.darkBorder),
            ),
            child: Column(
              children: [
                Text('$value',
                    style: AppTypography.h2.copyWith(
                        color: isActive ? color : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveDivider extends StatelessWidget {
  const _ArchiveDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Row(
        children: [
          Text('EARLIER',
              style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary, letterSpacing: 1.2)),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider(height: 1, color: AppColors.darkBorder)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (hasAny) {
      message = 'No requests match this filter.';
    } else if (context.isManager) {
      message =
          'When someone on your branch asks for your approval, it shows up here.';
    } else if (context.isAdmin) {
      message = 'Approval requests from every branch show up here.';
    } else {
      message =
          'Need to leave early, use your staff discount, or get the OK on '
          'something? Send your manager a request.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl),
      child: OpsHubEmptyState(
        title: hasAny ? 'Nothing here' : 'No requests yet',
        message: message,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
