import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';

/// The task assignment mode. The UI wording moved from "Employee / Team" to
/// "Individual / Group" (Group is an ad-hoc set of hand-picked people, not a
/// standing org unit) — these tests pin the thing that must NOT move with it:
/// the persisted values, which every existing `tasks/{id}.assignmentType`
/// document and the `== 'shift'` check in `firestore.rules` depend on.
void main() {
  group('TaskAssignmentType', () {
    test('persisted values are the lower-case enum names — never renamed', () {
      expect(TaskAssignmentType.individual.value, 'individual');
      expect(TaskAssignmentType.team.value, 'team');
      expect(TaskAssignmentType.shift.value, 'shift');
    });

    test('labels read Individual / Group / Shift', () {
      expect(TaskAssignmentType.individual.label, 'Individual');
      expect(TaskAssignmentType.team.label, 'Group');
      expect(TaskAssignmentType.shift.label, 'Shift');
    });

    test('the rename is label-only: no label leaks into storage', () {
      // If someone ever "tidies up" by persisting `label`, this catches it.
      for (final t in TaskAssignmentType.values) {
        expect(t.value, t.name);
        expect(t.value, isNot(t.label));
      }
    });

    test('fromString round-trips every stored value', () {
      for (final t in TaskAssignmentType.values) {
        expect(TaskAssignmentType.fromString(t.value), t);
      }
    });

    test('a task written under the old wording still parses', () {
      // "Team" was only ever a label — the document said 'team' then and now.
      expect(TaskAssignmentType.fromString('team'), TaskAssignmentType.team);
      expect(
        TaskAssignmentType.fromString('individual'),
        TaskAssignmentType.individual,
      );
    });

    group('forAssigneeCount — the mode is derived from the pick', () {
      test('one person owns it, two or more share it', () {
        expect(
          TaskAssignmentType.forAssigneeCount(1),
          TaskAssignmentType.individual,
        );
        expect(TaskAssignmentType.forAssigneeCount(2), TaskAssignmentType.team);
        expect(TaskAssignmentType.forAssigneeCount(7), TaskAssignmentType.team);
      });

      test('an empty pick is not a Group', () {
        // Nobody selected yet reads as "no owner chosen", not "shared work" —
        // and the form blocks Create there anyway.
        expect(
          TaskAssignmentType.forAssigneeCount(0),
          TaskAssignmentType.individual,
        );
      });

      test('never derives shift — the roster is only ever chosen', () {
        for (var n = 0; n < 10; n++) {
          expect(
            TaskAssignmentType.forAssigneeCount(n),
            isNot(TaskAssignmentType.shift),
          );
        }
      });
    });

    test('missing / unknown → individual (pre-field tasks keep working)', () {
      expect(TaskAssignmentType.fromString(null), TaskAssignmentType.individual);
      expect(
        TaskAssignmentType.fromString('group'), // the new *label*, not a value
        TaskAssignmentType.individual,
      );
      expect(
        TaskAssignmentType.fromString('whatever'),
        TaskAssignmentType.individual,
      );
    });
  });
}
