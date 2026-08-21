import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';

/// Sentinel id for a **client-synthesized** submitted event. Never written to
/// Firestore — it only exists so the timeline is self-contained on screen.
const String kSyntheticSubmittedId = '__submitted__';

/// The events to render for a request, guaranteeing the timeline **always leads
/// with the original submission**.
///
/// The canonical `submitted` event is written server-side by `onRequestCreated`.
/// Until that function is deployed (or in the brief window before it runs), the
/// stream carries only later events — so a freshly filed request would show an
/// empty timeline even though it has details and attachments. This prepends a
/// synthesized [RequestEventKind.submitted] built from the request doc, and
/// **suppresses it the moment the real server event is present** (so it never
/// double-renders once functions are live).
///
/// Pure + deterministic — safe to unit-test.
List<RequestEvent> requestThread(
  List<RequestEvent> events,
  RequestEntity request,
) {
  if (events.any((e) => e.isSubmitted)) return events;

  final opening = RequestEvent(
    id: kSyntheticSubmittedId,
    authorId: request.requesterId,
    authorName: request.requesterName,
    actor: RequestEventActor.requester,
    kind: RequestEventKind.submitted,
    text: request.summary,
    attachments: request.attachments,
    createdAt: request.createdAt ??
        (events.isNotEmpty ? events.first.createdAt : DateTime.now()),
  );
  return [opening, ...events];
}
