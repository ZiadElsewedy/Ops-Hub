import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/widgets/task_badge.dart';

/// Verifies the task lifecycle badge mapping after the P1 dedupe (2026-07-03):
/// the badge now carries ONLY NEW (monochrome) and REWORK #n (amber). Approved
/// and Rejected were removed — the card's status pill already shows them, so a
/// badge for them stacked the word twice.
void main() {
  group('taskBadgeFor', () {
    test('a fresh pending task → NEW (monochrome)', () {
      final badge = taskBadgeFor(const TaskEntity(id: '1', title: 't'));
      expect(badge?.label, 'NEW');
      expect(badge?.color, AppColors.primary);
    });

    test('a task awaiting rework → REWORK #n (amber), with the revision number',
        () {
      final badge = taskBadgeFor(const TaskEntity(
        id: '1',
        title: 't',
        status: TaskStatus.rejected,
        requiresRework: true,
        revisionNumber: 2,
      ));
      expect(badge?.label, 'REWORK #2');
      expect(badge?.color, AppColors.warning);
    });

    test('an approved task → NO badge (the status pill already says "Approved")',
        () {
      expect(
        taskBadgeFor(const TaskEntity(
            id: '1', title: 't', status: TaskStatus.approved)),
        isNull,
      );
    });

    test('a terminally rejected task → NO badge (the pill carries the state)',
        () {
      expect(
        taskBadgeFor(const TaskEntity(
            id: '1', title: 't', status: TaskStatus.rejected)),
        isNull,
      );
    });

    test('rework still shows on a rejected task (it is not just the status)', () {
      final badge = taskBadgeFor(const TaskEntity(
        id: '1',
        title: 't',
        status: TaskStatus.rejected,
        requiresRework: true,
        revisionNumber: 1,
      ));
      expect(badge?.label, 'REWORK #1');
    });

    test('an in-progress task has no badge', () {
      expect(
        taskBadgeFor(const TaskEntity(
            id: '1', title: 't', status: TaskStatus.started)),
        isNull,
      );
    });
  });
}
