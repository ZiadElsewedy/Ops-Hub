import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/services/case_seen_store.dart';

void main() {
  // The store gracefully falls back to in-memory when path_provider is
  // unavailable (as in tests) — so these exercise the real store logic.
  TestWidgetsFlutterBinding.ensureInitialized();

  final t1 = DateTime(2026, 7, 4, 10);
  final t2 = DateTime(2026, 7, 4, 11);

  group('caseIsUnread', () {
    test('a case with no activity is never unread', () {
      expect(caseIsUnread(null, null), isFalse);
      expect(caseIsUnread(null, 123), isFalse);
    });

    test('never-opened case with activity is unread', () {
      expect(caseIsUnread(t1, null), isTrue);
    });

    test('activity newer than last-seen is unread', () {
      expect(caseIsUnread(t2, t1.millisecondsSinceEpoch), isTrue);
    });

    test('activity at or before last-seen is read', () {
      expect(caseIsUnread(t1, t1.millisecondsSinceEpoch), isFalse);
      expect(caseIsUnread(t1, t2.millisecondsSinceEpoch), isFalse);
    });
  });

  group('CaseSeenStore', () {
    test('a fresh case is unread until it is opened', () async {
      final store = CaseSeenStore();
      await store.load('u1');
      expect(store.isUnread('c1', t1), isTrue);
      expect(store.markSeen('c1', t1), isTrue); // advanced
      expect(store.isUnread('c1', t1), isFalse);
    });

    test('a newer reply re-flags a previously-seen case', () async {
      final store = CaseSeenStore();
      await store.load('u1');
      store.markSeen('c1', t1);
      expect(store.isUnread('c1', t2), isTrue);
    });

    test('marking with an older/equal time does not advance', () async {
      final store = CaseSeenStore();
      await store.load('u1');
      store.markSeen('c1', t2);
      expect(store.markSeen('c1', t1), isFalse);
      expect(store.isUnread('c1', t2), isFalse);
    });

    test('seen-state is namespaced per user (shared device)', () async {
      final store = CaseSeenStore();
      await store.load('u1');
      store.markSeen('c1', t1);
      expect(store.isUnread('c1', t1), isFalse);
      await store.load('u2'); // account switch on the same store
      expect(store.isUnread('c1', t1), isTrue);
    });
  });
}
