import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/connectivity_scope.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/activity_format.dart';
import 'package:drop/features/task/presentation/attachment_format.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/attachment_gallery.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart'
    show SheetHandle;

/// Opens the deep submission-review surface as a large iOS-style modal sheet
/// (~90% height) — keeps the manager in the task's context (no full-screen
/// route). [submissionIndex] is the tapped event's index in `task.activityLog`.
Future<void> showSubmissionDetailsSheet({
  required BuildContext context,
  required TaskEntity task,
  required int submissionIndex,
  required TaskCubit cubit,
  required bool canReview,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SubmissionDetailsSheet(
      task: task,
      submissionIndex: submissionIndex,
      cubit: cubit,
      canReview: canReview,
    ),
  );
}

/// The full review surface for one submission cycle: header, full employee
/// response, a premium media gallery, manager feedback, and (for a pending
/// submission a reviewer is allowed to act on) sticky Approve / Request Rework
/// actions. Media rendering is delegated to [AttachmentGallery] / the viewer.
class SubmissionDetailsSheet extends StatefulWidget {
  const SubmissionDetailsSheet({
    super.key,
    required this.task,
    required this.submissionIndex,
    required this.cubit,
    required this.canReview,
  });

  final TaskEntity task;
  final int submissionIndex;
  final TaskCubit cubit;
  final bool canReview;

  @override
  State<SubmissionDetailsSheet> createState() => _SubmissionDetailsSheetState();
}

class _SubmissionDetailsSheetState extends State<SubmissionDetailsSheet> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = resolveSubmission(widget.task, widget.submissionIndex);
    final showActions = widget.canReview && s.awaiting;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          const SheetHandle(),
          _header(s),
          const Divider(height: 1, color: AppColors.darkBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                  AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.xl),
              children: [
                _employeeResponse(s),
                const SizedBox(height: AppSpacing.xl),
                _attachments(s),
                if (s.feedback != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _managerFeedback(s.feedback!),
                ],
              ],
            ),
          ),
          if (showActions)
            _actionBar()
          else
            SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _header(TaskSubmission s) {
    final color = activityColor(s.content.status);
    final name = s.content.actorName ?? 'Employee';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(90)),
            ),
            child: Icon(activityIcon(s.content.status), size: 19, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submission Details', style: AppTypography.h3),
                const SizedBox(height: 2),
                Text(
                  '${activityTitle(s.content.status)} by $name · '
                  '${attachmentTimestamp(s.content.at)}',
                  style: AppTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────────
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            )),
      );

  Widget _employeeResponse(TaskSubmission s) {
    final note = s.content.note ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Employee Response'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            note.isEmpty ? 'No note added with this submission.' : note,
            style: AppTypography.body.copyWith(
              color: note.isEmpty
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _attachments(TaskSubmission s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Attachments'),
        if (s.attachments.isEmpty)
          Text('No photos or videos attached.',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textTertiary))
        else
          AttachmentGallery(
            attachments: s.attachments,
            columns: 2,
            showDuration: true,
            showCaption: false,
          ),
      ],
    );
  }

  Widget _managerFeedback(ActivityEntry feedback) {
    final approved = feedback.status == 'approved';
    final color = activityColor(feedback.status);
    final note = feedback.note ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Manager Feedback'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: approved
                ? AppColors.successSurface
                : AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
                color: approved ? color.withAlpha(70) : AppColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(activityIcon(feedback.status), size: 15, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Text(activityTitle(feedback.status),
                      style: AppTypography.label.copyWith(color: color)),
                  if (feedback.actorName != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text('· ${feedback.actorName}',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(note,
                    style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary, height: 1.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Sticky review actions ────────────────────────────────────────
  Widget _actionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _notes,
            label: 'Feedback (optional)',
            prefixIcon: Icons.rate_review_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Request Rework',
                  onPressed: _requestRework,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  onPressed: _approve,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Terminal "Reject" — distinct from rework (no resubmit expected).
          TextButton(
            onPressed: _reject,
            child: Text('Reject',
                style: AppTypography.label.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String? get _note => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  void _approve() {
    // A review decision is server-authoritative and someone else's work waits
    // on it — it must not be taken against a possibly-stale submission.
    if (!requireOnline(context, action: 'approving work')) return;
    widget.cubit.approveTask(widget.task, reviewNotes: _note);
    Navigator.of(context).pop();
  }

  Future<void> _requestRework() async {
    if (!requireOnline(context, action: 'requesting rework')) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Request rework?',
      message: 'The employee will be asked to fix and resubmit it.',
      confirmLabel: 'Request rework',
    );
    if (confirmed && mounted) {
      widget.cubit.reworkTask(widget.task, reviewNotes: _note);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _reject() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reject task?',
      message: 'This rejects the submission. Use Request Rework instead if the '
          'employee should fix and resubmit it.',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (confirmed && mounted) {
      widget.cubit.rejectTask(widget.task, reviewNotes: _note);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
