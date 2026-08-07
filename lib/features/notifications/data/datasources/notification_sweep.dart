/// The **pure paging driver** behind the notification bulk actions
/// (`markAllRead` · `deleteArchived`).
///
/// Extracted from the datasource for one reason: the pagination is the part
/// that can be wrong, and inline it could only be checked by hand against a
/// real inbox. Cursor advancement, page-boundary arithmetic, termination and
/// the safety ceiling are all decisions this file makes and
/// `test/notification_sweep_test.dart` verifies — over thousands of items, and
/// including the case where committing *removes* the documents being paged.
/// What is left in the datasource is only the Firestore call itself.
///
/// The driver is deliberately generic over the page item: it never looks inside
/// one except through [selects], so the same logic serves an update sweep and a
/// delete sweep without either knowing about the other.
library;

/// Fetches the page that begins strictly after [cursor] (`null` for the first
/// page). Must return at most the page size; a short page means the end.
typedef SweepPageFetcher<T> = Future<List<T>> Function(T? cursor);

/// Applies the sweep's effect to one page's worth of selected items. Called
/// once per page, and never with an empty list.
typedef SweepCommit<T> = Future<void> Function(List<T> hits);

/// Thrown when a sweep runs past [SweepPolicy.maxPages] without reaching the
/// end of the collection.
///
/// It is an exception rather than a quiet return **on purpose**: the actions
/// behind this driver tell the user "all" — "mark **all** read", "delete **all**
/// archived" — and a silent partial is precisely the defect `clearArchived` was
/// fixed for. Better to say it could not finish than to imply it did.
class SweepLimitExceeded implements Exception {
  const SweepLimitExceeded(this.pagesRead, this.itemsScanned);

  final int pagesRead;
  final int itemsScanned;

  @override
  String toString() =>
      'SweepLimitExceeded(pagesRead: $pagesRead, itemsScanned: $itemsScanned)';
}

/// How far a sweep may go before it gives up.
class SweepPolicy {
  const SweepPolicy({required this.pageSize, required this.maxPages})
      : assert(pageSize > 0),
        assert(maxPages > 0);

  /// Documents read per page — and therefore the **maximum operations in one
  /// write batch**, which is why it must stay well under Firestore's hard cap
  /// of 500. See [NotificationRemoteDataSourceImpl] for the chosen value.
  final int pageSize;

  /// The ceiling, in pages. `pageSize * maxPages` is the largest collection a
  /// single sweep will process.
  final int maxPages;

  /// The largest number of items this policy will scan.
  int get maxItems => pageSize * maxPages;
}

/// What a completed sweep did — returned for logging and asserted in tests.
class SweepReport {
  const SweepReport({
    required this.pagesRead,
    required this.itemsScanned,
    required this.itemsCommitted,
    required this.batches,
  });

  final int pagesRead;
  final int itemsScanned;

  /// How many items [SweepCommit] was handed in total.
  final int itemsCommitted;

  /// How many times [SweepCommit] was called. Lower than [pagesRead] whenever a
  /// page contained nothing to act on.
  final int batches;

  @override
  String toString() => 'SweepReport(pages: $pagesRead, scanned: $itemsScanned, '
      'committed: $itemsCommitted, batches: $batches)';
}

/// Walks every page of a collection, committing the items [selects] accepts one
/// page at a time.
///
/// Termination, in the order it is decided:
///  - an **empty page** ends the sweep (nothing more exists);
///  - a **short page** — fewer items than [SweepPolicy.pageSize] — is the last
///    page: it is committed, then the sweep ends without a further round trip;
///  - a **full page** continues, using its last item as the next cursor;
///  - a page arriving when [SweepPolicy.maxPages] have already been processed
///    throws [SweepLimitExceeded]. The check is deliberately *after* the fetch:
///    a collection that ends exactly on the boundary has no page left to
///    arrive, so it completes normally instead of reporting a limit it did not
///    actually exceed.
///
/// The cursor is the last item of the page **as fetched**, not the last item
/// committed — so a page where nothing (or only the first item) was selected
/// still advances, and a sweep whose commit *deletes* what it touched still
/// moves forward rather than re-reading the same window. That mirrors Firestore
/// `startAfterDocument`, which resolves a position from the snapshot's order-by
/// values and therefore keeps working for a document that has since been
/// deleted.
Future<SweepReport> sweepPages<T>({
  required SweepPageFetcher<T> fetchPage,
  required bool Function(T item) selects,
  required SweepCommit<T> commit,
  required SweepPolicy policy,
}) async {
  T? cursor;
  var pagesRead = 0;
  var itemsScanned = 0;
  var itemsCommitted = 0;
  var batches = 0;

  while (true) {
    final page = await fetchPage(cursor);
    if (page.isEmpty) break;

    // The ceiling is checked AFTER the fetch, so it trips only when work
    // genuinely remains. Checking it before would fail a collection that ends
    // exactly on the boundary — every page full, nothing left — and report
    // "too many notifications" for a sweep that had in fact just finished all
    // of them. The cost is one extra empty read at the boundary, which is the
    // same read any loop needs to learn a full page was the last one.
    if (pagesRead >= policy.maxPages) {
      throw SweepLimitExceeded(pagesRead, itemsScanned);
    }

    pagesRead++;
    itemsScanned += page.length;
    cursor = page.last;

    final hits = [
      for (final item in page)
        if (selects(item)) item,
    ];
    if (hits.isNotEmpty) {
      await commit(hits);
      itemsCommitted += hits.length;
      batches++;
    }

    // A short page is the last page — ending here saves the round trip that
    // would only come back empty.
    if (page.length < policy.pageSize) break;
  }

  return SweepReport(
    pagesRead: pagesRead,
    itemsScanned: itemsScanned,
    itemsCommitted: itemsCommitted,
    batches: batches,
  );
}
