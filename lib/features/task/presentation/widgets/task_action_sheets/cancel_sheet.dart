part of '../task_action_sheets.dart';

// ─── Cancel ──────────────────────────────────────────────────────
/// Cancels a task with a **mandatory structured reason** (Automated Tasks spec
/// §5.5). The reason picklist is the whole point of the sheet: cancellation
/// volume *by reason* is what later distinguishes a legitimate cancel from a
/// routine that should be paused or a template that is generating the wrong
/// work — free text can't be counted, and an optional reason would make Cancel
/// a quiet way to dispose of work that simply wasn't done.
///
/// The CTA stays disabled until a reason is picked, so the requirement is
/// visible rather than punitive — no "you must pick a reason" error after the
/// fact. The dismiss action is labelled **Keep Task** so "Cancel" never means
/// two different things in the same sheet.
class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _note = TextEditingController();
  TaskCancelReason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) return;
    widget.cubit.cancelTask(widget.task, reason: reason, note: _note.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.task.status == TaskStatus.started;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Cancel Task'),
          Text(widget.task.title, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // Says exactly what cancelling does to the record and the numbers,
            // because a manager choosing between Cancel and "let it miss" is
            // choosing between two very different reports (§8).
            started
                ? 'Someone has already started this work. Cancelling closes it '
                      'now — it will not count as completed or as missed.'
                : 'Cancelling closes this task without it being done. It will '
                      'not count as completed or as missed.',
            style: AppTypography.caption.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'REASON',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final reason in TaskCancelReason.selectable) ...[
            _CancelReasonTile(
              reason: reason,
              selected: _reason == reason,
              onTap: () => setState(() => _reason = reason),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _note,
            label: 'Add a note (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Cancel Task',
            icon: const Icon(
              Icons.block_rounded,
              size: 18,
              color: AppColors.textDark,
            ),
            // Disabled until a reason exists — the mandatory field is enforced
            // by the control, not by an error message after the tap.
            onPressed: _reason == null ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Keep Task', style: AppTypography.label),
          ),
        ],
      ),
    );
  }
}

// ─── Report incorrect ────────────────────────────────────────────
/// The employee's half of the cancellation workflow (Automated Tasks spec
/// §5.2): they may say a task is **wrong**, and a manager decides. It never
/// changes the task's status — the work stays exactly where it is until someone
/// with the authority to cancel it acts.
///
/// The explanation is **required**. A bare "this is wrong" gives the manager
/// nothing to decide on, and this is the report's entire payload.
class _ReportIncorrectSheet extends StatefulWidget {
  const _ReportIncorrectSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;

  @override
  State<_ReportIncorrectSheet> createState() => _ReportIncorrectSheetState();
}

class _ReportIncorrectSheetState extends State<_ReportIncorrectSheet> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Re-enables the CTA the moment there is something to send.
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNote = _note.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Report a problem'),
          Text(widget.task.title, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // Sets the expectation honestly: this is a message to a human, not
            // a button that makes the task go away.
            'This goes to your manager, who decides what happens to the task. '
            'Nothing changes until they do.',
            style: AppTypography.caption.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _note,
            label: "What's wrong with it?",
            prefixIcon: Icons.flag_outlined,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Send to Manager',
            icon: const Icon(
              Icons.send_rounded,
              size: 18,
              color: AppColors.textDark,
            ),
            onPressed: !hasNote
                ? null
                : () {
                    widget.cubit.reportTaskIncorrect(
                      widget.task,
                      note: _note.text,
                    );
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }
}

/// One selectable reason row — a radio glyph plus the picklist label. Monochrome
/// throughout: selection is carried by the white ring/dot and a brighter border,
/// never by a colour.
class _CancelReasonTile extends StatelessWidget {
  const _CancelReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final TaskCancelReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: reason.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            // ≥44px touch target.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.subtleGradient,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    reason.label,
                    style: AppTypography.body.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
