import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/features/cases/domain/case_ordering.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';

void main() {
  CaseEntity c(
    String id, {
    CaseStatus status = CaseStatus.open,
    bool urgent = false,
    DateTime? lastMessageAt,
    DateTime? closedAt,
  }) =>
      CaseEntity(
        id: id,
        subject: id,
        status: status,
        urgent: urgent,
        lastMessageAt: lastMessageAt,
        closedAt: closedAt,
      );

  final t0 = DateTime(2026, 7, 4, 9);
  final t1 = DateTime(2026, 7, 4, 10);
  final t2 = DateTime(2026, 7, 4, 11);
  final t3 = DateTime(2026, 7, 4, 12);

  group('partitionCases', () {
    test('splits active vs closed', () {
      final parts = partitionCases([
        c('a', status: CaseStatus.open),
        c('b', status: CaseStatus.closed, closedAt: t1),
        c('c', status: CaseStatus.waitingResponse),
      ]);
      expect(parts.active.map((e) => e.id), containsAll(['a', 'c']));
      expect(parts.archived.map((e) => e.id), ['b']);
    });

    test('active: urgent floats above normal', () {
      final parts = partitionCases([
        c('normal', lastMessageAt: t3), // newest but not urgent
        c('urgent', urgent: true, lastMessageAt: t0),
      ]);
      expect(parts.active.first.id, 'urgent');
    });

    test('active: within the same urgency, newest activity first', () {
      final parts = partitionCases([
        c('older', lastMessageAt: t1),
        c('newer', lastMessageAt: t2),
      ]);
      expect(parts.active.map((e) => e.id), ['newer', 'older']);
    });

    test('archived: most-recently closed first', () {
      final parts = partitionCases([
        c('closedEarly', status: CaseStatus.closed, closedAt: t1),
        c('closedLate', status: CaseStatus.closed, closedAt: t3),
      ]);
      expect(parts.archived.map((e) => e.id), ['closedLate', 'closedEarly']);
    });
  });

  group('sortCasesForInbox', () {
    test('active section precedes the archive, urgent-active first', () {
      final list = sortCasesForInbox([
        c('closed', status: CaseStatus.closed, closedAt: t3),
        c('activeNormal', lastMessageAt: t2),
        c('activeUrgent', urgent: true, lastMessageAt: t0),
      ]);
      expect(list.map((e) => e.id), ['activeUrgent', 'activeNormal', 'closed']);
    });
  });
}
