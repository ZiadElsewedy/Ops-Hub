import 'package:flutter/material.dart';
import 'package:opshub/core/enums/attendance_source.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/status_badge.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// One day in the Attendance History ledger — a compact, tappable record card.
/// Shows the date/weekday (or the employee name in a reviewer list), the status
/// badge, the scheduled shift, clock in → out, worked hours, and quiet indicator
/// chips for late / early-leave / overtime / corrected. Everything comes from the
/// record snapshot, so a card never re-derives against today's schedule.
class AttendanceRecordCard extends StatelessWidget {
  const AttendanceRecordCard({
    super.key,
    required this.record,
    this.onTap,
    this.showEmployee = false,
  });

  final AttendanceEntity record;
  final VoidCallback? onTap;

  /// Reviewer list — lead with the employee's name and demote the date to the
  /// meta line. Self-history leads with the date.
  final bool showEmployee;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final indicators = _indicators(r);
    final title = showEmployee
        ? (r.userName ?? 'Employee')
        : AppDateFormatter.weekdayDayMonth(r.date);
    final meta = showEmployee
        ? '${AppDateFormatter.dayMonth(r.date)} · ${r.shift.label}'
        : '${r.shift.label} shift';

    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge.attendance(r.status),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            meta,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _clockLine(r)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _worked(r),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (indicators.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: indicators,
            ),
          ],
        ],
      ),
    );
  }

  /// The "in → out" line with a GPS glyph, or a quiet dash for a no-clock day
  /// (absent / on leave).
  Widget _clockLine(AttendanceEntity r) {
    if (!r.hasClockedIn) {
      return const Text(
        'No clock-in',
        style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
      );
    }
    final v = r.clockInVerification;
    return Row(
      children: [
        if (v != null) ...[
          Icon(
            v.verified ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            size: 13,
            color: v.verified ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            '${AppDateFormatter.time(r.clockIn!)} → '
            '${r.clockOut == null ? '…' : AppDateFormatter.time(r.clockOut!)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  String _worked(AttendanceEntity r) {
    if (r.isOpen) return 'Working';
    if (!r.hasClockedIn) return '—';
    return _hm(r.workedMinutes);
  }

  List<Widget> _indicators(AttendanceEntity r) => [
        if (r.isLate)
          _Indicator(label: 'Late ${_hm(r.lateMinutes)}', tint: AppColors.warning),
        if (r.hasEarlyLeave)
          _Indicator(
              label: 'Left early ${_hm(r.earlyLeaveMinutes)}',
              tint: AppColors.warning),
        if (r.hasOvertime)
          _Indicator(
              label: 'OT ${_hm(r.overtimeMinutes)}', tint: AppColors.success),
        // An excused record is materialized via a correction, but the "Excused"
        // status badge already tells that story — a "Corrected" chip would just
        // read as noise next to it.
        if (r.source == AttendanceSource.correction && !r.isExcused)
          _Indicator(label: 'Corrected', tint: AppColors.textSecondary),
        if (r.isUnscheduled)
          _Indicator(label: 'Unscheduled', tint: AppColors.textTertiary),
      ];

  static String _hm(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.label, required this.tint});
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint == AppColors.textTertiary ? AppColors.textSecondary : tint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
