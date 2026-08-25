import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_dialog.dart';
import 'package:opshub/core/widgets/opshub_loading_state.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/requests/domain/request_access.dart';
import 'package:opshub/features/requests/domain/request_thread.dart';
import 'package:opshub/features/requests/presentation/cubit/request_detail_cubit.dart';
import 'package:opshub/features/requests/presentation/cubit/request_detail_state.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:opshub/features/requests/presentation/request_format.dart';
import 'package:opshub/features/requests/presentation/widgets/request_composer.dart';
import 'package:opshub/features/requests/presentation/widgets/request_timeline.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_gallery.dart';

/// The full request detail — header, status, requester/branch/time, the dynamic
/// request information, the activity timeline + comments, and the role-scoped
/// approval actions. Provides a fresh [RequestDetailCubit] scoped to [requestId].
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return BlocProvider<RequestDetailCubit>(
      create: (_) => AppDependencies.createRequestDetailCubit(requestId, user),
      child: _RequestDetailView(user: user),
    );
  }
}

class _RequestDetailView extends StatelessWidget {
  const _RequestDetailView({required this.user});
  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestDetailCubit, RequestDetailState>(
      listener: (context, state) {
        state.mapOrNull(error: (e) => context.showError(e.message));
      },
      builder: (context, state) {
        return state.when(
          loading: () => const AdaptiveScaffold(
            title: 'Request',
            body: OpsHubLoadingState(message: 'Loading request…'),
          ),
          unavailable: () => AdaptiveScaffold(
            title: 'Request',
            body: _Unavailable(onBack: () {
              if (context.canPop()) context.pop();
            }),
          ),
          error: (_) => const AdaptiveScaffold(
            title: 'Request',
            body: OpsHubLoadingState(message: 'Loading request…'),
          ),
          loaded: (request, events, busy) =>
              _Loaded(request: request, events: events, busy: busy, user: user),
        );
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.request,
    required this.events,
    required this.busy,
    required this.user,
  });

  final RequestEntity request;
  final List<RequestEvent> events;
  final bool busy;
  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RequestDetailCubit>();
    final u = user;
    final canDecide = u != null && canDecideRequest(u, request);
    final canComment = u != null && canCommentOnRequest(u, request);
    final canReopen = u != null && canReopenRequest(u, request);
    final canDelete = u != null && canDeleteRequest(u);
    final branchName = request.branchId == null
        ? null
        : context.read<RequestsListCubit>().branchNames[request.branchId];
    final thread = requestThread(events, request);

    return AdaptiveScaffold(
      title: request.type.label,
      subtitle: request.refLabel,
      contentMaxWidth: 820,
      actions: [
        // Admin housekeeping — a SOFT delete (the record is kept, the inbox
        // stops showing it). Quiet icon, destructive confirm.
        if (canDelete)
          IconButton(
            tooltip: 'Delete request',
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textSecondary),
            onPressed: busy ? null : () => _confirmDelete(context, cubit),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _HeaderCard(request: request, branchName: branchName),
                const SizedBox(height: AppSpacing.lg),
                _DetailsCard(request: request),
                if (request.hasAttachments) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _AttachmentsCard(request: request),
                ],
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('Activity'),
                const SizedBox(height: AppSpacing.md),
                RequestTimeline(
                  events: thread,
                  viewerId: u?.uid ?? '',
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
          _ActionBar(
            request: request,
            canDecide: canDecide,
            canReopen: canReopen,
            busy: busy,
            onApprove: cubit.approve,
            onReject: () => _confirmReject(context, cubit),
            onReopen: () => _confirmReopen(context, cubit),
          ),
          RequestComposer(
            sending: busy,
            locked: !canComment,
            lockedLabel: request.isTerminal
                ? 'This request is ${request.status.label.toLowerCase()} — comments are read-only.'
                : 'You cannot comment on this request.',
            onSend: (text, attachments) =>
                cubit.addComment(text, attachments: attachments),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReject(
      BuildContext context, RequestDetailCubit cubit) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reject request?',
      message:
          'The requester will be notified. You can add a comment explaining why.',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (ok) await cubit.reject();
  }

  Future<void> _confirmReopen(
      BuildContext context, RequestDetailCubit cubit) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reopen request?',
      message:
          'It goes back to Pending for a fresh decision, and comments unlock. '
          'The requester and branch manager will be notified.',
      confirmLabel: 'Reopen',
    );
    if (ok) await cubit.reopen();
  }

  Future<void> _confirmDelete(
      BuildContext context, RequestDetailCubit cubit) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete request?',
      message:
          'It disappears from everyone’s inbox but is kept as a record.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await cubit.deleteRequest();
    if (deleted && context.mounted) {
      context.showSuccess('Request deleted');
      if (context.canPop()) context.pop();
    }
  }
}

// ─── Header ──────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.request, required this.branchName});
  final RequestEntity request;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final color = RequestFormat.statusColor(request.status);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Icon(RequestFormat.icon(request.type),
                    color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.type.label,
                        style: AppTypography.h3
                            .copyWith(color: AppColors.textPrimary)),
                    Text(request.summary,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(request: request),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.darkBorder),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              if ((request.requesterName ?? '').trim().isNotEmpty)
                _MetaItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Requester',
                    value: request.requesterName!.trim()),
              if ((branchName ?? '').trim().isNotEmpty)
                _MetaItem(
                    icon: Icons.storefront_outlined,
                    label: 'Branch',
                    value: branchName!.trim()),
              if (request.createdAt != null)
                _MetaItem(
                    icon: Icons.schedule_rounded,
                    label: 'Submitted',
                    value: RequestFormat.fullStamp(request.createdAt)),
              if ((request.decidedByName ?? '').trim().isNotEmpty)
                _MetaItem(
                    icon: RequestFormat.statusIcon(request.status),
                    label: request.status.isRejected ? 'Rejected by' : 'Decided by',
                    value: request.decidedByName!.trim(),
                    color: RequestFormat.statusColor(request.status)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.request});
  final RequestEntity request;

  @override
  Widget build(BuildContext context) {
    final color = RequestFormat.statusColor(request.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(RequestFormat.statusIcon(request.status), size: 13, color: color),
          const SizedBox(width: 5),
          Text(request.status.label,
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: AppTypography.bodySmall.copyWith(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Message ─────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.request});
  final RequestEntity request;

  @override
  Widget build(BuildContext context) {
    final message = request.message;
    if (message.isEmpty) return const SizedBox.shrink();
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.notes_rounded, label: 'Message'),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({required this.request});
  final RequestEntity request;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.attach_file_rounded, label: 'Attachments'),
          const SizedBox(height: AppSpacing.md),
          AttachmentGallery(attachments: request.attachments),
        ],
      ),
    );
  }
}

// ─── Action bar ──────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.request,
    required this.canDecide,
    required this.canReopen,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onReopen,
  });

  final RequestEntity request;
  final bool canDecide;
  final bool canReopen;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children;
    if (canDecide && request.status.isPending) {
      // The decision — approve / reject, only while pending.
      children = [
        Expanded(
          child: PremiumButton(
            label: 'Approve',
            icon: Icons.check_rounded,
            style: PremiumButtonStyle.filled,
            onPressed: busy ? null : onApprove,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PremiumButton(
            label: 'Reject',
            icon: Icons.close_rounded,
            tone: AppColors.error,
            onPressed: busy ? null : onReject,
          ),
        ),
      ];
    } else if (canReopen) {
      // Admin escape hatch on a decided request — back to Pending.
      children = [
        Expanded(
          child: PremiumButton(
            label: 'Reopen request',
            icon: Icons.replay_rounded,
            style: PremiumButtonStyle.ghost,
            onPressed: busy ? null : onReopen,
          ),
        ),
      ];
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
          AppSpacing.pagePadding, AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(children: children),
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────
class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTypography.label.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary, letterSpacing: 1.2));
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline_rounded,
              size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text('This request is no longer available',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          PremiumButton(
              label: 'Go back', icon: Icons.arrow_back_rounded, onPressed: onBack),
        ],
      ),
    );
  }
}
