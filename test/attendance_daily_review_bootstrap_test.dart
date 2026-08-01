import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_state.dart';
import 'package:drop/features/attendance/presentation/daily/attendance_daily_review_screen.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';

/// Daily Review latches its one-shot load. The latch must be spent only once the
/// load is actually dispatched — burning it on a pass that bailed out (a session
/// still restoring behind a deep link) would strand the board on its spinner for
/// the life of the screen, with nothing to retry it.
void main() {
  const admin = UserEntity(
    uid: 'admin-1',
    email: 'admin@drop.test',
    displayName: 'Zoz',
    authProvider: 'password',
    role: UserRole.admin,
    branchId: 'arkan',
  );

  late _FakeAdminCubit board;
  late _FakeAuthCubit auth;

  setUp(() {
    board = _FakeAdminCubit();
    auth = _FakeAuthCubit(const AuthState.unauthenticated());
  });

  tearDown(() async {
    await board.close();
    await auth.close();
  });

  Future<void> pump(WidgetTester tester, {String dayKey = '20260729'}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<AuthCubit>.value(
          value: auth,
          child: AttendanceDailyReviewScreen(
            branchId: 'arkan',
            dayKey: dayKey,
            cubit: board,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads immediately when the session is already live', (
    tester,
  ) async {
    auth.emit(const AuthState.authenticated(admin));

    await pump(tester);
    await tester.pump();

    expect(board.loads, hasLength(1));
    expect(board.loads.single.branchId, 'arkan');
  });

  testWidgets('still loads when the session arrives after the screen mounts', (
    tester,
  ) async {
    // A deep link opened before auth finished restoring.
    await pump(tester);
    expect(board.loads, isEmpty);

    auth.emit(const AuthState.authenticated(admin));
    await tester.pump();
    await tester.pump();

    expect(
      board.loads,
      hasLength(1),
      reason: 'the latch must not have been spent by the bailed-out pass',
    );
  });

  testWidgets('loads exactly once across both paths', (tester) async {
    await pump(tester);
    auth.emit(const AuthState.authenticated(admin));
    await tester.pump();
    await tester.pump();

    // A later auth re-emit must not re-dispatch.
    auth.emit(const AuthState.authenticated(admin));
    await tester.pump();
    await tester.pump();

    expect(board.loads, hasLength(1));
  });

  testWidgets('a malformed day link loads nothing and says so', (tester) async {
    auth.emit(const AuthState.authenticated(admin));

    await pump(tester, dayKey: 'not-a-day');
    await tester.pump();

    expect(board.loads, isEmpty);
    expect(find.text('That day link is not valid'), findsOneWidget);
  });
}

class _Load {
  const _Load(this.uid, this.branchId, this.businessDate);
  final String uid;
  final String? branchId;
  final DateTime? businessDate;
}

class _FakeAdminCubit extends Cubit<AttendanceAdminState>
    implements AttendanceAdminCubit {
  _FakeAdminCubit() : super(const AttendanceAdminState.loading());

  final loads = <_Load>[];

  @override
  Future<void> load(
    UserEntity admin, {
    String? branchId,
    DateTime? businessDate,
  }) async {
    loads.add(_Load(admin.uid, branchId, businessDate));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initial);

  @override
  // ignore: unnecessary_overrides — widened so the test can drive auth directly.
  void emit(AuthState state) => super.emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
