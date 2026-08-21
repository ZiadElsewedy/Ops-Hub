import 'package:opshub/features/notifications/data/datasources/notification_sweep.dart';
import 'package:flutter_test/flutter_test.dart';

/// The paging behind **Mark all read** and **Clear archived**.
///
/// Both actions replaced implementations that were correct only for a small
/// inbox and failed **silently** past it — `markAllRead` blew Firestore's
/// 500-operation batch cap, `clearArchived` only touched the loaded page. The
/// paging that replaced them was previously listed as "needs on-device QA"; it
/// is now verified here over thousands of items, including the case where
/// committing *deletes* the documents being paged.
///
/// [_FakeCollection] models Firestore's contract faithfully in the two ways
/// that matter: a page is a window into a stable sort order, and a cursor is a
/// **position**, resolved from the item's sort key — so it keeps working for an
/// item that has since been deleted (exactly what `startAfterDocument` does).
void main() {
  /// Runs a sweep over [collection] selecting items whose id is in [selected].
  Future<({SweepReport report, List<List<String>> batches})> sweep(
    _FakeCollection collection, {
    required bool Function(_Doc doc) selects,
    int pageSize = 10,
    int maxPages = 50,
    bool deleteOnCommit = false,
  }) async {
    collection.pageSize = pageSize;
    final batches = <List<String>>[];
    final report = await sweepPages<_Doc>(
      policy: SweepPolicy(pageSize: pageSize, maxPages: maxPages),
      fetchPage: collection.page,
      selects: selects,
      commit: (hits) async {
        batches.add([for (final d in hits) d.id]);
        if (deleteOnCommit) collection.delete(hits);
      },
    );
    return (report: report, batches: batches);
  }

  bool all(_Doc _) => true;

  group('termination', () {
    test('an empty collection reads one page and stops', () async {
      final c = _FakeCollection.of(0);
      final r = await sweep(c, selects: all);
      expect(r.report.pagesRead, 0);
      expect(r.report.itemsScanned, 0);
      expect(r.batches, isEmpty);
      expect(c.pageFetches, 1);
    });

    test('a short first page is the last page — no extra round trip', () async {
      final c = _FakeCollection.of(4);
      final r = await sweep(c, selects: all, pageSize: 10);
      expect(r.report.pagesRead, 1);
      expect(r.report.itemsScanned, 4);
      // The saving that matters: it did NOT fetch a second, empty page.
      expect(c.pageFetches, 1);
    });

    test('an EXACTLY full page needs a second fetch to learn it is done',
        () async {
      // The off-by-one that a naive implementation gets wrong: 10 items with a
      // page size of 10 is indistinguishable from "more to come" until asked.
      final c = _FakeCollection.of(10);
      final r = await sweep(c, selects: all, pageSize: 10);
      expect(r.report.pagesRead, 1);
      expect(r.report.itemsScanned, 10);
      expect(c.pageFetches, 2);
      expect(r.batches, hasLength(1));
    });

    test('an exact multiple of the page size sweeps every item once', () async {
      final c = _FakeCollection.of(30);
      final r = await sweep(c, selects: all, pageSize: 10);
      expect(r.report.pagesRead, 3);
      expect(r.report.itemsScanned, 30);
      expect(c.pageFetches, 4); // three full pages, then an empty one
      expect(r.batches.expand((b) => b), hasLength(30));
    });
  });

  group('multi-page cursor advancement', () {
    test('every item is visited exactly once, in order', () async {
      final c = _FakeCollection.of(95);
      final r = await sweep(c, selects: all, pageSize: 10);

      final visited = r.batches.expand((b) => b).toList();
      expect(visited, c.allIds);
      expect(visited.toSet(), hasLength(95), reason: 'no repeats');
      expect(r.report.pagesRead, 10); // 9 full + 1 short
      expect(r.report.itemsScanned, 95);
    });

    test('a page where NOTHING is selected still advances the cursor',
        () async {
      // The bug this guards: cursoring off the last *committed* item instead of
      // the last *fetched* one would re-read the same window forever.
      final c = _FakeCollection.of(50);
      // Only the very last item qualifies, so pages 1–4 select nothing.
      final r = await sweep(c, selects: (d) => d.index == 49, pageSize: 10);

      expect(r.report.pagesRead, 5);
      expect(r.report.itemsScanned, 50);
      expect(r.batches, [
        ['n49'],
      ]);
      expect(r.report.batches, 1, reason: 'empty pages must not commit');
    });

    test('a page where only the FIRST item is selected still advances',
        () async {
      final c = _FakeCollection.of(30);
      final r = await sweep(c, selects: (d) => d.index % 10 == 0, pageSize: 10);
      expect(r.batches, [
        ['n0'],
        ['n10'],
        ['n20'],
      ]);
    });

    test('selection spanning a page boundary is not split or lost', () async {
      final c = _FakeCollection.of(30);
      final r = await sweep(c, selects: (d) => d.index >= 8 && d.index <= 12,
          pageSize: 10);
      expect(r.batches, [
        ['n8', 'n9'],
        ['n10', 'n11', 'n12'],
      ]);
      expect(r.report.itemsCommitted, 5);
    });
  });

  group('a delete sweep (Clear archived)', () {
    test('committing removals does not skip the next page', () async {
      // The real risk in `deleteArchived`: the cursor names a document the
      // commit just deleted. Firestore resolves the cursor from the snapshot's
      // sort values, so it still points at the right position — and the sweep
      // must not compensate for a shift that does not happen.
      final c = _FakeCollection.of(50);
      final r = await sweep(c, selects: all, pageSize: 10,
          deleteOnCommit: true);

      expect(r.report.itemsScanned, 50);
      expect(r.batches.expand((b) => b).toList(), c.allIds);
      expect(c.remaining, isEmpty);
    });

    test('deleting only SOME items per page still walks the whole set',
        () async {
      final c = _FakeCollection.of(60);
      final r = await sweep(c, selects: (d) => d.index.isEven, pageSize: 10,
          deleteOnCommit: true);

      expect(r.report.itemsScanned, 60);
      expect(r.report.itemsCommitted, 30);
      // Exactly the odd ones survive — nothing skipped, nothing deleted twice.
      expect(c.remaining, [for (var i = 1; i < 60; i += 2) 'n$i']);
    });
  });

  group('batch sizing — the Firestore 500-operation cap', () {
    test('no batch ever exceeds the page size', () async {
      // This is the invariant that keeps `markAllRead` under the hard cap: the
      // page size IS the batch ceiling. The old code batched the entire
      // collection at once and died past 500.
      final c = _FakeCollection.of(2500);
      final r = await sweep(c, selects: all, pageSize: 300);

      for (final batch in r.batches) {
        expect(batch.length, lessThanOrEqualTo(300));
      }
      expect(r.report.itemsCommitted, 2500);
      expect(r.report.batches, 9); // 8 full + 1 of 100
    });

    test('the shipped policy stays clear of the cap', () async {
      const shipped = SweepPolicy(pageSize: 300, maxPages: 50);
      expect(shipped.pageSize, lessThan(500));
      expect(shipped.maxItems, 15000);
    });
  });

  group('large sets', () {
    test('sweeps 5,000 items with no repeats and no gaps', () async {
      final c = _FakeCollection.of(5000);
      final r = await sweep(c, selects: all, pageSize: 300);

      final visited = r.batches.expand((b) => b).toList();
      expect(visited, hasLength(5000));
      expect(visited.toSet(), hasLength(5000));
      expect(visited, c.allIds);
      expect(r.report.pagesRead, 17); // 16 full + 1 of 200
    });

    test('sweeps the full 15,000-item ceiling without tripping it', () async {
      // Exactly at the limit must SUCCEED — the ceiling is exclusive of the
      // work it can do, not one page short of it.
      final c = _FakeCollection.of(15000);
      final r = await sweep(c, selects: all, pageSize: 300, maxPages: 50);
      expect(r.report.pagesRead, 50);
      expect(r.report.itemsScanned, 15000);
      expect(r.report.itemsCommitted, 15000);
    });

    test('a sparse selection over a large set commits only what matched',
        () async {
      final c = _FakeCollection.of(5000);
      final r = await sweep(c, selects: (d) => d.index % 500 == 0,
          pageSize: 300);
      expect(r.report.itemsScanned, 5000);
      expect(r.report.itemsCommitted, 10);
    });
  });

  group('the safety ceiling', () {
    test('throws rather than returning a silent partial', () async {
      // "Mark all read" and "Delete all archived" promise *all*. Stopping
      // quietly is the exact defect `clearArchived` was fixed for, so the
      // driver refuses to imply success it did not achieve.
      final c = _FakeCollection.of(1000);
      await expectLater(
        sweep(c, selects: all, pageSize: 10, maxPages: 5),
        throwsA(isA<SweepLimitExceeded>()),
      );
    });

    test('the thrown error reports how far it got', () async {
      final c = _FakeCollection.of(1000);
      try {
        await sweep(c, selects: all, pageSize: 10, maxPages: 5);
        fail('expected SweepLimitExceeded');
      } on SweepLimitExceeded catch (e) {
        expect(e.pagesRead, 5);
        expect(e.itemsScanned, 50);
        expect(e.toString(), contains('pagesRead: 5'));
      }
    });

    test('work done before the ceiling is NOT rolled back', () async {
      // Each page commits as it goes, so a sweep that gives up has still made
      // progress. Re-running it continues from a smaller set rather than
      // starting over — which is why the user-facing message says "try again".
      final c = _FakeCollection.of(1000);
      final batches = <List<String>>[];
      await expectLater(
        sweepPages<_Doc>(
          policy: const SweepPolicy(pageSize: 10, maxPages: 5),
          fetchPage: c.page,
          selects: all,
          commit: (hits) async {
            batches.add([for (final d in hits) d.id]);
            c.delete(hits);
          },
        ),
        throwsA(isA<SweepLimitExceeded>()),
      );
      expect(batches, hasLength(5));
      expect(c.remaining, hasLength(950));
    });

    test('a collection that exactly fills the ceiling does not throw',
        () async {
      final c = _FakeCollection.of(50);
      final r = await sweep(c, selects: all, pageSize: 10, maxPages: 5);
      expect(r.report.pagesRead, 5);
    });

    test('one item past the ceiling does throw', () async {
      final c = _FakeCollection.of(51);
      await expectLater(
        sweep(c, selects: all, pageSize: 10, maxPages: 5),
        throwsA(isA<SweepLimitExceeded>()),
      );
    });
  });

  group('policy invariants', () {
    test('rejects a nonsensical policy at construction', () {
      expect(() => SweepPolicy(pageSize: 0, maxPages: 1), throwsA(anything));
      expect(() => SweepPolicy(pageSize: 1, maxPages: 0), throwsA(anything));
    });
  });

  group('failure propagation', () {
    test('a fetch failure aborts the sweep and surfaces', () async {
      final c = _FakeCollection.of(50)..failOnFetch = 3;
      await expectLater(
        sweep(c, selects: all, pageSize: 10),
        throwsA(isA<StateError>()),
      );
    });

    test('a commit failure aborts the sweep and surfaces', () async {
      // A partially-applied sweep must not be reported as success — the
      // datasource maps this onto a `ServerException` the cubit shows.
      final c = _FakeCollection.of(50);
      await expectLater(
        sweepPages<_Doc>(
          policy: const SweepPolicy(pageSize: 10, maxPages: 50),
          fetchPage: c.page,
          selects: all,
          commit: (hits) async => throw StateError('batch rejected'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

// ─── A Firestore-shaped fake ────────────────────────────────────────────

class _Doc {
  const _Doc(this.index);
  final int index;
  String get id => 'n$index';
}

/// An ordered collection paged the way Firestore pages one.
///
/// The two behaviours it deliberately reproduces:
///  - **a cursor is a position, not an index** — `page(cursor)` returns items
///    whose sort key is strictly after the cursor's, so it stays correct when
///    the cursor document has been deleted (Firestore's `startAfterDocument`
///    resolves the position from the snapshot's order-by values);
///  - **deletions do not shift the window** — a deleted item is simply absent
///    from later pages; it does not pull a later item backwards into a page
///    that has already been read.
class _FakeCollection {
  _FakeCollection.of(int count)
      : _docs = [for (var i = 0; i < count; i++) _Doc(i)] {
    allIds.addAll([for (final d in _docs) d.id]);
  }

  final List<_Doc> _docs;

  /// Mirrors the `limit()` the real query carries; set by the test to match the
  /// policy under test, so the fake never hands back more than Firestore would.
  int pageSize = 10;

  int pageFetches = 0;

  /// When set, the fetch of this 1-based page number throws.
  int? failOnFetch;

  /// Every id in sort order, including any since deleted — the expected visit
  /// order for a sweep that started before the deletions.
  final List<String> allIds = [];

  List<String> get remaining => [for (final d in _docs) d.id];

  void delete(List<_Doc> docs) {
    final gone = {for (final d in docs) d.index};
    _docs.removeWhere((d) => gone.contains(d.index));
  }

  Future<List<_Doc>> page(_Doc? cursor) async {
    pageFetches++;
    if (failOnFetch == pageFetches) throw StateError('read failed');
    // A cursor is a POSITION: everything whose sort key is strictly after it,
    // which stays well-defined even once the cursor's own document is gone.
    final after = cursor?.index;
    final window = <_Doc>[];
    for (final d in _docs) {
      if (after != null && d.index <= after) continue;
      window.add(d);
      if (window.length == pageSize) break;
    }
    return window;
  }
}
