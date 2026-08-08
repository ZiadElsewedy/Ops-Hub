import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/attendance/domain/attendance_directory_match.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';

const _dir = [
  AttendanceDirectoryEntry(userId: 'u-moh', name: 'Mohamed'),
  AttendanceDirectoryEntry(userId: 'u-ah', name: 'Ahmed'),
  AttendanceDirectoryEntry(userId: 'u-sa', name: 'Salama'),
];

void main() {
  group('attendanceDirectoryOnlyMatches', () {
    test('is empty with no search term (never floods the ledger)', () {
      expect(
        attendanceDirectoryOnlyMatches(
          directory: _dir,
          query: const AttendanceHistoryQuery(),
          presentUids: const {},
        ),
        isEmpty,
      );
    });

    test('surfaces a searched employee who has no record and no gap', () {
      final out = attendanceDirectoryOnlyMatches(
        directory: _dir,
        query: const AttendanceHistoryQuery(text: 'moh'),
        presentUids: const {},
      );
      expect(out.map((m) => m.userId).toList(), ['u-moh']);
    });

    test('excludes anyone already represented by a record or gap', () {
      final out = attendanceDirectoryOnlyMatches(
        directory: _dir,
        query: const AttendanceHistoryQuery(text: 'a'), // Ahmed, Salama, Mohamed
        presentUids: const {'u-ah'}, // Ahmed already has a row
      );
      expect(out.map((m) => m.userId).toSet(), {'u-moh', 'u-sa'});
    });

    test('is Arabic- and diacritic-insensitive (shares the record fold)', () {
      const dir = [
        AttendanceDirectoryEntry(userId: 'u1', name: 'مُحَمَّد'),
      ];
      final out = attendanceDirectoryOnlyMatches(
        directory: dir,
        query: const AttendanceHistoryQuery(text: 'محمد'),
        presentUids: const {},
      );
      expect(out.single.userId, 'u1');
    });

    test('sorts by name and de-dupes a doubled directory', () {
      const dir = [
        AttendanceDirectoryEntry(userId: 'u-z', name: 'Ziad'),
        AttendanceDirectoryEntry(userId: 'u-a', name: 'Adam'),
        AttendanceDirectoryEntry(userId: 'u-a', name: 'Adam'), // duplicate
      ];
      final out = attendanceDirectoryOnlyMatches(
        directory: dir,
        query: const AttendanceHistoryQuery(text: 'a'), // matches both
        presentUids: const {},
      );
      expect(out.map((m) => m.name).toList(), ['Adam', 'Ziad']);
    });
  });
}
