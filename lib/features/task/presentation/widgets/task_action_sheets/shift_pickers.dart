part of '../task_action_sheets.dart';

/// Morning/Night shift chip picker, shown instead of [_AssigneeField] when
/// "Shift" is the assigned-to mode (Shift Assignment feature) — the task
/// targets whoever is rostered on the picked shift, not named employees.
class ShiftChipPicker extends StatelessWidget {
  const ShiftChipPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ScheduleShift? value;
  final void Function(ScheduleShift) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Shift', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final shift in ScheduleShift.values)
              GestureDetector(
                onTap: () => onChanged(shift),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: value == shift
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == shift
                          ? AppColors.primary
                          : AppColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    '${shift.label} · ${shift.timeRange}',
                    style: AppTypography.caption.copyWith(
                      color: value == shift
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight: value == shift
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Once/Daily/Weekly repeat picker for a shift task — replaces
/// [_RecurrencePicker] only in shift mode. Once creates a single instance;
/// Daily/Weekly create a [RecurringTaskTemplateEntity] instead (via
/// `TaskCubit.createRecurringShiftTemplate`), so a weekday selector appears
/// when Weekly is picked.
class ShiftRepeatPicker extends StatelessWidget {
  const ShiftRepeatPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.weekday,
    required this.onWeekdayChanged,
    this.modes = TemplateRepeatMode.values,
  });
  final TemplateRepeatMode value;
  final void Function(TemplateRepeatMode) onChanged;
  final int weekday;
  final void Function(int) onWeekdayChanged;

  /// Which repeat modes to offer — the task form offers all three (Once
  /// creates a single task); the recurring-template management sheet only
  /// offers Daily/Weekly (a template is never "once" by definition).
  final List<TemplateRepeatMode> modes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.repeat_rounded, size: 16, color: AppColors.textTertiary),
            SizedBox(width: AppSpacing.sm),
            Text('Repeats', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final mode in modes)
              GestureDetector(
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: value == mode
                        ? AppColors.primary
                        : AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == mode
                          ? AppColors.primary
                          : AppColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: AppTypography.caption.copyWith(
                      color: value == mode
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight: value == mode
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (value == TemplateRepeatMode.weekly) ...[
          const SizedBox(height: AppSpacing.md),
          WeekdayChipPicker(value: weekday, onChanged: onWeekdayChanged),
        ],
      ],
    );
  }
}

/// Mon–Sun weekday chip row for [ShiftRepeatPicker]'s Weekly mode
/// (`DateTime.monday` = 1 … `DateTime.sunday` = 7, matching
/// [RecurringTaskTemplateEntity.weekday]).
class WeekdayChipPicker extends StatelessWidget {
  const WeekdayChipPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final void Function(int) onChanged;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < 7; i++)
          GestureDetector(
            onTap: () => onChanged(i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value == i + 1
                    ? AppColors.primary
                    : AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value == i + 1
                      ? AppColors.primary
                      : AppColors.darkBorder,
                ),
              ),
              child: Text(
                _labels[i],
                style: AppTypography.caption.copyWith(
                  color: value == i + 1
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                  fontWeight: value == i + 1
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
