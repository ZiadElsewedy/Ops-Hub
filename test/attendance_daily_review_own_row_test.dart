import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/attendance/domain/attendance_board.dart';
import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_admin_state.dart';
import 'package:opshub/features/attendance/presentation/daily/attendance_daily_review_screen.dart';
import 'package:opshub/features/attendance/presentation/widgets/attendance_manager_actions.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';

/// UI contract for the "no self-approval" rule on Daily Review: a manager may
/// not settle their OWN shift (enforced server-side in `firestore.rules`), so on
/// their own row the direct-action buttons are replaced by a notice pointing to
/// the correction path. Every OTHER row is unchanged. This is presentation only
/// — the server stays the gate; the UI just stops offering an action that would
/// always fail.
void main() {
  const branchId = 'arkan';
  const manager = UserEntity(
    uid: 'mgr-1',
    email: 'mgr@drop.test',
    authProvider: 'password',
    displayName: 'Aaa Manager',
    role: UserRole.manager,
    branchId: branchId,
  );

  // The day under review is over: 2026-07-13, opened the next morning.
  final day = DateTime(2026, 7, 13);
  final morningStart = DateTime(2026, 7, 13, 8, 30);
  final morningEnd = DateTime(2026, 7, 13, 16, 30);
  final nextMorning = DateTime(2026, 7, 14, 9);

  AttendanceRosterEntry roster(String uid, String name) => AttendanceRosterEntry(
        uid: uid,
        name: name,
        shift: ScheduleShift.morning,
        scheduledStart: morningStart,
        scheduledEnd: morningEnd,
      );

  // A shift that clocked in but never out → pendingReview → a missingClockOut
  // review item carrying a direct "Set the time" action.
  AttendanceEntity unclosed(String uid, String name) => AttendanceEntity(
        id: '${uid}_20260713_morning',
        userId: uid,
        userName: name,
        branchId: branchId,
        shift: ScheduleShift.morning,
        date: day,
        scheduledStart: morningStart,
        scheduledEnd: morningEnd,
        clockIn: morningStart,
        status: AttendanceStatus.pendingReview,
      );

  late _FakeAdminCubit cubit;
  late _FakeAuthCubit auth;

  setUp(() {
    auth = _FakeAuthCubit(const AuthState.authenticated(manager));
  });

  tearDown(() async {
    await cubit.close();
    await auth.close();
  });

  Future<void> pumpReview(WidgetTester tester, AttendanceBoard board) async {
    cubit = _FakeAdminCubit(
      AttendanceAdminState.loaded(
        branchId: branchId,
        board: board,
        now: nextMorning,
      ),
    );
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<AttendanceAdminCubit>.value(value: cubit),
          ],
          child: AttendanceDailyReviewScreen(
            branchId: branchId,
            dayKey: attendanceDayKey(day),
            cubit: cubit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    "a manager's own row shows the correction notice, not the review buttons",
    (tester) async {
      final board = computeAttendanceBoard(
        roster: [roster('mgr-1', 'Aaa Manager'), roster('emp-9', 'Zzz Employee')],
        records: [unclosed('mgr-1', 'Aaa Manager'), unclosed('emp-9', 'Zzz Employee')],
        now: nextMorning,
      );

      await pumpReview(tester, board);

      // The own row explains the rule instead of offering a doomed action.
      expect(
        find.textContaining("You can't review your own shift"),
        findsOneWidget,
      );
      // The employee's row still offers the direct action — exactly once, so the
      // manager's own row is confirmed to have dropped its copy.
      expect(find.text('Set the time'), findsOneWidget);
    },
  );

  testWidgets(
    'a board with no own row is completely unchanged (buttons, no notice)',
    (tester) async {
      final board = computeAttendanceBoard(
        roster: [roster('emp-8', 'Employee Eight'), roster('emp-9', 'Employee Nine')],
        records: [unclosed('emp-8', 'Employee Eight'), unclosed('emp-9', 'Employee Nine')],
        now: nextMorning,
      );

      await pumpReview(tester, board);

      expect(find.text('Set the time'), findsNWidgets(2));
      expect(find.textContaining("You can't review your own shift"), findsNothing);
    },
  );

  testWidgets('OwnAttendanceNotice states the correction path', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OwnAttendanceNotice()),
      ),
    );

    expect(
      find.textContaining("You can't review your own shift"),
      findsOneWidget,
    );
    expect(find.textContaining('File a correction'), findsOneWidget);
  });
}

class _FakeAdminCubit extends Cubit<AttendanceAdminState>
    implements AttendanceAdminCubit {
  _FakeAdminCubit(super.initial);

  // The screen re-dispatches load() in a post-frame callback; keep it a no-op so
  // the seeded loaded state stands.
  @override
  Future<void> load(
    UserEntity user, {
    String? branchId,
    DateTime? businessDate,
  }) async {}

  @override
  void emit(AttendanceAdminState state) => super.emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initial);

  @override
  void emit(AuthState state) => super.emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
