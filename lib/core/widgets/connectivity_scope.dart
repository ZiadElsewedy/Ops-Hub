import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drop/core/network/connectivity_service.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_snackbar.dart';

/// **ConnectivityScope** — app-wide "is there a usable connection", plus the
/// honest bar that says so.
///
/// ## Why this is not a wall
///
/// An earlier version replaced the whole app when offline. That broke the one
/// case that matters most: **clock-in happens at a branch**, which is exactly
/// where signal is worst — and attendance was *designed* to survive it
/// (`attendance/{uid}_{yyyyMMdd}_{shift}` is deterministic, so a write that
/// replays late cannot duplicate). Locking the door made cached data useless
/// and turned a weak signal into "you cannot record that you came to work".
///
/// It also had no override: the reachability probe is a DNS lookup, and a
/// network that throttles or blocks that one host would strand a user outside
/// the app entirely.
///
/// So the rule is now: **block the actions, never the app.**
///
///  - Reads keep working from cache — with [OfflineBar] above them saying so,
///    which is what actually solves "stale data misleads a decision".
///  - Clock in / out stays available. It is safe by construction.
///  - Only genuinely server-authoritative actions are gated, via
///    [requireOnline] at the call site.
class ConnectivityScope extends StatefulWidget {
  const ConnectivityScope({super.key, required this.child, this.service});

  final Widget child;

  /// Injectable for tests; production builds its own.
  final ConnectivityService? service;

  @override
  State<ConnectivityScope> createState() => _ConnectivityScopeState();

  /// Whether the app currently has a usable connection.
  ///
  /// Defaults to **true** when no scope is present, so a widget tested in
  /// isolation is never accidentally treated as offline.
  static bool isOnline(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ConnectivityState>()
          ?.online ??
      true;

  /// When the connection dropped — `null` while online.
  static DateTime? offlineSince(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ConnectivityState>()
      ?.since;
}

class _ConnectivityScopeState extends State<ConnectivityScope> {
  late final ConnectivityService _service =
      widget.service ?? ConnectivityService();

  StreamSubscription<bool>? _sub;
  bool _online = true;
  DateTime? _since;

  @override
  void initState() {
    super.initState();
    _sub = _service.onStatusChange.listen(_apply);
    _service.isOnline().then(_apply);
  }

  void _apply(bool online) {
    // Set before the mounted/no-change guards: the repository guard must track
    // the connection even when this widget has nothing to repaint.
    NetworkGuard.setOnline(online);
    if (!mounted || online == _online) return;
    setState(() {
      _online = online;
      // Stamped on the way down only, so a flapping connection does not keep
      // resetting the time the user is reading.
      _since = online ? null : DateTime.now();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ConnectivityState(
        online: _online,
        since: _since,
        child: widget.child,
      );
}

class _ConnectivityState extends InheritedWidget {
  const _ConnectivityState({
    required this.online,
    required this.since,
    required super.child,
  });

  final bool online;
  final DateTime? since;

  @override
  bool updateShouldNotify(_ConnectivityState old) =>
      old.online != online || old.since != since;
}

/// A slim, permanent bar above the app while offline.
///
/// Permanent on purpose: a snackbar that disappears cannot keep a manager from
/// trusting a stale roster ten minutes later. It states *when* the connection
/// dropped rather than a vague "offline", because the real question a user has
/// in front of stale data is "how old is this?".
///
/// Takes the status-bar inset itself and removes it from the child, so screens
/// below keep laying out exactly as they do online.
class OfflineBar extends StatelessWidget {
  const OfflineBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ConnectivityScope.isOnline(context)) return child;

    final since = ConnectivityScope.offlineSince(context);
    final label = since == null
        ? 'Offline — showing saved data'
        : 'Offline since ${AppDateFormatter.time24(since)} — showing saved data';
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: AppColors.darkBg,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.darkSurfaceElevated,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              topInset + AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Guards a **server-authoritative** action. Returns `false` and explains why
/// when there is no connection.
///
/// Reserve this for decisions that must not be taken against possibly-stale
/// data, or that other people's work depends on landing *now*: a review
/// decision, publishing a schedule, sending a broadcast.
///
/// Do **not** guard clock in / out — see the note on [ConnectivityScope].
bool requireOnline(BuildContext context, {required String action}) {
  if (ConnectivityScope.isOnline(context)) return true;
  AppSnackbar.error(context, 'You are offline — $action needs a connection.');
  return false;
}
