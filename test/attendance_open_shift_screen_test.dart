import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_location_policy.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_validation.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:drop/features/attendance/presentation/pages/attendance_screen.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';

/// The personal clock screen for a **manager** — the open-shift presence model
/// (`enforceSchedule: false`) and the switched-off explanatory state
/// (`managersCanClock` → `enabled: false`). Pins the two states the redesign
/// added: a manager must land on a real Clock In, not "No shift today", and a
/// switched-off branch must say so rather than showing a dead clock.
void main() {
  const manager = UserEntity(
    uid: 'mgr-1',
    email: 'mgr@drop.test',
    displayName: 'Manager',
    authProvider: 'password',
    role: UserRole.manager,
    branchId: 'arkan',
  );

  late _FakeAttendanceCubit cubit;
  late _FakeAuthCubit auth;

  setUp(() {
    cubit = _FakeAttendanceCubit();
    auth = _FakeAuthCubit(const AuthState.authenticated(manager));
  });

  tearDown(() async {
    await cubit.close();
    await auth.close();
  });

  Future<void> pump(WidgetTester tester, AttendanceState state) async {
    cubit.emit(state);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<AttendanceCubit>.value(value: cubit),
          ],
          child: const AttendanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AttendanceState presence({required bool enabled}) => AttendanceState.loaded(
        shift: ScheduleShift.morning,
        config: AttendanceConfig(
          enabled: enabled,
          enforceSchedule: false,
          // No geofence ⇒ the effective policy the cubit would resolve; keeps
          // the ready view free of a GPS gate for this presentation test.
          locationPolicy: AttendanceLocationPolicy.none,
        ),
        tick: DateTime(2026, 8, 6, 10),
      );

  testWidgets('a manager lands on an open shift, not "No shift today"',
      (tester) async {
    cubit.check = AttendanceCheck.ok;
    await pump(tester, presence(enabled: true));

    expect(find.text('OPEN SHIFT'), findsOneWidget);
    expect(find.text('Manager shift'), findsOneWidget);
    expect(find.text('Clock In'), findsOneWidget);
    expect(find.text('No shift today'), findsNothing);
  });

  testWidgets('a switched-off branch explains, it does not show a dead clock',
      (tester) async {
    await pump(tester, presence(enabled: false));

    expect(find.text('Clocking is off for managers here'), findsOneWidget);
    expect(find.text('Review branch attendance'), findsOneWidget);
    expect(find.text('Clock In'), findsNothing);
  });
}

class _FakeAttendanceCubit extends Cubit<AttendanceState>
    implements AttendanceCubit {
  _FakeAttendanceCubit() : super(const AttendanceState.initial());

  AttendanceCheck check = AttendanceCheck.ok;

  @override
  AttendanceCheck get clockInCheck => check;

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  Future<void> previewLocation() async {}

  @override
  void emit(AttendanceState state) => super.emit(state);

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
