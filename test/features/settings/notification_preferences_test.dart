import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/services/notification_preferences_store.dart';

/// The pure half of the notification switches — no file I/O, no widgets.
void main() {
  group('NotificationPreferences', () {
    test('defaults every switch on', () {
      const prefs = NotificationPreferences();
      expect(prefs.enabled, isTrue);
      expect(prefs.taskReminders, isTrue);
      expect(prefs.scheduleUpdates, isTrue);
      expect(prefs.caseMessages, isTrue);
      expect(prefs.announcements, isTrue);
      expect(prefs.sound, isTrue);
    });

    test('the master switch gates every category', () {
      const on = NotificationPreferences();
      expect(on.isCategoryActive(on.taskReminders), isTrue);

      final off = on.copyWith(enabled: false);
      expect(off.isCategoryActive(off.taskReminders), isFalse);
      // …but the category's own choice is kept, not reset.
      expect(off.taskReminders, isTrue);
    });

    test('a category stays off on its own merit when the master is on', () {
      const prefs = NotificationPreferences(announcements: false);
      expect(prefs.isCategoryActive(prefs.announcements), isFalse);
      expect(prefs.isCategoryActive(prefs.caseMessages), isTrue);
    });

    test('round-trips through the persisted map', () {
      const prefs = NotificationPreferences(
        enabled: true,
        taskReminders: false,
        scheduleUpdates: true,
        caseMessages: false,
        announcements: true,
        sound: false,
      );
      expect(NotificationPreferences.fromMap(prefs.toMap()), prefs);
    });

    test('a missing or malformed key falls back to that field default', () {
      final prefs = NotificationPreferences.fromMap({
        'enabled': false,
        'taskReminders': 'yes', // wrong type — not a bool
        // scheduleUpdates absent entirely
      });
      expect(prefs.enabled, isFalse);
      expect(prefs.taskReminders, isTrue);
      expect(prefs.scheduleUpdates, isTrue);
    });
  });

  group('NotificationPreferencesStore', () {
    test('degrades to in-memory when the file is unavailable', () async {
      // There is no path_provider platform channel in a plain unit test, so
      // `load` takes the catch path — which must still resolve and still serve
      // the defaults rather than throwing into the screen.
      final store = NotificationPreferencesStore();
      expect(store.isLoaded, isFalse);
      expect(store.loadedFor('u1'), isNull);

      final prefs = await store.load('u1');
      expect(prefs, const NotificationPreferences());
      expect(store.isLoaded, isTrue);

      store.save(const NotificationPreferences(sound: false));
      expect(store.preferences.sound, isFalse);
      expect(store.loadedFor('u1')?.sound, isFalse);
    });

    test('namespaces preferences by uid', () async {
      final store = NotificationPreferencesStore();
      await store.load('u1');
      store.save(const NotificationPreferences(enabled: false));

      await store.load('u2');
      expect(store.preferences, const NotificationPreferences());

      await store.load('u1');
      expect(store.preferences.enabled, isFalse);
    });

    test('ignores a save before any uid is known', () {
      final store = NotificationPreferencesStore();
      store.save(const NotificationPreferences(enabled: false));
      expect(store.preferences, const NotificationPreferences());
    });
  });
}
