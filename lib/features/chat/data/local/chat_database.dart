import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'chat_database.g.dart';

/// The chat offline cache — a Drift (SQLite) database persisting the chat
/// feature's conversations, messages (with their reply + attachment
/// **metadata**), and a small outbox of not-yet-acknowledged text sends.
///
/// This file is the **only** place the app touches SQLite, mirroring the
/// single-seam discipline the rest of DROP follows (`core/network` for HTTP,
/// `core/media` for Storage). Nothing outside `features/chat/data/local/` may
/// import `drift`.
///
/// **We never persist attachment or image BYTES.** Only the metadata a bubble
/// needs to render offline (kind/format/mime/filename/size) is stored; the
/// actual bytes are fetched on demand from a short-lived brokered URL, exactly
/// as the online path already does. This keeps the database small and honours
/// the cache contract (URLs + metadata, never blobs).

// ─── Tables ───────────────────────────────────────────────────────────────

/// One cached conversation — the durable twin of [ChatConversationSummary]
/// plus the per-thread bookkeeping (`myUserId`, the oldest-history `nextCursor`)
/// that lets a re-opened thread resume online pagination.
class ChatConversationRows extends Table {
  TextColumn get id => text()();

  /// JSON-encoded `List<String>` of both participants' internal ids.
  TextColumn get participantIds => text()();

  /// Server-computed counterpart (internal id) — present once the list endpoint
  /// has been read for this conversation.
  TextColumn get counterpartUserId => text().nullable()();

  /// Counterpart's Firebase uid (the directory key) — null until the backend
  /// has provisioned them.
  TextColumn get counterpartExternalId => text().nullable()();

  IntColumn get createdAtMs => integer()();
  IntColumn get lastMessageAtMs => integer().nullable()();

  /// The caller's own internal id in this thread, once derived — kept so a cold
  /// re-open renders own/counterpart alignment before the first network round.
  TextColumn get myUserId => text().nullable()();

  /// The server cursor for the next **older** history page, as last known.
  /// Lets an online scroll-back continue from where the cache ends.
  TextColumn get nextCursor => text().nullable()();

  /// Local wall-clock of the last merge into this row (ms). Cache-invalidation
  /// bookkeeping only; never shown.
  IntColumn get syncedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One cached message. Reply and attachment metadata are flattened into
/// nullable columns (a message has at most one of each) rather than child
/// tables — the shape is fixed and a join would only add cost.
@TableIndex(name: 'idx_message_conversation_seq', columns: {#conversationId, #seq})
class ChatMessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();

  /// Raw wire type string (`TEXT`/`IMAGE`/`DOCUMENT`) — kept verbatim so a
  /// newer server value round-trips instead of collapsing to a default.
  TextColumn get type => text()();
  TextColumn get body => text().nullable()();

  /// Conversation-scoped ordering sequence. 64-bit; stored as INTEGER (exact on
  /// every non-web target this app ships) and rebuilt to [BigInt] on read.
  IntColumn get seq => integer()();

  TextColumn get status => text()();
  IntColumn get createdAtMs => integer()();
  BoolColumn get deletedForEveryone =>
      boolean().withDefault(const Constant(false))();

  // ── Attachment metadata (never bytes) ──
  TextColumn get attachmentId => text().nullable()();
  TextColumn get attachmentKind => text().nullable()();
  TextColumn get attachmentFormat => text().nullable()();
  TextColumn get attachmentMimeType => text().nullable()();
  TextColumn get attachmentFilename => text().nullable()();
  IntColumn get attachmentByteSize => integer().nullable()();

  // ── Reply (quoted-parent) metadata ──
  TextColumn get replyToId => text().nullable()();
  TextColumn get replySenderId => text().nullable()();
  TextColumn get replyType => text().nullable()();
  TextColumn get replyBody => text().nullable()();

  /// The quoted parent's own attachment metadata, JSON-encoded (small, at most
  /// one) — kept inline to avoid a second nullable attachment column set.
  TextColumn get replyAttachmentJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The durable send outbox: a logical text send that has not yet been confirmed
/// by the server, keyed by its stable idempotency key. Survives an app restart
/// so a pending message can be retried after reconnect — the backend's dedupe
/// (same key) guarantees a lost-response retry never duplicates.
///
/// Text only by design: an outgoing attachment's bytes are deliberately **not**
/// persisted (see the no-bytes rule above); attachment sends keep the existing
/// in-session retry.
class PendingMessageRows extends Table {
  TextColumn get idempotencyKey => text()();
  TextColumn get conversationId => text()();
  TextColumn get content => text().nullable()();
  TextColumn get replyToMessageId => text().nullable()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {idempotencyKey};
}

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [ChatConversationRows, ChatMessageRows, PendingMessageRows],
)
class ChatDatabase extends _$ChatDatabase {
  ChatDatabase(super.e);

  /// Opens (or creates) the on-disk chat cache under the app's documents
  /// directory. Runs the sqlite work on a background isolate so the first open
  /// never janks the UI.
  factory ChatDatabase.open() => ChatDatabase(
        LazyDatabase(() async {
          final dir = await getApplicationDocumentsDirectory();
          final file = File(p.join(dir.path, 'drop_chat_cache.sqlite'));
          return NativeDatabase.createInBackground(file);
        }),
      );

  /// An in-memory instance — for tests and any ephemeral use.
  factory ChatDatabase.memory() => ChatDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
