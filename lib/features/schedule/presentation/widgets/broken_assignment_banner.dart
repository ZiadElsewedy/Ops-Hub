import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/widgets/employee_picker_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/sheet_chrome.dart';

/// A single broken slot — a (day, shift) holding a uid that no longer resolves
/// to a branch member.
typedef BrokenSlot = ({ScheduleDay day, ScheduleShift shift, String uid});

/// Every stale assignment in the week, in display order. The uid is carried for
/// the mutation only — it is **never** shown to the user.
List<BrokenSlot> brokenSlots(
    WeeklyScheduleEntity schedule, List<UserEntity> members) {
  final out = <BrokenSlot>[];
  for (final day in ScheduleDay.values) {
    for (final shift in ScheduleShift.values) {
      final uids = schedule.employeesFor(day, shift);
      for (final uid in orphanAssignments(uids, members)) {
        out.add((day: day, shift: shift, uid: uid));
      }
    }
  }
  return out;
}

/// Compact warning card shown above the grid when the roster contains stale
/// references. Tapping opens the resolve flow. User-friendly — no uid, no
/// "Unknown member" debug text.
class BrokenAssignmentBanner extends StatelessWidget {
  const BrokenAssignmentBanner({
    super.key,
    required this.count,
    required this.onReview,
  });

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReview,
        borderRadius: AppRadius.cardAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(22),
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.warning.withAlpha(110)),
          ),
          child: Row(
            children: [
              const Icon(Icons.report_problem_rounded,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? 'Missing employee assignment'
                          : '$count missing employee assignments',
                      style: AppTypography.label
                          .copyWith(color: AppColors.warning),
                    ),
                    const SizedBox(height: 1),
                    const Text('A scheduled employee is no longer in this branch.',
                        style: AppTypography.caption),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Review',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.warning)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.warning),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the resolve flow — a live list of every stale slot with Remove /
/// Reassign per entry. Reads the global [ScheduleCubit] so the list shrinks as
/// the admin clears entries, and shows an all-clear state when done.
Future<void> showResolveBrokenSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ResolveBrokenSheet(),
  );
}

class _ResolveBrokenSheet extends StatelessWidget {
  const _ResolveBrokenSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleCubit, ScheduleState>(
      builder: (context, state) => state.maybeWhen(
        loaded: (branchId, weekStart, schedule, members, busy) =>
            schedule == null
                ? const SizedBox.shrink()
                : _content(context, schedule, members, busy),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _content(BuildContext context, WeeklyScheduleEntity schedule,
      List<UserEntity> members, bool busy) {
    final slots = brokenSlots(schedule, members);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          if (busy) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: AppSpacing.md),
          const Text('Resolve assignments', style: AppTypography.h3),
          const SizedBox(height: 2),
          Text(
            slots.isEmpty
                ? 'Everything looks good.'
                : 'Remove or reassign each shift that points to a former '
                    'employee.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (slots.isEmpty)
            _allClear()
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final s in slots) _slotRow(context, s, members),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _allClear() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 20, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Text('All assignments resolved.',
              style: AppTypography.label
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _slotRow(
      BuildContext context, BrokenSlot slot, List<UserEntity> members) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_off_outlined,
                size: 18, color: AppColors.warning),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${slot.day.label} · ${slot.shift.label}',
                    style: AppTypography.label),
                const SizedBox(height: 1),
                const Text('Former employee — no longer here',
                    style: AppTypography.caption),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                context.read<ScheduleCubit>().remove(slot.day, slot.shift, slot.uid),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => _reassign(context, slot, members),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('Reassign'),
          ),
        ],
      ),
    );
  }

  void _reassign(
      BuildContext context, BrokenSlot slot, List<UserEntity> members) {
    final cubit = context.read<ScheduleCubit>();
    showEmployeePicker(
      context: context,
      title: 'Reassign ${slot.day.label} · ${slot.shift.label}',
      subtitle: 'Pick an employee to replace the former one',
      employees:
          members.where((u) => u.role.isEmployee && u.isActive).toList(),
      isAssigned: (_) => false,
      onPick: (u) async {
        await cubit.assign(slot.day, slot.shift, u.uid);
        await cubit.remove(slot.day, slot.shift, slot.uid);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
