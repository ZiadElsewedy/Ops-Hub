import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_monthly_report_screen.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReportingRepository implements AttendanceReportingRepository {
  final stream = StreamController<List<AttendanceLedgerRow>>.broadcast();
  String? watchedBranchId;
  String? watchedStart;
  String? watchedEnd;

  void push(List<AttendanceLedgerRow> rows) => stream.add(rows);

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    watchedBranchId = branchId;
    watchedStart = startDayKey;
    watchedEnd = endDayKey;
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

const _branchId = 'DDwedTHvI1sPHrMz06PI';
const _otherBranchId = 'ikMkXApQQFeMsYFFu97X';
const _branch = BranchEntity(id: _branchId, name: 'Cairo A');

const _manager = UserEntity(
  uid: 'manager1',
  email: 'manager@drop.test',
  displayName: 'Manager',
  authProvider: 'password',
  role: UserRole.manager,
  branchId: _branchId,
);

final _window = monthlyWindow(2026, 7);
final _periodId = attendancePeriodId(
  type: AttendancePeriodType.monthly,
  scopeKey: _branchId,
  window: _window,
);

AttendanceLedgerRow _phantomAbsent(String id) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: _branchId,
  dayKey: '20260715',
  businessDate: '2026-07-15',
  shift: ScheduleShift.morning,
  outcome: AttendanceLedgerOutcome.absent,
  expected: true,
  recordId: null,
  locked: false,
  version: 1,
  source: 'system',
  closedAt: DateTime(2026, 7, 15, 18),
);

Future<
  (_FakeReportingRepository, AttendanceReportCubit, BranchCubit, _FakeAuthCubit)
>
_pumpMonthly(
  WidgetTester tester, {
  required Size size,
  String? periodId,
  UserEntity user = _manager,
}) async {
  await tester.binding.setSurfaceSize(size);
  // Reset inside test scope: `setSurfaceSize` asserts `inTest`, so calling it
  // from a bare `tearDown` (outside the test body) throws.
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeReportingRepository();
  final reportCubit = AttendanceReportCubit(repository: repo);
  final branchCubit = BranchCubit(_FakeBranchRepository(const [_branch]));
  final authCubit = _FakeAuthCubit(user);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<BranchCubit>.value(value: branchCubit),
      ],
      child: MaterialApp(
        home: AttendanceMonthlyReportScreen(
          periodId: periodId ?? _periodId,
          cubit: reportCubit,
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

  testWidgets('empty month renders ledger gap and no rate percentage', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpMonthly(
        tester,
        size: size,
      );

      repo.push(const []);
      await tester.pump();

      expect(repo.watchedBranchId, _branchId);
      expect(repo.watchedStart, '20260701');
      expect(repo.watchedEnd, '20260731');
      expect(find.text('No data yet'), findsWidgets);
      expect(find.text('Show-up rate'), findsNothing);
      expect(find.text('0%'), findsNothing);
      // Five Schedule weeks overlap July 2026, none of them with rows.
      expect(find.text('No data'), findsNWidgets(5));
      expect(find.textContaining('Jul 2026'), findsWidgets);
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  testWidgets('a no-show month with rows renders a real 0%', (tester) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpMonthly(
        tester,
        size: size,
      );

      repo.push([
        _phantomAbsent('1'),
        _phantomAbsent('2'),
        _phantomAbsent('3'),
      ]);
      await tester.pump();

      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Show-up rate'), findsOneWidget);
      expect(find.text('0%'), findsWidgets);
      expect(find.text('0 / 3 scheduled shifts'), findsOneWidget);
      expect(find.text('3 / 3 scheduled shifts'), findsOneWidget);
      // Only the 12-18 July bucket carries rows.
      expect(find.text('No data'), findsNWidgets(4));
      expect(find.text('Partial · 4 of 7 days in month'), findsOneWidget);
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  testWidgets('invalid period id shows a clear message without crashing', (
    tester,
  ) async {
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpMonthly(
      tester,
      size: const Size(390, 844),
      periodId: 'not-a-period',
    );

    expect(find.text('Invalid monthly report link'), findsOneWidget);
    expect(
      find.textContaining('Expected branch_monthly_YYYYMMDD'),
      findsOneWidget,
    );
    expect(repo.watchedBranchId, isNull);
    _expectNoFlutterErrors(errors);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });

  testWidgets('a weekly window period id is rejected as invalid', (
    tester,
  ) async {
    final weeklyShaped = attendancePeriodId(
      type: AttendancePeriodType.monthly,
      scopeKey: _branchId,
      window: weeklyWindow(DateTime(2026, 7, 30)),
    );
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpMonthly(
      tester,
      size: const Size(390, 844),
      periodId: weeklyShaped,
    );

    expect(find.text('Invalid monthly report link'), findsOneWidget);
    expect(repo.watchedBranchId, isNull);
    _expectNoFlutterErrors(errors);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });

  testWidgets('a manager cannot open another branch month', (tester) async {
    final crossBranchId = attendancePeriodId(
      type: AttendancePeriodType.monthly,
      scopeKey: _otherBranchId,
      window: _window,
    );
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpMonthly(
      tester,
      size: const Size(1280, 900),
      periodId: crossBranchId,
    );

    expect(find.text('Monthly report unavailable'), findsOneWidget);
    expect(
      find.textContaining('cannot open a monthly report for another branch'),
      findsOneWidget,
    );
    _expectNoFlutterErrors(errors);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });

  group('MonthlyAttendancePeriodRef.tryParse', () {
    test('accepts a whole calendar month', () {
      final ref = MonthlyAttendancePeriodRef.tryParse(_periodId);

      expect(ref, isNotNull);
      expect(ref!.branchId, _branchId);
      expect(ref.version, 1);
      expect(ref.window.startDate, DateTime(2026, 7));
      expect(ref.window.dayCount, 31);
    });

    test('accepts a branch id containing an underscore', () {
      final ref = MonthlyAttendancePeriodRef.tryParse(
        attendancePeriodId(
          type: AttendancePeriodType.monthly,
          scopeKey: 'cairo_a',
          window: _window,
        ),
      );

      expect(ref, isNotNull);
      expect(ref!.branchId, 'cairo_a');
    });

    test('rejects the weekly type segment', () {
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          attendancePeriodId(
            type: AttendancePeriodType.weekly,
            scopeKey: _branchId,
            window: weeklyWindow(DateTime(2026, 7, 30)),
          ),
        ),
        isNull,
      );
    });

    test('rejects a window that is not a whole month', () {
      // Starts mid-month.
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260702_20260731_v1',
        ),
        isNull,
      );
      // Ends before the last day.
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260701_20260730_v1',
        ),
        isNull,
      );
      // Spans two months.
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260701_20260831_v1',
        ),
        isNull,
      );
      // A weekly window carrying the monthly type segment.
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260726_20260801_v1',
        ),
        isNull,
      );
    });

    test('accepts a 28-day February and rejects a 29th day in it', () {
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260201_20260228_v1',
        ),
        isNotNull,
      );
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260201_20260229_v1',
        ),
        isNull,
      );
    });

    test('rejects a malformed version', () {
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260701_20260731_1',
        ),
        isNull,
      );
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260701_20260731_vx',
        ),
        isNull,
      );
      expect(
        MonthlyAttendancePeriodRef.tryParse(
          '${_branchId}_monthly_20260701_20260731_v0',
        ),
        isNull,
      );
    });

    test('rejects an empty scope key and a short id', () {
      expect(
        MonthlyAttendancePeriodRef.tryParse('_monthly_20260701_20260731_v1'),
        isNull,
      );
      expect(MonthlyAttendancePeriodRef.tryParse('monthly_2026_v1'), isNull);
    });
  });
}
