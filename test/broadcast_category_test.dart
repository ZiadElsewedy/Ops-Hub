import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_category.dart';

/// The Communications Center category enum (Phase 3) — used by the Compose
/// screen's category selector and the feed/detail styling.
void main() {
  group('BroadcastCategory', () {
    test('value + label', () {
      expect(BroadcastCategory.announcement.value, 'announcement');
      expect(BroadcastCategory.emergency.label, 'Emergency');
    });

    test('fromString maps the three categories', () {
      expect(BroadcastCategory.fromString('announcement'),
          BroadcastCategory.announcement);
      expect(
          BroadcastCategory.fromString('reminder'), BroadcastCategory.reminder);
      expect(BroadcastCategory.fromString('emergency'),
          BroadcastCategory.emergency);
    });

    test('unknown / legacy "general" / retired "alert" / null → announcement', () {
      expect(
          BroadcastCategory.fromString('general'), BroadcastCategory.announcement);
      expect(BroadcastCategory.fromString('alert'),
          BroadcastCategory.announcement);
      expect(BroadcastCategory.fromString(null), BroadcastCategory.announcement);
      expect(BroadcastCategory.fromString('whatever'),
          BroadcastCategory.announcement);
    });

    test('only emergency is urgent (carries a status colour)', () {
      expect(BroadcastCategory.emergency.isUrgent, isTrue);
      expect(BroadcastCategory.announcement.isUrgent, isFalse);
      expect(BroadcastCategory.reminder.isUrgent, isFalse);
    });
  });
}
