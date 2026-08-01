import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/attendance_review_link.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_filters.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_weekly_employee_rows.dart';

/// The per-person drill-down: a report's "By person" row opens that person's own
/// ledger, scoped to the branch and period the row was read in.
void main() {
  const ziad = WeeklyAttendanceEmployeeAggregate(
    userId: 'u-ziad',
    displayName: 'Ziad Elsewedy',
    expected: 4,
    present: 0,
    absent: 4,
    lateMinutes: 0,
    workedMinutes: 0,
    overtimeMinutes: 0,
    exceptionCount: 0,
  );

  const salama = WeeklyAttendanceEmployeeAggregate(
    userId: 'u-salama',
    displayName: 'Salama',
    expected: 3,
    present: 3,
    absent: 0,
    lateMinutes: 0,
    workedMinutes: 1440,
    overtimeMinutes: 0,
    exceptionCount: 0,
  );

  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('By person rows', () {
    testWidgets('opening a row reports that row\'s employee', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        host(
          AttendanceWeeklyEmployeeRows(
            employees: const [ziad, salama],
            showStatus: true,
            onOpenEmployee: (e) => opened.add(e.displayName),
          ),
        ),
      );

      await tester.tap(find.text('Salama'));
      await tester.pump();

      expect(opened, ['Salama']);
    });

    testWidgets('the header row is never openable', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        host(
          AttendanceWeeklyEmployeeRows(
            employees: const [ziad],
            showStatus: true,
            onOpenEmployee: (e) => opened.add(e.displayName),
          ),
        ),
      );

      await tester.tap(find.text('Employee'));
      await tester.pump();

      expect(opened, isEmpty);
    });

    testWidgets('rows stay inert and unadvertised without a callback', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AttendanceWeeklyEmployeeRows(
            employees: [ziad],
            showStatus: true,
          ),
        ),
      );

      expect(
        find.textContaining('Open anyone to see their own records'),
        findsNothing,
      );
      await tester.tap(find.text('Ziad Elsewedy'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('says the rows open, since a phone has no hover', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AttendanceWeeklyEmployeeRows(
            employees: const [ziad],
            emptyMessage: 'Nobody has a recorded shift this month yet.',
            onOpenEmployee: (_) {},
          ),
        ),
      );

      expect(
        find.textContaining('Open anyone to see their own records'),
        findsOneWidget,
      );
    });
  });

  group('AttendanceReviewLink', () {
    test('pins the window only when both bounds are present', () {
      final full = AttendanceReviewLink(
        employeeName: 'Ziad Elsewedy',
        branchId: 'arkan',
        start: DateTime(2026, 7, 26),
        end: DateTime(2026, 8, 1),
      );
      final halfOpen = AttendanceReviewLink(
        employeeName: 'Ziad Elsewedy',
        start: DateTime(2026, 7, 26),
      );

      expect(full.hasWindow, isTrue);
      expect(halfOpen.hasWindow, isFalse);
      expect(
        const AttendanceReviewLink(employeeName: 'Ziad').hasWindow,
        isFalse,
      );
    });
  });

  group('reviewer search field', () {
    testWidgets('shows the name the ledger is already filtered to', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AttendanceHistoryFilters(
            query: const AttendanceHistoryQuery(text: 'Ziad Elsewedy'),
            onRange: (_, {start, end}) {},
            onStatus: (_) {},
            onToggleShift: (_) {},
            onSearch: (_) {},
            showSearch: true,
          ),
        ),
      );

      // Without this the list looks mysteriously short next to an empty box.
      expect(find.text('Ziad Elsewedy'), findsOneWidget);
    });

    testWidgets('stays empty when nothing is filtered', (tester) async {
      await tester.pumpWidget(
        host(
          AttendanceHistoryFilters(
            query: const AttendanceHistoryQuery(
              status: AttendanceStatusFilter.all,
            ),
            onRange: (_, {start, end}) {},
            onStatus: (_) {},
            onToggleShift: (_) {},
            onSearch: (_) {},
            showSearch: true,
          ),
        ),
      );

      expect(find.text('Search employee'), findsOneWidget);
    });
  });
}
