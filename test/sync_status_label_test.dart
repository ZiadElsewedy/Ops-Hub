import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/widgets/sync_button.dart';

/// The dashboard Sync button's relative "last synced" label — a pure function so
/// the freshness copy can be verified without pumping the whole screen.
void main() {
  final base = DateTime(2026, 7, 4, 12, 0, 0);

  test('never synced shows the bare action', () {
    expect(syncLabel(null, now: base), 'Sync');
  });

  test('within 45s reads as just now', () {
    expect(
      syncLabel(base.subtract(const Duration(seconds: 20)), now: base),
      'Synced just now',
    );
  });

  test('rolls up to minutes', () {
    expect(
      syncLabel(base.subtract(const Duration(minutes: 3)), now: base),
      'Synced 3m ago',
    );
  });

  test('rolls up to hours', () {
    expect(
      syncLabel(base.subtract(const Duration(hours: 2)), now: base),
      'Synced 2h ago',
    );
  });

  test('rolls up to days', () {
    expect(
      syncLabel(base.subtract(const Duration(days: 1, hours: 1)), now: base),
      'Synced 1d ago',
    );
  });
}
