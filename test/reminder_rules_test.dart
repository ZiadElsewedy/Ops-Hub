import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/task/domain/reminder_rules.dart';

/// Phase 2 Commit 5 — the pure task-reminder decision logic (mirrored by the
/// `runTaskReminders` Cloud Function).
void main() {
  // A neutral "now" well outside quiet hours (12:00).
  final now = DateTime(2026, 6, 22, 12);

  group('ReminderRules.dueKind — which kind fires', () {
    test('due24h when 24h..1h out; due1h when ≤1h; overdue when past', () {
      expect(
          ReminderRules.dueKind(
              deadline: now.add(const Duration(hours: 20)), now: now),
          'due24h');
      expect(
          ReminderRules.dueKind(
              deadline: now.add(const Duration(minutes: 40)), now: now),
          'due1h');
      expect(
          ReminderRules.dueKind(
              deadline: now.subtract(const Duration(hours: 2)), now: now),
          'overdue');
    });

    test('nothing when more than 24h out', () {
      expect(
          ReminderRules.dueKind(
              deadline: now.add(const Duration(days: 3)), now: now),
          isNull);
    });

    test('a shift-bounded window (≤24h) suppresses the eager 24h rung', () {
      final shiftEnd = now.add(const Duration(hours: 6)); // still today
      // Without a window → the old eager due24h.
      expect(
          ReminderRules.dueKind(deadline: shiftEnd, now: now), 'due24h');
      // Knowing the ~8h shift window → the 24h rung is withheld.
      expect(
          ReminderRules.dueKind(
              deadline: shiftEnd,
              now: now,
              scheduledWindow: const Duration(hours: 8)),
          isNull);
      // The 1h rung still fires near the deadline.
      expect(
          ReminderRules.dueKind(
              deadline: now.add(const Duration(minutes: 40)),
              now: now,
              scheduledWindow: const Duration(hours: 8)),
          'due1h');
    });

    test('a multi-day window (>24h) keeps the 24h rung', () {
      expect(
          ReminderRules.dueKind(
              deadline: now.add(const Duration(hours: 20)),
              now: now,
              scheduledWindow: const Duration(days: 3)),
          'due24h');
    });
  });

  group('ReminderRules.dueKind — anti-spam', () {
    test('only escalates forward (no resend / no going back)', () {
      // Already sent due24h: at ≤1h send due1h, but never re-send due24h.
      expect(
        ReminderRules.dueKind(
            deadline: now.add(const Duration(minutes: 30)),
            now: now,
            lastKind: 'due24h'),
        'due1h',
      );
      expect(
        ReminderRules.dueKind(
            deadline: now.add(const Duration(hours: 20)),
            now: now,
            lastKind: 'due24h'),
        isNull, // would be due24h again — suppressed
      );
      // After overdue sent, nothing escalates further.
      expect(
        ReminderRules.dueKind(
            deadline: now.subtract(const Duration(hours: 1)),
            now: now,
            lastKind: 'overdue'),
        isNull,
      );
    });

    test('maxReminders cap and disabled flag suppress everything', () {
      expect(
        ReminderRules.dueKind(
            deadline: now.subtract(const Duration(hours: 1)),
            now: now,
            reminderCount: 3,
            maxReminders: 3),
        isNull,
      );
      expect(
        ReminderRules.dueKind(
            deadline: now.subtract(const Duration(hours: 1)),
            now: now,
            enabled: false),
        isNull,
      );
    });

    test('quiet hours suppress reminders', () {
      final quietNow = DateTime(2026, 6, 22, 23); // 23:00, inside 22→7
      expect(
        ReminderRules.dueKind(
            deadline: quietNow.subtract(const Duration(hours: 1)),
            now: quietNow),
        isNull,
      );
    });
  });

  group('ReminderRules helpers', () {
    test('inQuietHours wraps midnight; zero-length window never quiet', () {
      expect(ReminderRules.inQuietHours(23, 22, 7), isTrue);
      expect(ReminderRules.inQuietHours(3, 22, 7), isTrue);
      expect(ReminderRules.inQuietHours(12, 22, 7), isFalse);
      expect(ReminderRules.inQuietHours(7, 22, 7), isFalse); // exact end
      expect(ReminderRules.inQuietHours(5, 9, 9), isFalse); // zero-length
    });

    test('typeFor maps overdue → taskOverdue, else taskReminder', () {
      expect(ReminderRules.typeFor('overdue'), 'taskOverdue');
      expect(ReminderRules.typeFor('due1h'), 'taskReminder');
      expect(ReminderRules.typeFor('due24h'), 'taskReminder');
    });
  });
}
