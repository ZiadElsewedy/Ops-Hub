import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:opshub/features/attendance/presentation/admin/admin_attendance_overview_cubit.dart';
import 'package:opshub/features/attendance/presentation/admin/attendance_admin_workspace_screen.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';

/// The Admin workspace used to hang on its spinner forever whenever the branch
/// directory was **already loaded** before the screen mounted — which is the
/// normal case, because `BranchCubit` is an app-level singleton and the only way
/// into this screen (the Attendance & Reports hub) loads it first. `loadIfNeeded`
/// emitted nothing, so the `BlocListener` that started the ledger fan-out never
/// fired.
void main() {
  const branches = [
    BranchEntity(id: 'arkan', name: 'OpsHub | Arkan'),
    BranchEntity(id: 'lmd', name: 'OpsHub | LMD'),
    BranchEntity(id: 'closed', name: 'Old Branch', isActive: false),
  ];

  late _FakeReportingRepository reporting;
  late BranchCubit branchCubit;
  late AdminAttendanceOverviewCubit overviewCubit;

  setUp(() {
    reporting = _FakeReportingRepository();
    branchCubit = BranchCubit(_FakeBranchRepository(branches));
    overviewCubit = AdminAttendanceOverviewCubit(repository: reporting);
  });

  tearDown(() async {
    await overviewCubit.close();
    await branchCubit.close();
  });

  Future<void> pumpWorkspace(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<BranchCubit>.value(
          value: branchCubit,
          child: AttendanceAdminWorkspaceScreen(cubit: overviewCubit),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts the fan-out when branches were already loaded', (
    tester,
  ) async {
    // The regression: the hub loaded the directory before we ever got here.
    await branchCubit.load();
    expect(reporting.watched, isEmpty);

    await pumpWorkspace(tester);

    expect(
      reporting.watched,
      ['arkan', 'lmd'],
      reason: 'inactive branches are excluded; the fan-out must still start',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the workspace hung here forever before the bootstrap fix',
    );
  });

  testWidgets('still starts it when branches load after the screen mounts', (
    tester,
  ) async {
    await pumpWorkspace(tester);

    expect(reporting.watched, ['arkan', 'lmd']);
  });

  testWidgets('does not rebuild an identical fan-out', (tester) async {
    await branchCubit.load();
    await pumpWorkspace(tester);
    expect(reporting.watched, ['arkan', 'lmd']);

    // A directory refresh that changes nothing must not tear down and
    // re-subscribe every branch stream — `watched` would grow to four entries.
    await branchCubit.load();
    await tester.pumpAndSettle();

    expect(reporting.watched, ['arkan', 'lmd']);
  });
}

class _FakeReportingRepository implements AttendanceReportingRepository {
  /// Every branch stream ever subscribed, in order — so a redundant fan-out
  /// shows up as repeated ids rather than being invisible.
  final watched = <String>[];

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    watched.add(branchId);
    return Stream<List<AttendanceLedgerRow>>.value(const []);
  }

  @override
  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) => Stream<List<AttendanceLedgerRow>>.value(const []);
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
