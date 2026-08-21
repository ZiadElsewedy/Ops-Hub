import 'package:geolocator/geolocator.dart';
import 'package:opshub/features/attendance/domain/attendance_location.dart';
import 'package:opshub/features/attendance/domain/attendance_location_service.dart';

/// The `geolocator`-backed [AttendanceLocationService] — the one place the plugin
/// is touched. It runs the permission → service → high-accuracy-fix sequence and
/// maps every outcome onto a [LocationResult] (never throws to the caller), so
/// the cubit stays plugin-free.
class GeolocatorLocationService implements AttendanceLocationService {
  const GeolocatorLocationService();

  /// How long to wait for a high-accuracy fix before giving up.
  static const _fixTimeout = Duration(seconds: 15);

  @override
  Future<LocationResult> currentLocation() async {
    // 1) Location services (GPS) must be on.
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failure(LocationError.serviceDisabled);
    }

    // 2) Permission — request once if it hasn't been asked yet.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(LocationError.permissionDenied);
    }

    // 3) A single high-accuracy reading.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _fixTimeout,
        ),
      );
      return LocationResult.success(AttendanceLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
        capturedAt: DateTime.now(),
      ));
    } catch (_) {
      return const LocationResult.failure(LocationError.unavailable);
    }
  }
}
