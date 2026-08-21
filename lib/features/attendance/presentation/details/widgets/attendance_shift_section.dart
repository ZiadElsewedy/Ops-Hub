import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// The **Shift** section of the Details screen — the payroll-relevant facts of
/// one record: the scheduled window (snapshotted at clock-in, so it's stable),
/// the actual clock in/out with their GPS verification, and the worked / late /
/// early-leave / overtime durations. Every duration is shown only when non-zero,
/// so a clean shift stays uncluttered.
class AttendanceShiftSection extends StatelessWidget {
  const AttendanceShiftSection({super.key, required this.record});

  final AttendanceEntity record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final scheduled = (r.scheduledStart != null && r.scheduledEnd != null)
        ? '${AppDateFormatter.time(r.scheduledStart!)} — '
            '${AppDateFormatter.time(r.scheduledEnd!)}'
        : 'Unscheduled';

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScheduledRow(shift: r.shift.label, window: scheduled),
          const SizedBox(height: AppSpacing.md),
          _ClockRow(
            label: 'Clock in',
            time: r.clockIn,
            verification: r.clockInVerification,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ClockRow(
            label: 'Clock out',
            time: r.clockOut,
            verification: r.clockOutVerification,
          ),
          const SizedBox(height: AppSpacing.md),
          _StatRow(label: 'Worked', value: _hm(r.workedMinutes), strong: true),
          if (r.lateMinutes > 0)
            _StatRow(
                label: 'Late by',
                value: _hm(r.lateMinutes),
                tone: AppColors.warning),
          if (r.earlyLeaveMinutes > 0)
            _StatRow(
                label: 'Left early',
                value: _hm(r.earlyLeaveMinutes),
                tone: AppColors.warning),
          if (r.overtimeMinutes > 0)
            _StatRow(
                label: 'Overtime',
                value: _hm(r.overtimeMinutes),
                tone: AppColors.success),
        ],
      ),
    );
  }
}

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({required this.shift, required this.window});
  final String shift;
  final String window;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SCHEDULED SHIFT',
                  style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 3),
              Text('$shift · $window',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockRow extends StatelessWidget {
  const _ClockRow({
    required this.label,
    required this.time,
    required this.verification,
  });
  final String label;
  final DateTime? time;
  final AttendanceVerification? verification;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  time == null ? '—' : AppDateFormatter.time(time!),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          if (v != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        v.verified
                            ? Icons.where_to_vote_rounded
                            : Icons.wrong_location_outlined,
                        size: 15,
                        color: v.verified
                            ? AppColors.success
                            : AppColors.warning),
                    const SizedBox(width: 4),
                    Text(v.verified ? 'At branch' : 'Off-site',
                        style: TextStyle(
                            color: v.verified
                                ? AppColors.success
                                : AppColors.warning,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${v.distanceMeters.round()} m · '
                  '±${(v.location.accuracyMeters ?? 0).round()} m',
                  style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            )
          else if (time != null)
            const Text('No GPS',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.tone,
    this.strong = false,
  });
  final String label;
  final String value;
  final Color? tone;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: tone ?? AppColors.textPrimary,
              fontSize: strong ? 16 : 15,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _hm(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  final h = m ~/ 60;
  final rem = m % 60;
  if (h == 0) return '${rem}m';
  return rem == 0 ? '${h}h' : '${h}h ${rem}m';
}
