import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/utils/app_logger.dart';

/// Pure "new task" decision — a task is **unseen** when it is still `pending`
/// and this viewer has never opened it. Extracted so the rule is trivially
/// unit-testable without any file I/O.
///
/// Deliberately narrow: only a *pending* task can be new. The moment work
/// starts (or the task reaches any other status) it is no longer an
/// unacknowledged arrival, so the attention treatment must not apply — see
/// [taskAttentionTone] in
/// `features/task/presentation/widgets/task_attention_surface.dart`.
bool taskIsUnseen(TaskStatus status, int? seenMillis) =>
    status == TaskStatus.pending && seenMillis == null;

/// Persists, per signed-in user, which tasks this viewer has already opened —
/// so Home can give a genuinely *new* task its one-time attention treatment and
/// drop it permanently the moment the employee acknowledges it.
///
/// Deliberately **client-only** (no server read-receipts / schema change / rules
/// deploy): a small JSON file in the app-support directory, exactly mirroring
/// [CaseSeenStore]. Seen-state is namespaced by uid so a shared device never
/// leaks one user's state to another. Any file failure (web, sandbox) degrades
/// to in-memory — the treatment still clears within the session and never
/// blocks the dashboard.
///
/// **Never notifies.** This is a plain object, not a `ChangeNotifier`: callers
/// mark a task seen from a gesture callback and rebuild themselves. A store that
/// notified its listeners synchronously would fire "setState during build".
class TaskSeenStore {
  TaskSeenStore();

  static const _fileName = 'task_seen.json';

  /// "uid:taskId" → first-opened epoch millis.
  final Map<String, int> _seen = {};
  String _uid = '';
  bool _loaded = false;
  File? _file;

  String _key(String taskId) => '$_uid:$taskId';

  /// Whether the persisted map has been read yet. Callers should hold off on the
  /// attention treatment until this is true, otherwise every task looks new for
  /// the frame or two before the file lands.
  bool get isLoaded => _loaded;

  /// Loads the persisted map once and scopes reads/writes to [uid]. Cheap to
  /// call on every Home open — it no-ops after the first load but always keeps
  /// the active uid current (so an account switch reads the right namespace).
  Future<void> load(String uid) async {
    _uid = uid;
    if (_loaded) return;
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
    } finally {
      _loaded = true;
    }
  }

  /// Whether [taskId] should wear the attention treatment right now.
  bool isUnseen(String taskId, TaskStatus status) =>
      taskIsUnseen(status, _seen[_key(taskId)]);

  /// Records that [taskId] was opened. Returns whether this was the **first**
  /// time (so the caller can decide to rebuild). Seen is permanent — a task
  /// never re-arms.
  bool markSeen(String taskId) {
    final key = _key(taskId);
    if (_seen.containsKey(key)) return false;
    _seen[key] = DateTime.now().millisecondsSinceEpoch;
    unawaited(_persist());
    return true;
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(_seen));
    } catch (e) {
      AppLog.warning('tasks.seen', 'persist seen-state failed: $e');
    }
  }
}
