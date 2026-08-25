import 'package:opshub/features/cases/domain/entities/case_entity.dart';

/// Inbox ordering for the case list (the left split-pane) — a conversation
/// inbox in the Slack / Intercom sense, **not** a task board. Pure Dart, no
/// infrastructure: deterministic given the same inputs.
///
/// Rules (owner-specified):
///   1. Active cases (Open / In Discussion / Waiting Response) come first.
///   2. Among active cases, **urgent** float above normal.
///   3. Within each of those, order by **latest activity** descending.
///   4. Closed cases sink to a separate archive section (newest-closed first).

int _cmpDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // nulls last
  if (b == null) return -1;
  return b.compareTo(a); // newest first
}

/// Comparator for the ACTIVE section: urgent first, then latest activity desc.
int _cmpActive(CaseEntity a, CaseEntity b) {
  if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
  return _cmpDateDesc(a.lastActivityAt, b.lastActivityAt);
}

/// Comparator for the ARCHIVE section: most-recently closed first (falls back to
/// last activity when a `closedAt` is missing).
int _cmpArchived(CaseEntity a, CaseEntity b) =>
    _cmpDateDesc(a.closedAt ?? a.lastActivityAt, b.closedAt ?? b.lastActivityAt);

/// Splits cases into the two inbox sections, each already sorted.
({List<CaseEntity> active, List<CaseEntity> archived}) partitionCases(
  List<CaseEntity> cases,
) {
  final active = <CaseEntity>[];
  final archived = <CaseEntity>[];
  for (final c in cases) {
    (c.isActive ? active : archived).add(c);
  }
  active.sort(_cmpActive);
  archived.sort(_cmpArchived);
  return (active: active, archived: archived);
}

/// The full inbox order (active section then archive), for surfaces that render
/// a single flat list.
List<CaseEntity> sortCasesForInbox(List<CaseEntity> cases) {
  final parts = partitionCases(cases);
  return [...parts.active, ...parts.archived];
}
