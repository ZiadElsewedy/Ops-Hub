import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:drop/core/utils/app_logger.dart';

/// The six notification switches exposed on the Notifications settings screen.
///
/// A **plain immutable value object**, not a `freezed` entity: this is a local
/// device preference, not a business object, and it never crosses a repository
/// boundary. Keeping it codegen-free keeps `core/services` free of generated
/// files, exactly like [CaseSeenStore]'s map.
///
/// Defaults are **all on**. DROP is an internal operations tool — a new install
/// that silently withheld task reminders would be a worse default than one that
/// tells the employee too much, and the user can turn any of them off here.
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.taskReminders = true,
    this.scheduleUpdates = true,
    this.caseMessages = true,
    this.announcements = true,
    this.sound = true,
  });

  /// The master switch. When false the other five are **inert** — the UI
  /// disables them and [isCategoryActive] answers false regardless of their
  /// stored value, so turning notifications back on restores the exact set the
  /// user had chosen rather than resetting it.
  final bool enabled;
  final bool taskReminders;
  final bool scheduleUpdates;
  final bool caseMessages;
  final bool announcements;
  final bool sound;

  /// Whether a per-category switch should actually take effect — its own value
  /// **and** the master switch. Pure, so the rule is unit-testable and has one
  /// home.
  bool isCategoryActive(bool category) => enabled && category;

  NotificationPreferences copyWith({
    bool? enabled,
    bool? taskReminders,
    bool? scheduleUpdates,
    bool? caseMessages,
    bool? announcements,
    bool? sound,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    taskReminders: taskReminders ?? this.taskReminders,
    scheduleUpdates: scheduleUpdates ?? this.scheduleUpdates,
    caseMessages: caseMessages ?? this.caseMessages,
    announcements: announcements ?? this.announcements,
    sound: sound ?? this.sound,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'taskReminders': taskReminders,
    'scheduleUpdates': scheduleUpdates,
    'caseMessages': caseMessages,
    'announcements': announcements,
    'sound': sound,
  };

  /// Tolerates a missing or malformed key by falling back to that field's
  /// default, so a partially-written file can never crash the screen.
  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    bool read(String key, bool fallback) {
      final value = map[key];
      return value is bool ? value : fallback;
    }

    return NotificationPreferences(
      enabled: read('enabled', true),
      taskReminders: read('taskReminders', true),
      scheduleUpdates: read('scheduleUpdates', true),
      caseMessages: read('caseMessages', true),
      announcements: read('announcements', true),
      sound: read('sound', true),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.enabled == enabled &&
      other.taskReminders == taskReminders &&
      other.scheduleUpdates == scheduleUpdates &&
      other.caseMessages == caseMessages &&
      other.announcements == announcements &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(
    enabled,
    taskReminders,
    scheduleUpdates,
    caseMessages,
    announcements,
    sound,
  );
}

/// Persists each signed-in user's notification switches **on this device**.
///
/// Deliberately **client-only for now** (no Firestore document, no schema
/// change, no rules deploy): a small JSON file in the app-support directory,
/// exactly mirroring [CaseSeenStore] and [TaskSeenStore]. That is also why the
/// project does not take a `shared_preferences` dependency for it — the app
/// already has one local-preference mechanism and a second would be two.
///
/// Preferences are namespaced by uid so a shared device never applies one
/// user's choices to another. Any file failure (sandbox, web) degrades to
/// in-memory: the switches still work for the session and never block the
/// screen.
///
/// **Not yet wired to delivery.** Nothing reads these values to suppress a push
/// or an in-app notification — the Firebase/FCM side is a later step. The store
/// is the seam that step will read.
///
/// **Never notifies.** A plain object, not a `ChangeNotifier`: callers set a
/// value from a gesture callback and rebuild themselves.
class NotificationPreferencesStore {
  NotificationPreferencesStore();

  static const _fileName = 'notification_preferences.json';

  /// uid → that user's stored switches.
  final Map<String, NotificationPreferences> _byUid = {};
  String _uid = '';
  bool _loaded = false;
  File? _file;

  /// Whether the persisted file has been read yet. The screen holds its rows
  /// behind this so the switches never paint a default the user did not choose
  /// and then flip a frame later.
  bool get isLoaded => _loaded;

  /// The active user's preferences (defaults until [load] completes).
  NotificationPreferences get preferences =>
      _byUid[_uid] ?? const NotificationPreferences();

  /// The already-loaded preferences for [uid], or null when the file has not
  /// been read yet. Lets a returning visit paint the user's real switches on
  /// its first frame instead of flashing a placeholder.
  NotificationPreferences? loadedFor(String uid) {
    if (!_loaded) return null;
    _uid = uid;
    return preferences;
  }

  /// Reads the file once and scopes reads/writes to [uid]. Cheap to call on
  /// every screen open — it no-ops after the first load but always keeps the
  /// active uid current, so an account switch reads the right namespace.
  Future<NotificationPreferences> load(String uid) async {
    _uid = uid;
    if (_loaded) return preferences;
    try {
      await _read().timeout(_readTimeout);
    } catch (_) {
      _file = null; // in-memory only (web / sandbox) — never fatal.
    }
    _loaded = true;
    return preferences;
  }

  /// The screen holds its switches behind [isLoaded], so a read that never
  /// answers would leave it on placeholders forever. Bounded so the worst case
  /// is "we show the defaults", not "we show nothing".
  static const _readTimeout = Duration(seconds: 2);

  Future<void> _read() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    _file = file;
    if (!await file.exists()) return;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (k is String && v is Map) {
        _byUid[k] = NotificationPreferences.fromMap(
          Map<String, dynamic>.from(v),
        );
      }
    });
  }

  /// Stores [prefs] for the active user and persists in the background.
  void save(NotificationPreferences prefs) {
    if (_uid.isEmpty) return;
    if (_byUid[_uid] == prefs) return;
    _byUid[_uid] = prefs;
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode(_byUid.map((k, v) => MapEntry(k, v.toMap()))),
      );
    } catch (e) {
      AppLog.warning(
        'settings.notifications',
        'persist notification preferences failed: $e',
      );
    }
  }
}
