part of '../task_action_sheets.dart';

// ─── Review ──────────────────────────────────────────────────────
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? get _note => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Review Task'),
          Text(widget.task.title, style: AppTypography.label),
          if (widget.task.hasChecklist) ...[
            const SizedBox(height: AppSpacing.md),
            _ReviewChecklist(task: widget.task),
          ],
          _SubmittedWork(task: widget.task),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _notes,
            label: 'What needs fixing? (optional)',
            prefixIcon: Icons.rate_review_outlined,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Approve',
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: AppColors.textDark,
            ),
            onPressed: () {
              widget.cubit.approveTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          // Sends the task back for the employee to fix and resubmit (bumps the
          // revision → REWORK #n).
          AppButton.secondary(
            label: 'Request Rework',
            onPressed: () {
              widget.cubit.reworkTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          // Terminal "Reject" — distinct from rework (no resubmit expected).
          TextButton(
            onPressed: () {
              widget.cubit.rejectTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            },
            child: Text(
              'Reject',
              style: AppTypography.label.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only checklist progress for the manager review sheet ("4 / 5 completed"
/// or "100% complete") with each item's state.
class _ReviewChecklist extends StatelessWidget {
  const _ReviewChecklist({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 16,
                color: complete ? AppColors.success : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                complete ? '100% complete' : '$done / $total completed',
                style: AppTypography.labelSmall.copyWith(
                  color: complete ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final i in task.checklist)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    i.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: i.completed
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      i.title,
                      style: AppTypography.bodySmall.copyWith(
                        color: i.completed
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The employee's submitted work shown to the reviewing manager: their notes and
/// the proof photo (if any). Renders nothing when there's neither.
class _SubmittedWork extends StatelessWidget {
  const _SubmittedWork({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final notes = task.notes ?? '';
    final media = latestAttachments(task);
    if (notes.isEmpty && media.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submitted work', style: AppTypography.labelSmall),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(notes, style: AppTypography.bodySmall),
            ],
            if (media.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AttachmentGallery(attachments: media, tileSize: 80),
            ],
          ],
        ),
      ),
    );
  }
}
