import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/request_ordering.dart';

void main() {
  RequestEntity r(
    String id, {
    RequestStatus status = RequestStatus.pending,
    DateTime? lastEventAt,
    DateTime? decidedAt,
  }) =>
      RequestEntity(
        id: id,
        type: RequestType.other,
        requesterId: 'u1',
        status: status,
        lastEventAt: lastEventAt,
        decidedAt: decidedAt,
      );

  final t0 = DateTime(2026, 7, 7, 9);
  final t1 = DateTime(2026, 7, 7, 10);
  final t2 = DateTime(2026, 7, 7, 11);

  group('partitionRequests', () {
    test('splits pending (active) vs decided (archived)', () {
      final parts = partitionRequests([
        r('a', status: RequestStatus.pending),
        r('b', status: RequestStatus.approved, decidedAt: t1),
        r('c', status: RequestStatus.rejected, decidedAt: t0),
      ]);
      expect(parts.active.map((e) => e.id), ['a']);
      expect(parts.archived.map((e) => e.id), containsAll(['b', 'c']));
    });

    test('within the active section, newest activity first', () {
      final parts = partitionRequests([
        r('old', lastEventAt: t0),
        r('new', lastEventAt: t2),
        r('mid', lastEventAt: t1),
      ]);
      expect(parts.active.map((e) => e.id), ['new', 'mid', 'old']);
    });

    test('archive is newest-decided first', () {
      final parts = partitionRequests([
        r('older', status: RequestStatus.rejected, decidedAt: t0),
        r('newer', status: RequestStatus.approved, decidedAt: t2),
      ]);
      expect(parts.archived.map((e) => e.id), ['newer', 'older']);
    });
  });

  test('sortRequestsForInbox concatenates active then archive', () {
    final list = sortRequestsForInbox([
      r('done', status: RequestStatus.approved, decidedAt: t0),
      r('todo', status: RequestStatus.pending, lastEventAt: t1),
    ]);
    expect(list.first.id, 'todo');
    expect(list.last.id, 'done');
  });
}
