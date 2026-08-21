import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/swap_status.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/pages/my_schedule_screen.dart';

/// Guards the employee My Week tab — the premium hero/week-cards UI that is,
/// per the owner's 2026-07-07 ruling, THE employee schedule UI on every tier
/// (a minimal rework was reverted the same day; only in-language improvements
/// are allowed and are covered below: swap-on-today, un-truncated notes, the
/// next-shift line, live countdown states, the Swaps-tab dot).
///
/// Also the regression test for the mobile "blank My Week" bug: `TabBarView`
/// disposes the My Week tab when the user visits Swaps; on return the tab
/// remounts with its entrance AnimationController at 0.0, and — because the
/// ScheduleCubit is still `loaded` and emits nothing new — the BlocConsumer
/// listener that plays the animation never fires, leaving every section at
/// opacity 0 forever.
///
/// The fakes emit loading→loaded back-to-back so the (infinitely pulsing)
/// OpsHubLoadingState never mounts and pumpAndSettle terminates. Every test ends
/// by unmounting the tree — the hero's live countdown pill owns a minute-tick
/// Timer that must be disposed before the test completes.

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleCubit extends Cubit<ScheduleState>
    implements ScheduleCubit {
  _FakeScheduleCubit(this._view) : super(const ScheduleState.initial());
  final ScheduleState _view;

  /// `implements` fakes throw NoSuchMethodError on un-stubbed concrete
  /// members — the hero card reads this cubit-context getter if the suite
  /// happens to run inside the 00:00–00:30 weekend spill window, so it must
  /// be stubbed even though no test exercises it deliberately.
  @override
  Set<String> get previousSaturdayNight => const {};

  @override
  Future<void> load({
    required String branchId,
    DateTime? weekStart,
    bool force = false,
  }) async {
    emit(const ScheduleState.loading());
    emit(_view);
  }

  @override
  Future<void> refresh() => load(branchId: '');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShiftSwapCubit extends Cubit<ShiftSwapState>
    implements ShiftSwapCubit {
  _FakeShiftSwapCubit([this._swaps = const []])
      : super(const ShiftSwapState.initial());
  final List<ShiftSwapEntity> _swaps;

  @override
  Future<void> loadMine(String uid, {bool force = false}) async {
    emit(ShiftSwapState.loaded(_swaps));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserEntity _employee() => const UserEntity(
      uid: 'u1',
      email: 'u1@drop.test',
      displayName: 'Ziad Sewedy',
      authProvider: 'password',
      branchId: 'b1',
    );

WeeklyScheduleEntity _week({
  DateTime? weekStart,
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments = const {},
  Map<ScheduleDay, Map<String, LeaveType>> leave = const {},
  Map<ScheduleDay, String> dayNotes = const {},
  Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours = const {},
}) {
  final start = weekStart ?? ScheduleWeek.currentWeekStart();
  return WeeklyScheduleEntity(
    id: 'b1_week',
    branchId: 'b1',
    weekStart: start,
    assignments: assignments,
    leave: leave,
    dayNotes: dayNotes,
    shiftHours: shiftHours,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required WeeklyScheduleEntity schedule,
  List<ShiftSwapEntity> swaps = const [],
}) async {
  final user = _employee();
  final scheduleCubit = _FakeScheduleCubit(ScheduleState.loaded(
    branchId: 'b1',
    weekStart: schedule.weekStart,
    schedule: schedule,
    members: [user],
  ));
  final swapCubit = _FakeShiftSwapCubit(swaps);
  final authCubit = _FakeAuthCubit(user);
  addTearDown(() async {
    await scheduleCubit.close();
    await swapCubit.close();
    await authCubit.close();
  });
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: authCubit),
      BlocProvider<ScheduleCubit>.value(value: scheduleCubit),
      BlocProvider<ShiftSwapCubit>.value(value: swapCubit),
    ],
    child: const MaterialApp(home: MyScheduleScreen()),
  ));
  await tester.pumpAndSettle();
}

/// Disposes the tree so the countdown pill's pending minute Timer is
/// cancelled — without this every test fails with "A Timer is still pending".
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('My Week stays visible after visiting Swaps and returning',
      (tester) async {
    await _pump(
      tester,
      schedule: _week(assignments: {
        for (final day in ScheduleDay.values)
          day: {
            ScheduleShift.morning: ['u1'],
          },
      }),
    );

    // Nearest FadeTransition above the greeting = the entrance-stagger fade.
    double greetingOpacity() => tester
        .widget<FadeTransition>(find
            .ancestor(
              of: find.textContaining('👋'),
              matching: find.byType(FadeTransition),
            )
            .first)
        .opacity
        .value;

    expect(find.textContaining('👋'), findsOneWidget);
    expect(greetingOpacity(), 1.0, reason: 'initial entrance must complete');

    // Swaps tab and back — TabBarView disposes/remounts the My Week tab.
    await tester.tap(find.text('Swaps'));
    await tester.pumpAndSettle();
    expect(find.text('No swap requests'), findsOneWidget);

    await tester.tap(find.text('My Week'));
    await tester.pumpAndSettle();

    expect(find.textContaining('👋'), findsOneWidget);
    expect(
      greetingOpacity(),
      1.0,
      reason: 'the week must not remount invisible after returning from Swaps',
    );

    await _unmount(tester);
  });

  testWidgets(
      'week rows surface my leave, a note indicator and weekend closing hours',
      (tester) async {
    // Tall viewport so all seven (lazily-built) week rows are mounted.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      schedule: _week(
        assignments: {
          // Weekend night — must display the 00:00 close, not 23:00.
          ScheduleDay.thursday: {
            ScheduleShift.night: ['u1'],
          },
        },
        leave: {
          ScheduleDay.monday: {'u1': LeaveType.sick},
        },
        dayNotes: const {ScheduleDay.tuesday: 'Inventory'},
      ),
    );

    // Monday names the recorded leave instead of a generic "Off"; the note
    // shows as a glanceable "Note" indicator on the card (full text lives in
    // the tap-to-open sheet); the Thursday night row states the weekend close
    // in the arrow form. (`findsAtLeastNWidgets` — the today hero card may
    // duplicate one of these depending on the real weekday the test runs on.)
    expect(find.text('Sick Leave'), findsAtLeastNWidgets(1));
    expect(find.text('Note'), findsAtLeastNWidgets(1));
    expect(find.text('Inventory'), findsNothing,
        reason: 'the note text is not printed on the card, only an indicator');
    expect(find.text('16:00 → 00:00'), findsAtLeastNWidgets(1));
    expect(find.textContaining('23:00'), findsNothing);

    await _unmount(tester);
  });

  testWidgets(
      'a configured overnight close is what the employee sees (Saturday 01:00)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The business change lives in data, not code: Saturday night → 01:00.
    await _pump(
      tester,
      schedule: _week(
        assignments: {
          ScheduleDay.saturday: {
            ScheduleShift.night: ['u1'],
          },
        },
        shiftHours: {
          ScheduleDay.saturday: {
            ScheduleShift.night: const ShiftHours(990, 1500), // 16:30 → 01:00
          },
        },
      ),
    );

    // The row shows the configured close, not the standing weekend default.
    expect(find.text('16:30 → 01:00'), findsAtLeastNWidgets(1));
    expect(find.textContaining('00:30'), findsNothing,
        reason: 'the configured override replaces the standing default');

    await _unmount(tester);
  });

  // ─── In-language improvements (2026-07-07) ─────────────────────────────────

  testWidgets(
      'cards are clean (no Swap/Today/Past); Swap lives in the shift sheet, '
      'offered even on today\'s still-future shift',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Next week: every slot is strictly future. u1 on morning, u2 on night —
    // so a swap (morning ⇄ night, same day) is eligible on every day.
    await _pump(
      tester,
      schedule: _week(
        weekStart: ScheduleWeek.currentWeekStart().add(const Duration(days: 7)),
        assignments: {
          for (final day in ScheduleDay.values)
            day: {
              ScheduleShift.morning: ['u1'],
              ScheduleShift.night: ['u2'],
            },
        },
      ),
    );

    // Glanceable cards — no inline action fillers anywhere.
    expect(find.text('Swap'), findsNothing);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Past'), findsNothing);

    // The action lives in the tap-to-open sheet. Open today's from the hero;
    // its still-future morning shift must offer Swap (the old UI's redundant
    // "Today" pill used to block this).
    await tester.tap(find.text('View shift details'));
    await tester.pumpAndSettle();
    expect(find.text('Swap Shift'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('multi-line note: indicator on the card, full bullets in the sheet',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const note = 'Arrive 15 minutes early\n'
        'Inventory count before opening\n'
        'Ahmed will cover the fitting room';

    await _pump(
      tester,
      schedule: _week(
        assignments: {
          for (final day in ScheduleDay.values)
            day: {
              ScheduleShift.morning: ['u1'],
            },
        },
        dayNotes: {for (final day in ScheduleDay.values) day: note},
      ),
    );

    // The card carries a "3 notes" indicator, never the note text itself.
    expect(find.text('3 notes'), findsAtLeastNWidgets(1));
    expect(find.text('Arrive 15 minutes early'), findsNothing,
        reason: 'note bullets are not printed on the glanceable card');

    // Tap a shift → the sheet renders each line as its own un-truncated bullet.
    await tester.tap(find.text('View shift details'));
    await tester.pumpAndSettle();
    expect(find.text('Arrive 15 minutes early'), findsOneWidget);
    expect(find.text('Inventory count before opening'), findsOneWidget);
    expect(find.text('Ahmed will cover the fitting room'), findsOneWidget);
    final bullet =
        tester.widget<Text>(find.text('Ahmed will cover the fitting room'));
    expect(bullet.maxLines, isNull,
        reason: 'notes are first-class: never clamped');

    await _unmount(tester);
  });

  testWidgets('off-day hero names the exact leave and answers "when next?"',
      (tester) async {
    await _pump(
      tester,
      schedule: _week(
        leave: {
          ScheduleDay.today(): {'u1': LeaveType.sick},
        },
      ),
    );

    expect(find.text('Sick Leave'), findsAtLeastNWidgets(1));
    expect(find.text('Day Off'), findsNothing,
        reason: 'never a generic label when a leave record exists');
    // No shifts anywhere this week — deterministic regardless of weekday.
    expect(find.text('No more shifts this week'), findsOneWidget);

    await _unmount(tester);
  });

  group('Swaps tab dot (phone)', () {
    ShiftSwapEntity swapFor(String targetId, {DateTime? slotWeek}) =>
        ShiftSwapEntity(
          id: 's1',
          branchId: 'b1',
          // Next week's Sunday morning — always a still-future slot.
          weekStart: slotWeek ??
              ScheduleWeek.currentWeekStart().add(const Duration(days: 7)),
          day: ScheduleDay.sunday,
          shift: ScheduleShift.morning,
          requesterId: 'u2',
          requesterName: 'Omar',
          targetId: targetId,
          status: SwapStatus.pending,
        );

    testWidgets('shows while a swap on a future slot awaits my answer',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, schedule: _week(), swaps: [swapFor('u1')]);
      expect(find.byKey(const Key('swaps-tab-dot')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('never nags for a stale pending swap whose slot passed',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, schedule: _week(), swaps: [
        swapFor('u1',
            slotWeek: ScheduleWeek.currentWeekStart()
                .subtract(const Duration(days: 14))),
      ]);
      expect(find.byKey(const Key('swaps-tab-dot')), findsNothing);
      await _unmount(tester);
    });
  });

  group('WeeklyScheduleEntity.nextShiftAfter', () {
    test('finds the first slot strictly after the given day', () {
      final week = _week(assignments: {
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u1'],
        },
        ScheduleDay.thursday: {
          ScheduleShift.night: ['u1'],
        },
      });
      expect(week.nextShiftAfter('u1', ScheduleDay.monday),
          (ScheduleDay.thursday, ScheduleShift.night));
      expect(week.nextShiftAfter('u1', ScheduleDay.sunday),
          (ScheduleDay.monday, ScheduleShift.morning));
    });

    test('returns null when the week holds no further shifts', () {
      final week = _week(assignments: {
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u1'],
        },
      });
      expect(week.nextShiftAfter('u1', ScheduleDay.thursday), isNull);
      expect(week.nextShiftAfter('u1', ScheduleDay.saturday), isNull);
    });
  });

  group('WeeklyScheduleEntity.noteLinesFor', () {
    test('splits a multi-line note into trimmed, non-empty bullet lines', () {
      final week = _week(dayNotes: const {
        ScheduleDay.tuesday: 'Arrive 15 min early\n'
            '  Inventory count  \n'
            '\n'
            'Ahmed covers fitting room\n',
      });
      expect(week.noteLinesFor(ScheduleDay.tuesday), [
        'Arrive 15 min early',
        'Inventory count',
        'Ahmed covers fitting room',
      ]);
    });

    test('a single-line note is one bullet; no note is empty', () {
      final week = _week(dayNotes: const {ScheduleDay.monday: 'Big delivery'});
      expect(week.noteLinesFor(ScheduleDay.monday), ['Big delivery']);
      expect(week.noteLinesFor(ScheduleDay.tuesday), isEmpty);
    });
  });
}
