import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/cases/domain/case_participation.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/cases/presentation/case_format.dart';
import 'package:opshub/features/cases/presentation/cubit/case_conversation_cubit.dart';
import 'package:opshub/features/cases/presentation/cubit/case_conversation_state.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:opshub/features/cases/presentation/widgets/case_composer.dart';
import 'package:opshub/features/cases/presentation/widgets/case_message_list.dart';
import 'package:opshub/features/cases/presentation/widgets/case_status_control.dart';

/// The shared conversation body — used identically by the desktop split-pane
/// right side and the mobile detail screen. A top header (subject · sender ·
/// urgent · status control), the chat thread, and the composer.
class CaseConversationView extends StatelessWidget {
  const CaseConversationView({super.key, this.onClosedOrDeleted});

  /// Called when the case is deleted (desktop clears the selection).
  final VoidCallback? onClosedOrDeleted;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaseConversationCubit, CaseConversationState>(
      listenWhen: (prev, curr) =>
          curr.maybeWhen(error: (_) => true, orElse: () => false),
      listener: (context, state) => state.mapOrNull(
        error: (e) => context.showError(e.message),
      ),
      builder: (context, state) => state.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        unavailable: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('This case is unavailable.'),
          ),
        ),
        loaded: (c, messages, sending, changing) => _Loaded(
          caseItem: c,
          messages: messages,
          sending: sending,
          changing: changing,
          onClosedOrDeleted: onClosedOrDeleted,
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.caseItem,
    required this.messages,
    required this.sending,
    required this.changing,
    this.onClosedOrDeleted,
  });
  final CaseEntity caseItem;
  final List<CaseMessage> messages;
  final bool sending;
  final bool changing;
  final VoidCallback? onClosedOrDeleted;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaseConversationCubit>();
    final role = context.currentRole;
    final user = context.currentUser;
    final iAmReporter = role != null && viewerIsReporter(role, caseItem);
    final canControl = role != null && viewerCanControlStatus(role, caseItem);

    return Column(
      children: [
        _HeaderBar(
          caseItem: caseItem,
          canControl: canControl,
          changingStatus: changing,
          onSelectStatus: cubit.changeStatus,
          onReveal:
              (role?.isAdmin ?? false) && caseItem.privacy.isConfidential
                  ? () => _revealSender(context, cubit)
                  : null,
          onDelete: (role?.isAdmin ?? false)
              ? () => _confirmDelete(context)
              : null,
        ),
        const Divider(height: 1, color: AppColors.darkBorder),
        Expanded(
          child: CaseMessageList(
            caseItem: caseItem,
            messages: messages,
            currentUid: user?.uid ?? '',
            iAmReporter: iAmReporter,
          ),
        ),
        CaseComposer(
          onSend: (text, attachments) =>
              cubit.sendMessage(text, attachments: attachments),
          sending: sending,
          closed: caseItem.isClosed,
          canReopen: canControl,
          onReopen: cubit.reopen,
        ),
      ],
    );
  }

  Future<void> _revealSender(
      BuildContext context, CaseConversationCubit cubit) async {
    final identity = await cubit.revealReporter();
    if (!context.mounted) return;
    final name = (identity?.createdByName ?? '').trim();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceElevated,
        title: const Text('Reporter identity'),
        content: Text(
          identity == null
              ? 'The reporter identity could not be read.'
              : 'Opened by ${name.isNotEmpty ? name : identity.createdByUserId}.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceElevated,
        title: const Text('Delete case?'),
        content: const Text(
            'This permanently removes the case and its conversation. This '
            'cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<CaseListCubit>().deleteCase(caseItem.id);
    onClosedOrDeleted?.call();
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.caseItem,
    required this.canControl,
    required this.changingStatus,
    required this.onSelectStatus,
    this.onReveal,
    this.onDelete,
  });

  final CaseEntity caseItem;
  final bool canControl;
  final bool changingStatus;
  final ValueChanged<CaseStatus> onSelectStatus;
  final VoidCallback? onReveal;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
      color: AppColors.darkSurface,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(caseCategoryIcon(caseItem.category),
                size: 19, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(caseItem.subject,
                          style: AppTypography.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (caseItem.urgent) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const _UrgentBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                        caseItem.privacy.isNormal
                            ? Icons.person_outline
                            : Icons.lock_outline,
                        size: 13,
                        color: AppColors.textTertiary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('${caseItem.senderLabel} · ${caseItem.category.label}',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CaseStatusControl(
            status: caseItem.status,
            enabled: canControl,
            busy: changingStatus,
            onSelect: onSelectStatus,
          ),
          if (onReveal != null)
            IconButton(
              tooltip: 'Reveal sender',
              icon: const Icon(Icons.visibility_outlined,
                  color: AppColors.textSecondary),
              onPressed: onReveal,
            ),
          if (onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              color: AppColors.darkSurfaceElevated,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
              onSelected: (_) => onDelete!.call(),
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete case'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(28),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.error.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.priority_high_rounded, size: 12, color: AppColors.error),
          const SizedBox(width: 4),
          Text('Urgent',
              style: AppTypography.caption.copyWith(color: AppColors.error)),
        ],
      ),
    );
  }
}
