import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_week_review_repository.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_week_review.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:opshub/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:opshub/features/attendance/presentation/reporting/attendance_weekly_report_screen.dart';
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

const _branchId = 'DDwedTHvI1sPHrMz06PI';
const _branch = BranchEntity(id: _branchId, name: 'Cairo A');

const _manager = UserEntity(
  uid: 'manager1',
  email: 'manager@drop.test',
  displayName: 'Manager',
  authProvider: 'password',
  role: UserRole.manager,
  branchId: _branchId,
);

final _window = weeklyWindow(DateTime(2026, 7, 30));
final _periodId = attendancePeriodId(
  type: AttendancePeriodType.weekly,
  scopeKey: _branchId,
  window: _window,
);

AttendanceLedgerRow _phantomAbsent(String id) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: _branchId,
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
_pumpWeekly(WidgetTester tester, {required Size size, String? periodId}) async {
  await tester.binding.setSurfaceSize(size);
  // Reset inside test scope: `setSurfaceSize` asserts `inTest`, so calling it
  // from a bare `tearDown` (outside the test body) throws
  // "'inTest': is not true" instead of restoring the viewport.
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
        home: AttendanceWeeklyReportScreen(
          periodId: periodId ?? _periodId,
          cubit: reportCubit,
          weekReviewRepository: _FakeWeekReviewRepo(),
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

  testWidgets('empty week renders ledger gap and no rate percentage', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpWeekly(
        tester,
        size: size,
      );

      repo.push(const []);
      await tester.pump();

      expect(repo.watchedBranchId, _branchId);
      expect(repo.watchedStart, '20260726');
      expect(repo.watchedEnd, '20260801');
      expect(find.text('No data yet'), findsWidgets);
      expect(find.text('Show-up rate'), findsNothing);
      expect(find.text('0%'), findsNothing);
      expect(find.text('Sunday 26 Jul'), findsOneWidget);
      expect(find.text('Saturday 1 Aug'), findsOneWidget);
      expect(find.text('No data'), findsNWidgets(7));
      expect(find.text('Not closed'), findsNothing);
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  testWidgets('production-shape no-shows render 0% on desktop and mobile', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpWeekly(
        tester,
        size: size,
      );

      repo.push([
        _phantomAbsent('1'),
        _phantomAbsent('2'),
        _phantomAbsent('3'),
      ]);
      await tester.pump();

      // 3 rows on one day of seven: the pipeline calls that fully closed, the
      // manager is told the week is still in progress.
      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Fully closed'), findsNothing);

      // The week in one line — counts, never a store-level percentage.
      expect(find.text('0 of 3 shifts worked · 0h'), findsOneWidget);
      expect(find.text('Show-up rate'), findsNothing);
      expect(find.text('0%'), findsNothing);

      // The four KPIs, and only those four.
      expect(find.text('Hours worked'), findsOneWidget);
      // Also a column header in the person table, hence findsWidgets.
      expect(find.text('Overtime'), findsWidgets);
      expect(find.text('Unexcused absences'), findsOneWidget);
      expect(find.text('Late arrivals'), findsOneWidget);
      expect(find.text('Punctual arrivals'), findsNothing);
      expect(find.text('Needs attention'), findsNothing);
      // 3 of 3 expected shifts went unworked.
      expect(find.text('3 of 3 scheduled shifts'), findsOneWidget);

      expect(find.text('Wednesday 29 Jul'), findsOneWidget);
      expect(find.text('No data'), findsNWidgets(6));

      // The evidence table left the manager surface with the eight-section
      // structure, taking the per-row record link with it.
      expect(find.text('Every shift'), findsNothing);
      expect(find.text('No clock-in recorded'), findsNothing);
      expect(find.text('Open record'), findsNothing);

      // Everyone is absent, so every person row bands as Absent.
      expect(find.text('By person'), findsOneWidget);
      expect(find.text('Absent'), findsWidgets);
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
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpWeekly(
      tester,
      size: const Size(390, 844),
      periodId: 'not-a-period',
    );

    expect(find.text('Invalid weekly report link'), findsOneWidget);
    expect(
      find.textContaining('Expected branch_weekly_YYYYMMDD'),
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
}


/// Nobody has reviewed the week. Injected rather than reaching into DI — a
/// widget that reads a `late final` singleton cannot be pumped in a test.
class _FakeWeekReviewRepo implements AttendanceWeekReviewRepository {
  @override
  Stream<AttendanceWeekReview?> watchWeekReview({
    required String branchId,
    required DateTime weekStart,
  }) => Stream.value(null);

  @override
  Future<void> markReviewed(AttendanceWeekReview review) async {}

  @override
  Future<void> reopen({
    required String branchId,
    required DateTime weekStart,
  }) async {}
}
