import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/data/models/branch_model.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';

void main() {
  group('BranchGeofence', () {
    test('.at applies the standing defaults (150 m radius, 50 m accuracy)', () {
      final g = BranchGeofence.at(30.0444, 31.2357);
      expect(g.radiusMeters, 150);
      expect(g.minAccuracyMeters, 50);
    });

    test('toMap → fromMap round-trips', () {
      const g = BranchGeofence(
        latitude: 30.0444,
        longitude: 31.2357,
        radiusMeters: 120,
        minAccuracyMeters: 35,
      );
      expect(BranchGeofence.fromMap(g.toMap()), g);
    });
  });

  group('BranchGeofence.validateInput', () {
    String? check({
      double? lat = 30.0,
      double? lng = 31.0,
      double? radius = 150,
      double? acc = 50,
    }) =>
        BranchGeofence.validateInput(
          latitude: lat,
          longitude: lng,
          radiusMeters: radius,
          minAccuracyMeters: acc,
        );

    test('valid input passes', () => expect(check(), isNull));
    test('missing location', () => expect(check(lat: null), isNotNull));
    test('latitude out of range', () => expect(check(lat: 120), isNotNull));
    test('longitude out of range', () => expect(check(lng: 250), isNotNull));
    test('zero radius', () => expect(check(radius: 0), isNotNull));
    test('negative accuracy', () => expect(check(acc: -1), isNotNull));
  });

  group('BranchModel geofence persistence', () {
    test('geofence survives fromEntity → toEntity', () {
      const g = BranchGeofence(
          latitude: 30.0, longitude: 31.0, radiusMeters: 200, minAccuracyMeters: 40);
      final e = const BranchEntity(id: 'b1', name: 'B1').copyWith(geofence: g);
      expect(BranchModel.fromEntity(e).toEntity().geofence, g);
    });

    test('a branch with no geofence field parses to null', () {
      final e = BranchModel.fromMap({'name': 'B1'}, id: 'b1').toEntity();
      expect(e.geofence, isNull);
      expect(e.hasGeofence, isFalse);
    });

    test('the general toMap omits geofence (never clobbers it)', () {
      const g = BranchGeofence(latitude: 30.0, longitude: 31.0);
      final e = const BranchEntity(id: 'b1', name: 'B1').copyWith(geofence: g);
      expect(BranchModel.fromEntity(e).toMap().containsKey('geofence'), isFalse);
    });
  });

  group('BranchModel manager clock persistence', () {
    test('missing manager clock flag defaults to enabled for legacy branches', () {
      final model = BranchModel.fromMap({'name': 'B1'}, id: 'b1');
      expect(model.managersCanClock, isTrue);
      expect(model.toEntity().managersCanClock, isTrue);
    });

    test('reads a disabled manager clock flag', () {
      final model =
          BranchModel.fromMap({'name': 'B1', 'managersCanClock': false}, id: 'b1');
      expect(model.managersCanClock, isFalse);
      expect(model.toEntity().managersCanClock, isFalse);
    });

    test('round-trips the manager clock flag through toMap', () {
      final original = BranchModel.fromEntity(
        const BranchEntity(id: 'b1', name: 'B1', managersCanClock: false),
      );
      final restored = BranchModel.fromMap(original.toMap(), id: original.id);
      expect(restored.managersCanClock, isFalse);
    });
  });
}
