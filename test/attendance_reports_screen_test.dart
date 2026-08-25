import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/presentation/reporting/attendance_monthly_report_screen.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:opshub/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:opshub/features/attendance/presentation/reporting/attendance_reports_screen.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReportingRepository implements AttendanceReportingRepository {
  final stream = StreamController<List<AttendanceLedgerRow>>.broadcast();
  String? watchedBranchId;

  void push(List<AttendanceLedgerRow> rows) => stream.add(rows);

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    watchedBranchId = branchId;
    return stream.stream;
  }

  @override
  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) => stream.stream;

  Future<void> close() => stream.close();
}

class _FakeBranchRepository implements BranchRepository {
  _FakeBranchRepository(this.branches);

  final List<BranchEntity> branches;

  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async => branches;

  @override
  Future<BranchEntity?> getBranch(String branchId, {bool forceRefresh = false}) async {
    for (final branch in branches) {
      if (branch.id == branchId) return branch;
    }
    return null;
  }

  @override
  Future<BranchEntity> createBranch(BranchEntity branch) async => branch;

  @override
  Future<void> updateBranch(BranchEntity branch) async {}

  @override
  Future<void> setBranchActive(String branchId, bool isActive) async {}

  @override
  Future<void> setGeofence(String branchId, BranchGeofence geofence) async {}

  @override
  Future<void> deleteBranch(String branchId) async {}

  @override
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  }) async => '';
}

const _branch = BranchEntity(id: 'DDwedTHvI1sPHrMz06PI', name: 'Cairo A');

const _manager = UserEntity(
  uid: 'manager1',
  email: 'manager@drop.test',
  displayName: 'Manager',
  authProvider: 'password',
  role: UserRole.manager,
  branchId: 'DDwedTHvI1sPHrMz06PI',
);

AttendanceLedgerRow _blockedPresent(
  String id, {
  required AttendanceLedgerOutcome outcome,
  required List<AttendanceExceptionCode> exceptionCodes,
  required int workedMinutes,
  int lateMinutes = 0,
}) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: 'DDwedTHvI1sPHrMz06PI',
  dayKey: '20260729',
  businessDate: '2026-07-29',
  shift: ScheduleShift.morning,
  outcome: outcome,
  expected: true,
  recordId: 'rec$id',
  workedMinutes: workedMinutes,
  lateMinutes: lateMinutes,
  exceptionCodes: exceptionCodes,
  locked: false,
  version: 1,
  source: 'system',
  closedAt: DateTime(2026, 7, 29, 18),
);

AttendanceLedgerRow _phantomAbsent(String id) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: 'DDwedTHvI1sPHrMz06PI',
  dayKey: '20260729',
  businessDate: '2026-07-29',
  shift: ScheduleShift.morning,
  outcome: AttendanceLedgerOutcome.absent,
  expected: true,
  recordId: null,
  locked: false,
  version: 1,
  source: 'system',
  closedAt: DateTime(2026, 7, 29, 18),
);

Future<
  (_FakeReportingRepository, AttendanceReportCubit, BranchCubit, _FakeAuthCubit)
>
_pumpReports(WidgetTester tester, {required Size size}) async {
  await tester.binding.setSurfaceSize(size);
  // Reset inside test scope: `setSurfaceSize` asserts `inTest`, so a bare
  // tearDown reset can fail outside the active widget test body.
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeReportingRepository();
  final reportCubit = AttendanceReportCubit(repository: repo);
  final branchCubit = BranchCubit(_FakeBranchRepository(const [_branch]));
  final authCubit = _FakeAuthCubit(_manager);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<BranchCubit>.value(value: branchCubit),
      ],
      child: MaterialApp(
        home: AttendanceReportsScreen(
          cubit: reportCubit,
          now: DateTime(2026, 7, 30, 14),
        ),
      ),
    ),
  );
  await tester.pump();
  return (repo, reportCubit, branchCubit, authCubit);
}

void _expectNoFlutterErrors(List<FlutterErrorDetails> errors) {
  expect(
    errors,
    isEmpty,
    reason: errors.map((error) => error.exceptionAsString()).join('\n'),
  );
}

/// Surfaces the IA redesign cut. None of these may come back on the hub while
/// it renders a single branch: every one of them restated a fact stated above
/// it, or spent a tile on something that is not built yet.
void _expectRetiredSurfacesAbsent() {
  for (final label in const [
    'Branch periods', // single-branch comparison table
    'Ready periods', // third vocabulary for closed-ness
    'Restatements', // hardcoded zero, never a real fact
    'Next reporting surfaces',
    'Per-employee report',
    'Period close',
    'Export ledger',
  ]) {
    expect(find.text(label), findsNothing, reason: '"$label" is retired');
  }
}

/// `find.byTooltip` matches the [Tooltip] IconButton builds internally, not the
/// button, so the button is resolved by its tooltip property instead.
IconButton _periodButton(WidgetTester tester, String tooltip) {
  return tester
      .widgetList<IconButton>(find.byType(IconButton))
      .firstWhere((button) => button.tooltip == tooltip);
}

/// The page names itself exactly once. It used to be titled by both the chrome
/// header and a PageHero directly beneath it.
void _expectSingleTitle() {
  expect(find.text('Attendance & Reports'), findsOneWidget);
}

/// Both report destinations stay reachable, and the unbuilt ones cost one line.
void _expectGoDeeper() {
  expect(find.text('Weekly report'), findsOneWidget);
  expect(find.text('Monthly report'), findsOneWidget);
  expect(find.text('Person history'), findsOneWidget);
  expect(
    find.text('Period close and export remain the next reporting surfaces.'),
    findsOneWidget,
  );
}

void main() {
  final previousOnError = FlutterError.onError;
  late List<FlutterErrorDetails> errors;

  setUp(() {
    errors = [];
    FlutterError.onError = (details) {
      errors.add(details);
    };
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
  });

  testWidgets('empty ledger renders awaiting-close without rate values', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpReports(
        tester,
        size: size,
      );

      repo.push(const []);
      await tester.pump();

      expect(repo.watchedBranchId, 'DDwedTHvI1sPHrMz06PI');
      expect(find.text('No data yet'), findsWidgets);
      expect(find.text('No data yet'), findsWidgets);
      expect(find.text('Show-up rate'), findsNothing);
      expect(find.text('0%'), findsNothing);
      expect(find.textContaining('0 /'), findsNothing);

      // No rows means no denominator, so the components of the rate are
      // withheld too — not rendered at zero.
      expect(find.text('Expected'), findsNothing);
      expect(find.text('Present'), findsNothing);
      expect(find.text('Absent'), findsNothing);

      // Blockers are unknowable before rows materialize, so the page must not
      // claim there are none.
      expect(
        find.text('Nothing to check until shifts are recorded.'),
        findsOneWidget,
      );
      expect(find.text('Nothing is waiting on you'), findsNothing);

      // Scope + period controls survive the restyle, including the
      // future-period block: 2026-07-30 sits in the current weekly window.
      expect(find.byTooltip('Refresh report'), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('attendance-reports-dashboard')),
        findsOneWidget,
      );
      expect(_periodButton(tester, 'Next period').onPressed, isNull);
      expect(_periodButton(tester, 'Previous period').onPressed, isNotNull);

      _expectSingleTitle();
      _expectGoDeeper();
      _expectRetiredSurfacesAbsent();
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  testWidgets('populated phantom rows render 0 percent over denominator 3', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpReports(
        tester,
        size: size,
      );

      repo.push([
        _phantomAbsent('1'),
        _phantomAbsent('2'),
        _phantomAbsent('3'),
      ]);
      await tester.pump();

      // The verdict: trust, then action. Closed-ness is stated once, in one
      // vocabulary, and a zero blocker count costs one quiet line.
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('3 of 3 shifts settled'), findsOneWidget);
      expect(find.text('Nothing is waiting on you'), findsOneWidget);

      // Rows present with zero clock-ins is a real 0% result, never the
      // no-data state — and the rate still discloses its denominator. Both
      // are asserted exactly once: the redesign's whole point is that each
      // fact is rendered once.
      expect(find.text('Show-up rate'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 / 3 scheduled shifts'), findsOneWidget);
      expect(find.text('No data yet'), findsNothing);

      // The components of that rate, at supporting weight. They are counts, so
      // they carry no denominator of their own — the headline owns it.
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Worked'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2)); // expected + absent
      expect(find.text('0'), findsOneWidget); // present

      // Punctual arrivals has no denominator with zero present rows, so it
      // collapses to one muted line instead of "--" over "0 / 0".
      expect(find.text('Punctual arrivals'), findsNothing);
      expect(find.text('Worked time'), findsNothing);
      expect(find.text('--'), findsNothing);
      expect(
        find.textContaining('no punctuality or worked time to show'),
        findsOneWidget,
      );

      _expectSingleTitle();
      _expectGoDeeper();
      _expectRetiredSurfacesAbsent();
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  testWidgets('blocking exceptions give the verdict weight and the queue', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpReports(
        tester,
        size: size,
      );

      repo.push([
        _blockedPresent(
          '1',
          outcome: AttendanceLedgerOutcome.worked,
          exceptionCodes: const [AttendanceExceptionCode.missingPunch],
          workedMinutes: 480,
        ),
        _blockedPresent(
          '2',
          outcome: AttendanceLedgerOutcome.workedLate,
          exceptionCodes: const [
            AttendanceExceptionCode.late,
            AttendanceExceptionCode.missingPunch,
          ],
          workedMinutes: 470,
          lateMinutes: 10,
        ),
      ]);
      await tester.pump();

      // A real blocker earns weight, colour and the affordance — the inverse of
      // the zero-state's single muted line.
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('2 of 2 shifts settled'), findsOneWidget);
      expect(find.text('Needs your decision'), findsOneWidget);
      expect(find.text('2 of 2 shifts still need a decision.'), findsOneWidget);
      expect(find.text('Review these'), findsOneWidget);
      expect(find.text('Nothing is waiting on you'), findsNothing);

      // Every rate still discloses its denominator, exactly once each.
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('2 / 2 scheduled shifts'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 / 2 people who showed up'), findsOneWidget);

      // With present rows the conditional pair has real denominators, so it
      // renders instead of collapsing.
      expect(find.text('Punctual arrivals'), findsOneWidget);
      expect(find.text('Worked time'), findsOneWidget);
      expect(find.text('15h 50m'), findsOneWidget);
      expect(find.text('Across 2 shifts worked'), findsOneWidget);
      expect(
        find.textContaining('no punctuality or worked time to show'),
        findsNothing,
      );

      _expectSingleTitle();
      _expectGoDeeper();
      _expectRetiredSurfacesAbsent();
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  test('the Monthly tile mints an id the Monthly report accepts', () {
    const branchId = 'DDwedTHvI1sPHrMz06PI';
    // The hub's period selector may be on Week. The Monthly tile must derive a
    // whole calendar month from the selected window's start date — never hand
    // the monthly route the seven-day window it is looking at.
    final selectedWeek = weeklyWindow(DateTime(2026, 7, 30, 14));
    final monthlyId = attendancePeriodId(
      type: AttendancePeriodType.monthly,
      scopeKey: branchId,
      window: monthlyWindow(
        selectedWeek.startDate.year,
        selectedWeek.startDate.month,
      ),
    );

    final parsed = MonthlyAttendancePeriodRef.tryParse(monthlyId);
    expect(parsed, isNotNull);
    expect(parsed!.branchId, branchId);
    expect(parsed.window.startDate, DateTime(2026, 7));
    expect(parsed.window.endDate.year, 2026);
    expect(parsed.window.endDate.month, 7);
    expect(parsed.window.endDate.day, 31);

    // The naive alternative — reusing the selected weekly window — is rejected
    // by the report's own parser. That is why the derivation exists.
    final reusedWeeklyWindow = attendancePeriodId(
      type: AttendancePeriodType.monthly,
      scopeKey: branchId,
      window: selectedWeek,
    );
    expect(MonthlyAttendancePeriodRef.tryParse(reusedWeeklyWindow), isNull);
  });
}
