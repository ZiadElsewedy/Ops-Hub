import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/shift_hours_scope.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';

/// Schedule V2 · Pillar 5 — `ScheduleCubit.applyShiftHours` routes the manager's
/// scope choice to the right write, and a new week snapshots the branch plan.
/// This is the "global vs local updates" contract.
class _FakeGetUsers implements GetUsersByBranch {
  @override
  Future<List<UserEntity>> call(String branchId) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingSchedule implements ScheduleRepository {
  bool setHoursCalled = false;
  ShiftHours? setHours;
  bool restampCalled = false;
  ShiftPlan? restampPlan;
  bool createCalled = false;
  ShiftPlan? createPlan;

  @override
  Future<WeeklyScheduleEntity?> getSchedule(String b, DateTime w) async => null;

  @override
  Future<WeeklyScheduleEntity> createSchedule({
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
    ShiftPlan? shiftPlan,
  }) async {
    createCalled = true;
    createPlan = shiftPlan;
    return WeeklyScheduleEntity(
        id: 'x', branchId: branchId, weekStart: weekStart, shiftPlan: shiftPlan);
  }

  @override
  Future<void> setShiftHours({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required ShiftHours? hours,
  }) async {
    setHoursCalled = true;
    setHours = hours;
  }

  @override
  Future<void> restampShiftPlan({
    required String branchId,
    required DateTime fromWeek,
    required ShiftPlan plan,
  }) async {
    restampCalled = true;
    restampPlan = plan;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingTemplates implements ShiftTemplateRepository {
  _RecordingTemplates(this.set);
  final ShiftTemplateSet set;
  bool upsertCalled = false;
  ShiftTemplate? upserted;

  @override
  Future<ShiftTemplateSet> ensureDefaults(String branchId) async => set;
  @override
  Future<ShiftTemplateSet> getSet(String branchId) async => set;
  @override
  Future<List<ShiftTemplate>> getTemplates(String branchId) async =>
      set.templates;
  @override
  Stream<List<ShiftTemplate>> watchTemplates(String branchId) =>
      Stream.value(set.templates);
  @override
  Future<void> upsertTemplate(ShiftTemplate template) async {
    upsertCalled = true;
    upserted = template;
  }

  @override
  Future<void> deleteTemplate(String id) async {}
}

void main() {
  final defaults = ShiftTemplateSet(
      ShiftTemplateSet.defaultsFor('b1', idFor: (r) => 'b1__${r.value}'));

  late _RecordingSchedule sched;
  late _RecordingTemplates templates;
  late ScheduleCubit cubit;

  setUp(() async {
    sched = _RecordingSchedule();
    templates = _RecordingTemplates(defaults);
    cubit = ScheduleCubit(sched, _FakeGetUsers(), templates);
    await cubit.load(branchId: 'b1');
  });

  tearDown(() => cubit.close());

  test('thisWeek → a per-slot override only', () async {
    await cubit.applyShiftHours(ScheduleDay.sunday, ScheduleShift.morning,
        const ShiftHours(540, 1020), ShiftHoursScope.thisWeek);
    expect(sched.setHoursCalled, isTrue);
    expect(sched.setHours, const ShiftHours(540, 1020));
    expect(templates.upsertCalled, isFalse);
    expect(sched.restampCalled, isFalse);
  });

  test('future → updates the template, no restamp, no this-week override',
      () async {
    await cubit.applyShiftHours(ScheduleDay.sunday, ScheduleShift.night,
        const ShiftHours(900, 1380), ShiftHoursScope.future);
    expect(templates.upsertCalled, isTrue);
    expect(templates.upserted!.role, ShiftTemplateRole.weekdayNight);
    expect(templates.upserted!.hours, const ShiftHours(900, 1380));
    expect(sched.restampCalled, isFalse);
    expect(sched.setHoursCalled, isFalse);
  });

  test('global → updates the template AND restamps current/future weeks',
      () async {
    await cubit.applyShiftHours(ScheduleDay.thursday, ScheduleShift.night,
        const ShiftHours(960, 1560), ShiftHoursScope.global);
    expect(templates.upsertCalled, isTrue);
    expect(templates.upserted!.role, ShiftTemplateRole.weekendNight);
    expect(sched.restampCalled, isTrue);
    // The restamped plan carries the edit; the other roles are unchanged.
    expect(sched.restampPlan!.weekendNight, const ShiftHours(960, 1560));
    expect(sched.restampPlan!.morning, defaults.plan.morning);
    expect(sched.setHoursCalled, isFalse);
  });

  test('createSchedule snapshots the branch plan onto the new week', () async {
    await cubit.createSchedule();
    expect(sched.createCalled, isTrue);
    expect(sched.createPlan, defaults.plan);
  });
}
