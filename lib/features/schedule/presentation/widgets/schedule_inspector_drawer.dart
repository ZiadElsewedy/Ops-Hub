import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/employee_week_stats.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/schedule_insights.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The Mac inspector drawer docked beside the schedule grid (Schedule V2).
///
/// Default view: the week overview + a tappable team roster. Selecting a person
/// swaps in their **week detail** — hours (from the week's resolved shift
/// hours), days worked, the longest streak and days off. Everything is derived
/// read-only from the loaded roster; the widget owns no state and performs no
/// writes — selection is lifted to the parent via [onSelect], so it drops
/// cleanly into a stateless test.
class ScheduleInspectorDrawer extends StatelessWidget {
  const ScheduleInspectorDrawer({
    super.key,
    required this.schedule,
    required this.members,
    required this.insights,
    required this.selectedUid,
    required this.onSelect,
    this.onCollapse,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final ScheduleInsights insights;

  /// The employee whose detail is shown; null = the overview. Ignored if the
  /// roster no longer contains them (the drawer falls back to the overview).
  final String? selectedUid;
  final ValueChanged<String?> onSelect;

  /// When provided, the rail shows a compact header with a collapse control
  /// (the host hides the whole rail). Null on touch / in isolation tests, where
  /// the drawer is just content and fills whatever width it's given.
  final VoidCallback? onCollapse;

  UserEntity? get _selected {
    if (selectedUid == null) return null;
    for (final m in members) {
      if (m.uid == selectedUid) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final content = selected == null ? _overview() : _employee(selected);
    return Container(
      decoration: const BoxDecoration(
        // A softer hairline than the standard border — the rail should recede
        // so the grid stays the hero (Schedule V2 layout rebalance). Fills the
        // width the host gives it, so the rail can collapse / resize cleanly.
        border: Border(left: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: onCollapse == null
          ? content
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _railHeader(),
                Expanded(child: content),
              ],
            ),
    );
  }

  /// The rail's own chrome — a quiet identity label + a collapse control, so
  /// the manager can dismiss the panel from within it (the grid then reclaims
  /// the width). Only present when the host wires [onCollapse].
  Widget _railHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 4),
      child: Row(
        children: [
          Expanded(child: _sectionLabel('Inspector')),
          Tooltip(
            message: 'Hide inspector',
            child: InkWell(
              onTap: onCollapse,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Overview: week totals + team roster ────────────────────────
  Widget _overview() {
    final roster = [...members]
      ..sort((a, b) => userDisplayName(a)
          .toLowerCase()
          .compareTo(userDisplayName(b).toLowerCase()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.xl),
      children: [
        _sectionLabel('This week'),
        const SizedBox(height: AppSpacing.sm),
        _statRow('Morning', '${insights.morningAssignments}'),
        _statRow('Night', '${insights.nightAssignments}'),
        if (insights.leaveEntries > 0)
          _statRow('On leave', '${insights.leaveEntries}'),
        _statRow('Open shifts', '${insights.openCount}'),
        _statRow('People scheduled', '${insights.scheduledPeople}'),
        if (roster.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _sectionLabel('Team · tap for detail'),
          const SizedBox(height: AppSpacing.sm),
          for (final m in roster) _teamRow(m),
        ],
      ],
    );
  }

  Widget _teamRow(UserEntity member) {
    final stats = computeEmployeeWeekStats(schedule, member.uid);
    final position = member.position?.trim();
    return InkWell(
      onTap: () => onSelect(member.uid),
      borderRadius: AppRadius.lgAll,
      hoverColor: const Color(0x12FFFFFF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            UserAvatar.fromUser(member, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortName(member),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                  if (position != null && position.isNotEmpty)
                    Text(
                      position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stats.isEmpty
                  ? 'Off'
                  : '${stats.workedDays}d · ${stats.hoursLabel}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ── Employee detail ────────────────────────────────────────────
  Widget _employee(UserEntity member) {
    final stats = computeEmployeeWeekStats(schedule, member.uid);
    final position = member.position?.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.xl),
      children: [
        InkWell(
          onTap: () => onSelect(null),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Team',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            UserAvatar.fromUser(member, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userDisplayName(member),
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (position != null && position.isNotEmpty)
                    Text(position,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('This week'),
        const SizedBox(height: AppSpacing.sm),
        _statRow('Weekly hours', stats.hoursLabel),
        _statRow('Days worked', '${stats.workedDays}'),
        _statRow('Weekend days', '${stats.weekendCount}'),
        _statRow('Consecutive days', '${stats.longestRun}'),
        _statRow(
          'Days off',
          stats.offDays.isEmpty
              ? 'None'
              : '${stats.offDays.length} · '
                  '${stats.offDays.map((d) => d.shortLabel).join(', ')}',
        ),
      ],
    );
  }

  // ── Shared bits ────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          // The value can be long (e.g. a list of days off) — let it wrap and
          // stay right-aligned rather than overflow the fixed-width drawer.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
