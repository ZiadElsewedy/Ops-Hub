import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_coverage_status.dart';

void main() {
  group('AttendanceCoverageStatus', () {
    test('no rows is missing data, never a result', () {
      final status = AttendanceCoverageStatus.resolve(
        hasRows: false,
        blockingRowCount: 0,
        hasDayGaps: true,
      );

      expect(status, AttendanceCoverageStatus.noData);
      expect(status.label, 'No data yet');
    });

    test('a blocker outranks a gap', () {
      final status = AttendanceCoverageStatus.resolve(
        hasRows: true,
        blockingRowCount: 2,
        hasDayGaps: true,
      );

      expect(status, AttendanceCoverageStatus.needsAttention);
      expect(status.label, 'Needs attention');
    });

    test(
      'rows on some days with nothing blocked is in progress, not settled',
      () {
        // The bug this enum exists to fix: the close pipeline calls a week with
        // rows on one day of seven "fully closed", because no row carries a
        // blocking exception. Saying "closed" about a mostly-empty period is a
        // trust claim the data does not support.
        final status = AttendanceCoverageStatus.resolve(
          hasRows: true,
          blockingRowCount: 0,
          hasDayGaps: true,
        );

        expect(status, AttendanceCoverageStatus.dataGap);
        expect(status.label, 'In progress');
      },
    );

    test('every day covered with nothing blocked is settled', () {
      final status = AttendanceCoverageStatus.resolve(
        hasRows: true,
        blockingRowCount: 0,
        hasDayGaps: false,
      );

      expect(status, AttendanceCoverageStatus.settled);
      expect(status.label, 'Settled');
    });

    test('only a real blocker is toned', () {
      // PP6: absence of data is never presented as a bad result. Amber on "No
      // data yet" and "In progress" is what made a week where nobody was
      // rostered read as a catastrophic week.
      expect(AttendanceCoverageStatus.noData.isActionable, isFalse);
      expect(AttendanceCoverageStatus.dataGap.isActionable, isFalse);
      expect(AttendanceCoverageStatus.settled.isActionable, isFalse);
      expect(AttendanceCoverageStatus.needsAttention.isActionable, isTrue);
    });

    test('no manager-facing label uses close-pipeline vocabulary', () {
      const banned = ['ledger', 'closed', 'phantom', 'row', 'exception'];
      for (final status in AttendanceCoverageStatus.values) {
        final label = status.label.toLowerCase();
        for (final word in banned) {
          expect(
            label.contains(word),
            isFalse,
            reason: '"${status.label}" leaks internal vocabulary: $word',
          );
        }
      }
    });
  });
}
