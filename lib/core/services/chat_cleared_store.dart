import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:drop/core/utils/app_logger.dart';

/// Pure decision — is a conversation still **fully cleared** (nothing new since
/// the viewer last cleared/deleted it)? True when the viewer has a clear
/// watermark for it and its latest activity is at or before that watermark. A
/// strictly-newer message (`lastActivityAt > watermark`) means genuine new
/// activity, so it is no longer cleared and reappears in the inbox.
///
/// Extracted so the rule is trivially unit-testable without any file I/O.
bool chatConversationCleared(DateTime? lastActivityAt, int? clearedThroughMillis) {
  if (clearedThroughMillis == null) return false;
  if (lastActivityAt == null) return true; // cleared, no activity since
  return lastActivityAt.millisecondsSinceEpoch <= clearedThroughMillis;
}

/// Persists, per signed-in user, the point through which each conversation was
/// **cleared or deleted for me** — so the inbox can honour a clear across a
/// refresh *and* a full app restart, instead of the row coming straight back
/// with the same stale last message.
///
/// The backend's delete-for-me removes messages from *history*, but the
/// conversation-list row still reports its old `lastMessageAt`/last-message
/// preview (the list endpoint does not recompute those per-viewer). Without a
/// durable client watermark the cleared conversation reappears on every reload.
/// This is that watermark: conversationId → the epoch-millis of the newest
/// activity at the moment the viewer cleared it. A later message bumps
/// `lastMessageAt` past the watermark and the conversation returns on its own.
///
/// Deliberately **client-only** (no server read-state / schema change): a small
/// JSON file in the app-support directory (via `path_provider`, the same
/// mechanism [CaseSeenStore] and the crash reporter use). State is namespaced by
/// uid so a shared device never leaks one user's clears to another. Any file
/// failure (web, sandbox) degrades to in-memory — clearing still works within
/// the session and never blocks the inbox.
class ChatClearedStore {
  ChatClearedStore();

  static const _fileName = 'chat_cleared.json';

  /// "uid:conversationId" → cleared-through epoch millis.
  final Map<String, int> _cleared = {};
  String _uid = '';
  bool _loaded = false;
  File? _file;

  String _key(String conversationId) => '$_uid:$conversationId';

  /// Loads the persisted map once and scopes reads/writes to [uid]. Cheap to
  /// call on every inbox open — it no-ops after the first load but always keeps
  /// the active uid current (so an account switch reads the right namespace).
  Future<void> load(String uid) async {
    _uid = uid;
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName');
      _file = file;
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String && v is int) _cleared[k] = v;
          });
        }
      }
    } catch (_) {
      _file = null; // in-memory only (web / sandbox) — never fatal.
    }
  }

  /// The cleared-through watermark for [conversationId] (epoch millis), or null
  /// when the viewer has never cleared it. Synchronous, so the inbox filter can
  /// read it while rendering.
  int? clearedThroughMillis(String conversationId) =>
      _cleared[_key(conversationId)];

  /// Whether [conversationId] is still fully cleared given its latest activity —
  /// the inbox hides it while this holds.
  bool isCleared(String conversationId, DateTime? lastActivityAt) =>
      chatConversationCleared(lastActivityAt, _cleared[_key(conversationId)]);

  /// Records that [conversationId] was cleared through [clearedThrough] (its
  /// newest activity at clear time; defaults to now when unknown). Advances an
  /// existing watermark but never moves it backwards. Returns whether the stored
  /// value changed (so the caller can decide to refilter the inbox).
  bool markCleared(String conversationId, DateTime? clearedThrough) {
    final ts = (clearedThrough ?? DateTime.now()).millisecondsSinceEpoch;
    final key = _key(conversationId);
    final cur = _cleared[key];
    if (cur != null && cur >= ts) return false;
    _cleared[key] = ts;
    unawaited(_persist());
    return true;
  }

  /// Drops every stored watermark — on sign-out, so the next user on a shared
  /// device never inherits this account's cleared conversations.
  void clear() {
    _cleared.clear();
    _loaded = false;
    _uid = '';
    _file = null;
    unawaited(_wipeFile());
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(_cleared));
    } catch (e) {
      AppLog.warning('chat.cleared', 'persist cleared-state failed: $e');
    }
  }

  Future<void> _wipeFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) await file.delete();
    } catch (_) {/* best-effort — see class doc */}
  }
}
