import 'package:opshub/features/attendance/domain/attendance_location.dart';

/// Why acquiring a GPS fix for a clock action failed. Maps 1:1 onto the clock
/// rejection reasons the UI shows.
enum LocationError {
  /// The device's location services (GPS) are switched off entirely.
  serviceDisabled,

  /// The app doesn't have location permission (denied, or denied-forever).
  permissionDenied,

  /// Permission + service are fine but no fix could be read (timeout / hardware).
  unavailable,
}

/// The outcome of trying to read the device's current location — a captured
/// [AttendanceLocation] on success, or a [LocationError] explaining the failure.
/// A tiny result type (rather than throwing) so the cubit can branch cleanly and
/// tests can inject any outcome.
class LocationResult {
  final AttendanceLocation? location;
  final LocationError? error;

  const LocationResult.success(AttendanceLocation this.location) : error = null;
  const LocationResult.failure(LocationError this.error) : location = null;

  bool get ok => location != null;
}

/// Reads the device's current **high-accuracy** location, having ensured the
/// location service is on and permission is granted. Pure interface — the
/// `geolocator` implementation lives in the data layer, so the domain + cubit
/// stay plugin-free and unit-testable.
abstract class AttendanceLocationService {
  Future<LocationResult> currentLocation();
}
