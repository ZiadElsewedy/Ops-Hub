part of '../task_action_sheets.dart';

/// Premium checklist builder used inside the task creation / edit form — turns
/// the work into numbered, ordered steps (each optionally *required*). The
/// parent [_TaskFormSheetState] owns all state (controllers, required flags,
/// ids); this widget is stateless and just renders + calls back.
class _ChecklistBuilder extends StatelessWidget {
  const _ChecklistBuilder({
    required this.controllers,
    required this.required,
    required this.lastAdded,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleRequired,
  });

  final List<TextEditingController> controllers;
  final List<bool> required;

  /// The row index just added (or `-1`), so it can autofocus — adding a step
  /// drops the cursor straight into it.
  final int lastAdded;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int) onToggleRequired;

  @override
  Widget build(BuildContext context) {
    final empty = controllers.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Break the work into steps',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (!empty) ...[
                const SizedBox(width: AppSpacing.sm),
                _CountPill(controllers.length),
              ],
            ],
          ),
          // Animated so adding / removing a step glides instead of snapping.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: empty
                ? const _ChecklistEmpty()
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      children: [
                        for (var i = 0; i < controllers.length; i++)
                          _StepRow(
                            key: ValueKey('ci_$i'),
                            index: i + 1,
                            controller: controllers[i],
                            isRequired: required[i],
                            autofocus: i == lastAdded,
                            onToggleRequired: () => onToggleRequired(i),
                            onRemove: () => onRemove(i),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddStepButton(onTap: onAdd),
        ],
      ),
    );
  }
}

/// Empty state for the checklist builder — a quiet nudge, never a wall of text.
class _ChecklistEmpty extends StatelessWidget {
  const _ChecklistEmpty();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        'Optional — add ordered steps the employee ticks off as they work.',
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// A single editable, numbered step inside [_ChecklistBuilder].
class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.controller,
    required this.isRequired,
    required this.onToggleRequired,
    required this.onRemove,
    this.autofocus = false,
  });

  final int index;
  final TextEditingController controller;
  final bool isRequired;
  final bool autofocus;
  final VoidCallback onToggleRequired;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Step number — a quiet ordinal badge instead of a fake drag handle.
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text(
              '$index',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Describe this step…',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.darkBg,
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Required toggle: filled star = required, outline = optional.
          Tooltip(
            message: isRequired
                ? 'Required — tap to make optional'
                : 'Optional — tap to make required',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: onToggleRequired,
              icon: Icon(
                isRequired ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: isRequired
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            onPressed: onRemove,
            tooltip: 'Remove step',
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width dashed "add a step" affordance at the foot of the builder.
class _AddStepButton extends StatelessWidget {
  const _AddStepButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The plus sits in a filled chip so the affordance invites a tap
            // rather than reading as a disabled row.
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 15,
                color: AppColors.onAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add step',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small count chip (e.g. `3`) used by section builders.
class _CountPill extends StatelessWidget {
  const _CountPill(this.count);
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text('$count', style: AppTypography.caption),
    );
  }
}
