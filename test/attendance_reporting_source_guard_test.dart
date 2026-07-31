import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attendance reporting read path reads only the expectation ledger', () {
    /*
     * ADR-017 makes `attendance_expectations` the single source of truth for
     * attendance reporting. These files may aggregate ledger rows, but they must
     * not reconstruct report numbers from raw attendance records, rosters,
     * board code, analytics stats, or schedule reads.
     */
    const guardedFiles = [
      'lib/features/attendance/domain/reporting/attendance_ledger_row.dart',
      'lib/features/attendance/domain/repositories/attendance_reporting_repository.dart',
      'lib/features/attendance/data/models/attendance_ledger_model.dart',
      'lib/features/attendance/data/datasources/attendance_reporting_datasource.dart',
      'lib/features/attendance/data/repositories/attendance_reporting_repository_impl.dart',
      'lib/features/attendance/presentation/reporting/attendance_report_cubit.dart',
      'lib/features/attendance/presentation/reporting/attendance_report_state.dart',
      'lib/features/attendance/presentation/reporting/attendance_reports_screen.dart',
      'lib/features/attendance/domain/reporting/attendance_weekly_report.dart',
      'lib/features/attendance/domain/reporting/attendance_monthly_report.dart',
      'lib/features/attendance/presentation/reporting/attendance_weekly_report_screen.dart',
      'lib/features/attendance/presentation/reporting/attendance_monthly_report_screen.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_report_coverage.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_report_headline.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_report_metrics.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_report_scope_bar.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_weekly_daily_table.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_weekly_employee_rows.dart',
      'lib/features/attendance/presentation/reporting/widgets/attendance_monthly_week_buckets.dart',
      'lib/features/attendance/presentation/history/widgets/attendance_history_summary.dart',
    ];

    const forbidden = {
      'attendance_analytics.dart': 'AttendanceStats reconstruction',
      'AttendanceStats': 'AttendanceStats reconstruction',
      'attendance_history_query.dart': 'raw attendance history query path',
      'buildExpectedShiftRows':
          'client-side roster x attendance reconstruction',
      'attendance_board.dart': 'live board reconstruction path',
      'AttendanceCalculator': 'raw record minute recalculation',
      'ScheduleRepository': 'schedule repository read',
      'ScheduleRemoteDataSource': 'schedule datasource read',
      'ShiftTemplateRepository': 'schedule repository read',
      'ShiftTemplateRemoteDataSource': 'schedule datasource read',
      'features/schedule/data/datasources': 'schedule datasource import',
      'features/schedule/domain/repositories': 'schedule repository import',
    };

    for (final path in guardedFiles) {
      final source = File(path).readAsStringSync();
      for (final entry in forbidden.entries) {
        expect(
          source.contains(entry.key),
          isFalse,
          reason:
              '$path references `${entry.key}` (${entry.value}). '
              'Attendance reporting must read the ledger only; '
              'attendance_expectations is the single source of truth for '
              'reporting under ADR-017.',
        );
      }
    }
  });
}
