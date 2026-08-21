import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:opshub/core/utils/app_logger.dart';

/// Pure unread decision — a case is **unread** when its latest activity is newer
/// than the last time this viewer opened it (or they have never opened it).
/// Extracted so the rule is trivially unit-testable without any file I/O.
bool caseIsUnread(DateTime? lastActivityAt, int? seenMillis) {
  if (lastActivityAt == null) return false;
  if (seenMillis == null) return true;
  return lastActivityAt.millisecondsSinceEpoch > seenMillis;
}

/// Persists, per signed-in user, the last time each case was opened — so the
/// inbox can flag cases that have **new activity since you last looked**.
///
/// Deliberately **client-only** (no server read-receipts / schema change): a
/// small JSON file in the app-support directory (via `path_provider`, the same
/// mechanism the crash reporter uses). Seen-state is namespaced by uid so a
/// shared device never leaks one user's read-state to another. Any file failure
/// (web, sandbox) degrades to in-memory — unread still works within the session
/// and never blocks the inbox.
class CaseSeenStore {
  CaseSeenStore();

  static const _fileName = 'case_seen.json';

  /// "uid:caseId" → last-seen epoch millis.
  final Map<String, int> _seen = {};
  String _uid = '';
  bool _loaded = false;
  File? _file;

  String _key(String caseId) => '$_uid:$caseId';

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
            if (k is String && v is int) _seen[k] = v;
          });
        }
      }
    } catch (_) {
      _file = null; // in-memory only (web / sandbox) — never fatal.
    }
  }

  bool isUnread(String caseId, DateTime? lastActivityAt) =>
      caseIsUnread(lastActivityAt, _seen[_key(caseId)]);

  /// Records that [caseId] was seen up to [lastActivityAt]. Returns whether the
  /// stored value **advanced** (so the caller can decide to refresh the UI).
  bool markSeen(String caseId, DateTime? lastActivityAt) {
    final ts = (lastActivityAt ?? DateTime.now()).millisecondsSinceEpoch;
    final key = _key(caseId);
    final cur = _seen[key];
    if (cur != null && cur >= ts) return false;
    _seen[key] = ts;
    unawaited(_persist());
    return true;
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(_seen));
    } catch (e) {
      AppLog.warning('cases.seen', 'persist seen-state failed: $e');
    }
  }
}
