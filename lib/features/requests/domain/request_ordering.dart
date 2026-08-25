import 'package:opshub/features/requests/domain/entities/request_entity.dart';

/// Inbox ordering for the requests list — an approval inbox, not a task board.
/// Pure Dart, deterministic given the same inputs.
///
/// Rules:
///   1. Pending requests (awaiting a decision) come first; decided ones archive.
///   2. Within each section, latest activity first.

int _cmpDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // nulls last
  if (b == null) return -1;
  return b.compareTo(a); // newest first
}

int _cmpActive(RequestEntity a, RequestEntity b) =>
    _cmpDateDesc(a.lastActivityAt, b.lastActivityAt);

int _cmpArchived(RequestEntity a, RequestEntity b) => _cmpDateDesc(
      a.decidedAt ?? a.lastActivityAt,
      b.decidedAt ?? b.lastActivityAt,
    );

/// Splits requests into the two inbox sections, each already sorted.
({List<RequestEntity> active, List<RequestEntity> archived}) partitionRequests(
  List<RequestEntity> requests,
) {
  final active = <RequestEntity>[];
  final archived = <RequestEntity>[];
  for (final r in requests) {
    (r.isActive ? active : archived).add(r);
  }
  active.sort(_cmpActive);
  archived.sort(_cmpArchived);
  return (active: active, archived: archived);
}

/// The full inbox order (pending section then archive), for a single flat list.
List<RequestEntity> sortRequestsForInbox(List<RequestEntity> requests) {
  final parts = partitionRequests(requests);
  return [...parts.active, ...parts.archived];
}
