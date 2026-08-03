import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// **ConnectivityService** — is there a *usable* connection right now?
///
/// DROP is an online-first operations tool: the app refuses to open without a
/// connection (see `ConnectivityGate`). That makes a false "online" the
/// expensive answer, so this deliberately does **not** trust
/// `connectivity_plus` on its own — that reports the network *interface*, so a
/// phone joined to a café Wi-Fi with a captive portal, or a router with no
/// upstream, both report `wifi` while nothing can actually be reached.
///
/// So the interface is used as the **trigger** and a real DNS lookup as the
/// **verdict**. The lookup targets Firestore's host: the question that matters
/// is not "is the internet up" but "can this app reach its backend".
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    Future<bool> Function()? probe,
  })  : _connectivity = connectivity ?? Connectivity(),
        _probe = probe ?? _dnsProbe;

  final Connectivity _connectivity;
  final Future<bool> Function() _probe;

  /// The host the app must be able to reach for anything to work.
  static const _host = 'firestore.googleapis.com';

  /// Kept short: this runs on a cold start, in front of the whole app, and a
  /// user staring at a blank screen is worse than an extra retry.
  static const _timeout = Duration(seconds: 5);

  static Future<bool> _dnsProbe() async {
    try {
      final result = await InternetAddress.lookup(_host).timeout(_timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// A single point-in-time verdict.
  ///
  /// The interface check short-circuits the common case: with the radio off
  /// there is nothing to probe, and skipping the lookup keeps the offline
  /// screen instant instead of waiting out a five-second timeout.
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    if (!_hasInterface(result)) return false;
    return _probe();
  }

  /// Emits on every interface change, each one re-verified by a real probe.
  ///
  /// Interface events are noisy — a hand-off from Wi-Fi to cellular fires
  /// several — and the probe is what turns that noise into an answer. The gate
  /// listening to this only ever rebuilds on a genuine change because it
  /// compares against the state it is already showing.
  Stream<bool> get onStatusChange async* {
    await for (final result in _connectivity.onConnectivityChanged) {
      if (!_hasInterface(result)) {
        yield false;
      } else {
        yield await _probe();
      }
    }
  }

  static bool _hasInterface(List<ConnectivityResult> result) =>
      result.isNotEmpty &&
      !(result.length == 1 && result.first == ConnectivityResult.none);
}
