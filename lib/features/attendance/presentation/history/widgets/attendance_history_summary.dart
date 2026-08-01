import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';

/// The Attendance History summary strip, backed by the persisted
/// `attendance_expectations` reporting ledger. It never reconstructs reporting
/// numbers from raw attendance records or schedules.
class AttendanceHistorySummary extends StatefulWidget {
  const AttendanceHistorySummary({
    super.key,
    required this.isReview,
    required this.userId,
    required this.branchId,
    required this.window,
  });

  final bool isReview;
  final String? userId;
  final String? branchId;
  final AttendancePeriodWindow window;

  @override
  State<AttendanceHistorySummary> createState() =>
      _AttendanceHistorySummaryState();
}

class _AttendanceHistorySummaryState extends State<AttendanceHistorySummary> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistorySummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isReview != widget.isReview ||
        oldWidget.userId != widget.userId ||
        oldWidget.branchId != widget.branchId ||
        oldWidget.window != widget.window) {
      _sync();
    }
  }

  void _sync() {
    final cubit = context.read<AttendanceReportCubit>();
    if (widget.isReview) {
      cubit.watchBranchWindow(branchId: widget.branchId, window: widget.window);
    } else {
      cubit.watchUserWindow(userId: widget.userId, window: widget.window);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceReportCubit, AttendanceReportState>(
      builder: (context, state) {
        if (state.status == AttendanceReportStatus.error) {
          return const StatStrip(
            stats: [
              Stat(label: 'Attendance data', value: 'Unavailable'),
              Stat(label: 'Shifts recorded', value: '--'),
              Stat(label: 'Needs attention', value: '--'),
            ],
          );
        }
        if (state.status == AttendanceReportStatus.loading &&
            !state.coverage.hasRows) {
          return const StatStrip(
            stats: [
              Stat(label: 'Attendance data', value: 'Loading'),
              Stat(label: 'Shifts recorded', value: '--'),
              Stat(label: 'Needs attention', value: '--'),
            ],
          );
        }
        if (state.coverage.awaitingClose) {
          return const StatStrip(
            stats: [
              Stat(label: 'Attendance data', value: 'No data yet'),
              Stat(label: 'Shifts recorded', count: 0),
              Stat(label: 'Needs attention', value: '--'),
            ],
          );
        }
        return _SummaryStrip(state: state);
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final AttendanceReportState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    return Tooltip(
      message: [
        summary.showUpRate.describe(),
        summary.punctualArrivalRate.describe(),
      ].join('\n'),
      child: StatStrip(
        stats: [
          Stat(label: 'Present', count: summary.present),
          Stat(
            label: 'Absent',
            count: summary.absent,
            tone: summary.absent > 0 ? AppColors.error : null,
          ),
          if (summary.excused > 0)
            Stat(label: 'Excused', count: summary.excused),
          Stat(label: 'Show-up rate', value: _rate(summary.showUpRate)),
          Stat(
            label: 'Punctual arrivals',
            value: _rate(summary.punctualArrivalRate),
          ),
          Stat(label: 'Worked', value: _worked(summary.workedMinutes)),
          Stat(
            label: 'Payroll blockers',
            count: state.coverage.blockingExceptionRowCount,
            tone: state.coverage.blockingExceptionRowCount > 0
                ? AppColors.warning
                : null,
          ),
        ],
      ),
    );
  }

  static String _rate(AttendanceRate rate) {
    final percent = rate.percent;
    return percent == null ? '--' : '${percent.round()}%';
  }

  static String _worked(int minutes) {
    if (minutes <= 0) return '0h';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
