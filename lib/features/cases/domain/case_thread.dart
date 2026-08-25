import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';

/// Sentinel id for a **client-synthesized** opening message. Never written to
/// Firestore — it only exists so the conversation is self-contained on screen.
const String kSyntheticOpeningId = '__opening__';

/// The messages to render for a case, guaranteeing the thread **always leads
/// with the original report**.
///
/// The canonical opening message is written server-side by `onCaseCreated`. Until
/// that function is deployed (or in the brief window before it runs), the stream
/// carries only replies — so a freshly opened case would show an empty thread
/// even though it has a subject, description and attachments. This prepends a
/// synthesized [CaseMessageKind.opening] built from the case doc itself, and
/// **suppresses it the moment the real server opening is present** (so it never
/// double-renders once functions are live).
///
/// Pure + deterministic: no infrastructure, safe to unit-test.
List<CaseMessage> caseThread(List<CaseMessage> messages, CaseEntity caseItem) {
  final hasOpening = messages.any((m) => m.isOpening);
  if (hasOpening) return messages;

  final hasContent =
      (caseItem.description?.trim().isNotEmpty ?? false) || caseItem.hasAttachments;
  if (!hasContent) return messages;

  final opening = CaseMessage(
    id: kSyntheticOpeningId,
    // De-identified by construction — alignment is driven by [authorRole], not a
    // uid, so a confidential reporter's opening never leaks who filed it.
    authorName: caseItem.senderLabel,
    authorRole: CaseAuthorRole.reporter,
    kind: CaseMessageKind.opening,
    text: caseItem.description?.trim(),
    attachments: caseItem.attachments,
    createdAt: caseItem.createdAt ??
        (messages.isNotEmpty ? messages.first.createdAt : DateTime.now()),
  );
  return [opening, ...messages];
}
