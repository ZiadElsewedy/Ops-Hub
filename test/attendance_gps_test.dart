import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/attendance_location.dart';

void main() {
  group('gpsDistanceMeters (Haversine)', () {
    test('the same point is 0 metres', () {
      expect(gpsDistanceMeters(30.0, 31.0, 30.0, 31.0), closeTo(0, 0.001));
    });

    test('~0.001° of latitude is ~111 metres', () {
      final d = gpsDistanceMeters(30.0, 31.0, 30.001, 31.0);
      expect(d, closeTo(111, 2));
    });

    test('is symmetric', () {
      final a = gpsDistanceMeters(30.0, 31.0, 30.02, 31.02);
      final b = gpsDistanceMeters(30.02, 31.02, 30.0, 31.0);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('AttendanceVerification.evaluate', () {
    AttendanceLocation at(double lat, double lng, double accuracy) =>
        AttendanceLocation(
            latitude: lat, longitude: lng, accuracyMeters: accuracy);

    test('inside the radius with a good fix → verified', () {
      final v = AttendanceVerification.evaluate(
        location: at(30.0002, 31.0, 8), // ~22 m from the branch
        branchLat: 30.0,
        branchLng: 31.0,
        radiusMeters: 150,
        minAccuracyMeters: 50,
      );
      expect(v.withinRadius, isTrue);
      expect(v.accuracyOk, isTrue);
      expect(v.verified, isTrue);
      expect(v.distanceMeters, closeTo(22, 3));
    });

    test('outside the radius → not within, not verified', () {
      final v = AttendanceVerification.evaluate(
        location: at(30.01, 31.0, 8), // ~1.1 km away
        branchLat: 30.0,
        branchLng: 31.0,
        radiusMeters: 150,
        minAccuracyMeters: 50,
      );
      expect(v.withinRadius, isFalse);
      expect(v.verified, isFalse);
    });

    test('a weak fix (accuracy worse than the floor) → not accuracyOk', () {
      final v = AttendanceVerification.evaluate(
        location: at(30.0, 31.0, 120), // right on the branch but ±120 m
        branchLat: 30.0,
        branchLng: 31.0,
        radiusMeters: 150,
        minAccuracyMeters: 50,
      );
      expect(v.withinRadius, isTrue);
      expect(v.accuracyOk, isFalse);
      expect(v.verified, isFalse);
    });

    test('a null accuracy is treated as untrustworthy', () {
      final v = AttendanceVerification.evaluate(
        location: const AttendanceLocation(latitude: 30.0, longitude: 31.0),
        branchLat: 30.0,
        branchLng: 31.0,
        radiusMeters: 150,
        minAccuracyMeters: 50,
      );
      expect(v.accuracyOk, isFalse);
    });
  });
}
