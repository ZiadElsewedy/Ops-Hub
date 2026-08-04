import 'package:flutter/material.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The **phone-native** final schedule — the readable counterpart to the
/// landscape `FinalScheduleSheet`, which is a 1600px print document that only
/// looks right on a Mac (shrunk to fit a phone it becomes an illegible
/// thumbnail).
///
/// Reads top-to-bottom, one day per card, Morning then Night, with the people
/// actually on each shift listed as chips — no zooming, no horizontal scroll.
/// The macOS Final view is untouched; this is what a phone shows instead. The
/// PNG / PDF exports still publish the landscape sheet, so what you send is
/// identical across platforms.
///
/// Read-only by construction: it renders the schedule and derives nothing new.
class FinalScheduleMobileView extends StatelessWidget {
  const FinalScheduleMobileView({
    super.key,
    required this.schedule,
    required this.members,
    required this.branch,
    this.managerName,
    this.generatedAt,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final BranchEntity? branch;
  final String? managerName;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final roster = scheduledRoster(schedule, members);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        _header(context, roster.length),
        const SizedBox(height: AppSpacing.lg),
        if (roster.isEmpty)
          _emptyState()
        else
          for (final day in ScheduleDay.values) ...[
            _DayCard(
              day: day,
              schedule: schedule,
              members: members,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        const SizedBox(height: AppSpacing.sm),
        _legend(),
      ],
    );
  }

  Widget _header(BuildContext context, int peopleCount) {
    final branchName = branch?.name ?? 'Branch';
    final gen = generatedAt ?? DateTime.now();
    // A colon-labelled manager field ("Manager: Name") instead of a mid-dot,
    // which blended with the mid-dot joiner and read as a doubled "Manager ·
    // Manager".
    final meta = <String>[
      '$peopleCount ${peopleCount == 1 ? 'person' : 'people'} scheduled',
      'Generated ${AppDateFormatter.dayMonthYear(gen)}',
      if (managerName != null && managerName!.trim().isNotEmpty)
        'Manager: ${managerName!.trim()}',
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BranchAvatar(
                logoUrl: branch?.logoUrl,
                name: branchName,
                size: 44,
                radius: 13,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DROP',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      branchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Week of ${ScheduleWeek.rangeLabel(schedule.weekStart)}',
            style: AppTypography.label,
          ),
          const SizedBox(height: 3),
          Text(
            meta.join('  ·  '),
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44),
      alignment: Alignment.center,
      child: Text(
        'No one is scheduled this week.',
        style: AppTypography.body.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: const [
        _LegendDot(label: 'Morning', icon: Icons.wb_sunny_outlined),
        _LegendDot(label: 'Night', icon: Icons.nightlight_round),
        _LegendDot(label: 'On leave', icon: Icons.beach_access_outlined),
      ],
    );
  }
}

/// One day of the week — Morning then Night, with a leave line and note when
/// present. Days with nobody on either shift still render (a visible gap is
/// information: nobody is covering that day).
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.schedule,
    required this.members,
  });

  final ScheduleDay day;
  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;

  bool get _isToday => ScheduleWeek.startOf(DateTime.now()) ==
          ScheduleWeek.startOf(schedule.weekStart) &&
      ScheduleDay.today() == day;

  @override
  Widget build(BuildContext context) {
    final date = schedule.weekStart.add(Duration(days: day.index));
    final note = schedule.noteLinesFor(day);
    final onLeave = schedule.leaveOn(day);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: _isToday ? AppColors.accentBorder : AppColors.darkBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day header.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.darkSurfaceElevated,
            child: Row(
              children: [
                Text(day.label, style: AppTypography.label),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppDateFormatter.dayMonth(date),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
                const Spacer(),
                if (_isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentSurface,
                      borderRadius: AppRadius.fullAll,
                      border: Border.all(color: AppColors.accentBorder),
                    ),
                    child: Text(
                      'Today',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _ShiftRow(
            shift: ScheduleShift.morning,
            day: day,
            schedule: schedule,
            members: members,
          ),
          const Divider(height: 1, color: AppColors.darkBorder),
          _ShiftRow(
            shift: ScheduleShift.night,
            day: day,
            schedule: schedule,
            members: members,
          ),
          if (onLeave.isNotEmpty) _leaveLine(onLeave),
          if (note.isNotEmpty) _noteLine(note),
        ],
      ),
    );
  }

  Widget _leaveLine(Map<String, LeaveType> onLeave) {
    final parts = <String>[
      for (final entry in onLeave.entries)
        if (userForUid(entry.key, members) != null)
          '${nameForUid(entry.key, members)} (${entry.value.shortLabel})',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.beach_access_outlined,
              size: 15, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'On leave · ${parts.join(', ')}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteLine(List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined,
              size: 15, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              lines.join(' · '),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single shift's line inside a day card: label + hours on the left, the
/// people on it as chips (or an "Open" marker when nobody is assigned).
class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.shift,
    required this.day,
    required this.schedule,
    required this.members,
  });

  final ScheduleShift shift;
  final ScheduleDay day;
  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;

  @override
  Widget build(BuildContext context) {
    final uids = validAssignments(schedule.employeesFor(day, shift), members);
    final isMorning = shift == ScheduleShift.morning;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isMorning
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_round,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        shift.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.hoursFor(day, shift).format(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: uids.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Open',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < uids.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _PersonLine(user: userForUid(uids[i], members)!),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A person on a shift: avatar · name · role — the same avatar the editor uses,
/// so the read-only sheet and the editor render people identically.
class _PersonLine extends StatelessWidget {
  const _PersonLine({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final position = user.position?.trim();
    final role = (position != null && position.isNotEmpty)
        ? position
        : roleLabel(user.role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UserAvatar.fromUser(user, size: 30),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userDisplayName(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
