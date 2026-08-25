import 'dart:math' as math;

import 'package:opshub/features/attendance/domain/attendance_location.dart';

/// Great-circle distance between two lat/lng points in **metres** (Haversine).
/// Pure + framework-free, so the geofence decision is unit-testable and doesn't
/// depend on the `geolocator` plugin (which computes the same thing on-device).
double gpsDistanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _radians(double degrees) => degrees * math.pi / 180.0;

/// The GPS verification of one clock action — computed once at clock-in / at
/// clock-out and **persisted** on the record (separately for each; see
/// `AttendanceEntity.clockInVerification` / `clockOutVerification`). Pure value
/// object, serialized by `AttendanceModel`.
///
/// It snapshots the branch's [radiusMeters] and [minAccuracyMeters] **at the
/// moment of the action**, so the record's verification stays stable and
/// auditable even if the branch geofence is later re-tuned. [verified] is the
/// single truth "was this a legitimate at-branch clock" = inside the radius AND
/// the GPS fix was accurate enough to trust.
class AttendanceVerification {
  /// The captured device position (lat/lng · accuracy · time).
  final AttendanceLocation location;

  /// Distance from the branch centre to [location], in metres.
  final double distanceMeters;

  /// The branch's allowed radius at the time of the action (snapshot).
  final double radiusMeters;

  /// The branch's GPS-accuracy floor at the time of the action (snapshot).
  final double minAccuracyMeters;

  /// Inside the allowed radius.
  final bool withinRadius;

  /// The GPS fix was accurate enough to trust (reported accuracy ≤ floor).
  final bool accuracyOk;

  const AttendanceVerification({
    required this.location,
    required this.distanceMeters,
    required this.radiusMeters,
    required this.minAccuracyMeters,
    required this.withinRadius,
    required this.accuracyOk,
  });

  /// A legitimate at-branch clock — inside the radius with a trustworthy fix.
  bool get verified => withinRadius && accuracyOk;

  /// Evaluate a captured [location] against a branch geofence.
  static AttendanceVerification evaluate({
    required AttendanceLocation location,
    required double branchLat,
    required double branchLng,
    required double radiusMeters,
    required double minAccuracyMeters,
  }) {
    final distance = gpsDistanceMeters(
      location.latitude,
      location.longitude,
      branchLat,
      branchLng,
    );
    final accuracy = location.accuracyMeters ?? double.infinity;
    return AttendanceVerification(
      location: location,
      distanceMeters: distance,
      radiusMeters: radiusMeters,
      minAccuracyMeters: minAccuracyMeters,
      withinRadius: distance <= radiusMeters,
      accuracyOk: accuracy <= minAccuracyMeters,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AttendanceVerification &&
      other.location == location &&
      other.distanceMeters == distanceMeters &&
      other.radiusMeters == radiusMeters &&
      other.minAccuracyMeters == minAccuracyMeters &&
      other.withinRadius == withinRadius &&
      other.accuracyOk == accuracyOk;

  @override
  int get hashCode => Object.hash(location, distanceMeters, radiusMeters,
      minAccuracyMeters, withinRadius, accuracyOk);
}
