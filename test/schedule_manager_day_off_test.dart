import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:opshub/features/schedule/presentation/widgets/day_details_sheet.dart';

/// A manager works an open (presence) shift and never fills a Morning/Night
/// slot, but employees still need to see the manager's **day off**. So the day
/// sheet's Leave picker lets a manager mark their **own** day off — self only,
/// and always [LeaveType.dayOff] (no type choice). Everyone else is a branch
/// employee choosing any leave type. See `day_details_sheet._showLeavePicker`.

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingScheduleCubit extends Cubit<ScheduleState>
    implements ScheduleCubit {
  _RecordingScheduleCubit(super.view);

  final leaveCalls = <(ScheduleDay, String, LeaveType?)>[];

  @override
  Set<String> get previousSaturdayNight => const {};

  @override
  Future<bool> setLeave(ScheduleDay day, String uid, LeaveType? type) async {
    leaveCalls.add((day, uid, type));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserEntity _manager() => const UserEntity(
      uid: 'm1',
      email: 'm1@drop.test',
      displayName: 'Rana Fouad',
      authProvider: 'password',
      branchId: 'b1',
      role: UserRole.manager,
    );

UserEntity _admin() => const UserEntity(
      uid: 'a1',
      email: 'a1@drop.test',
      displayName: 'Admin Ali',
      authProvider: 'password',
      role: UserRole.admin,
    );

UserEntity _employee() => const UserEntity(
      uid: 'u1',
      email: 'u1@drop.test',
      displayName: 'Ziad Sewedy',
      authProvider: 'password',
      branchId: 'b1',
      role: UserRole.employee,
    );

WeeklyScheduleEntity _emptyWeek() => WeeklyScheduleEntity(
      id: 'b1_2026-07-05',
      branchId: 'b1',
      weekStart: DateTime(2026, 7, 5),
    );

Future<_RecordingScheduleCubit> _pumpSheet(
  WidgetTester tester, {
  required UserEntity currentUser,
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final scheduleCubit = _RecordingScheduleCubit(ScheduleState.loaded(
    branchId: 'b1',
    weekStart: DateTime(2026, 7, 5),
    schedule: _emptyWeek(),
    // The branch roster read returns the whole branch, manager included.
    members: [_manager(), _employee()],
  ));
  final authCubit = _FakeAuthCubit(currentUser);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<ScheduleCubit>.value(value: scheduleCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: DayDetailsSheet(day: ScheduleDay.sunday, canEdit: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scheduleCubit;
}

void main() {
  testWidgets('a manager can mark their OWN day off — self, and Day off only',
      (tester) async {
    final cubit = await _pumpSheet(tester, currentUser: _manager());

    await tester.tap(find.text('Add leave'));
    await tester.pumpAndSettle();

    // The picker offers the employee AND the editing manager themselves.
    expect(find.text('Ziad Sewedy'), findsOneWidget);
    expect(find.text('Rana Fouad'), findsOneWidget);

    await tester.tap(find.text('Rana Fouad'));
    await tester.pumpAndSettle();

    // Picked self ⇒ straight to Day off, no leave-type choice is shown.
    expect(find.text('Annual leave'), findsNothing);
    expect(find.text('Sick leave'), findsNothing);
    expect(cubit.leaveCalls,
        [(ScheduleDay.sunday, 'm1', LeaveType.dayOff)]);
  });

  testWidgets('an employee still gets the full leave-type choice',
      (tester) async {
    final cubit = await _pumpSheet(tester, currentUser: _manager());

    await tester.tap(find.text('Add leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ziad Sewedy'));
    await tester.pumpAndSettle();

    // An employee routes through the type picker — nothing is set yet.
    expect(find.text('Annual leave'), findsOneWidget);
    expect(find.text('Day off'), findsWidgets);
    expect(cubit.leaveCalls, isEmpty);
  });

  testWidgets('an admin editing cannot mark the manager off (manager self only)',
      (tester) async {
    await _pumpSheet(tester, currentUser: _admin());

    await tester.tap(find.text('Add leave'));
    await tester.pumpAndSettle();

    // Admin is not a branch manager, so the manager is not selectable here;
    // only branch employees are.
    expect(find.text('Ziad Sewedy'), findsOneWidget);
    expect(find.text('Rana Fouad'), findsNothing);
  });
}
