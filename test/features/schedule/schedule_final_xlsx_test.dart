import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/reporting/schedule_final_xlsx.dart';

UserEntity _emp(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      authProvider: 'password',
      displayName: name,
    );

WeeklyScheduleEntity _schedule() => WeeklyScheduleEntity(
      id: 'b1_2026-07-05',
      branchId: 'b1',
      weekStart: DateTime(2026, 7, 5),
      assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
          ScheduleShift.night: ['u2'],
        },
      },
      // u1 has a designated day off on Monday, so the Off row renders.
      leave: {
        ScheduleDay.monday: {'u1': LeaveType.dayOff},
      },
      dayNotes: {ScheduleDay.sunday: 'Inventory delivery'},
    );

/// Decodes the workbook and returns `{partName: utf8 content}`.
Map<String, String> _unzip(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return {
    for (final f in archive.files)
      if (f.isFile) f.name: utf8.decode(f.content as List<int>),
  };
}

void main() {
  group('buildScheduleFinalXlsx', () {
    final members = [_emp('u1', 'Salah Ahmed'), _emp('u2', 'Mona Adel')];

    test('produces a valid, unzippable OOXML package', () {
      final bytes = buildScheduleFinalXlsx(
        schedule: _schedule(),
        members: members,
        branchName: 'Drop The Shop | Arkan',
        managerName: 'Rana Fouad',
        generatedAt: DateTime(2026, 7, 9),
      );
      expect(bytes, isNotEmpty);
      // The ZIP magic number — a real xlsx is a zip container.
      expect(bytes[0], 0x50); // 'P'
      expect(bytes[1], 0x4B); // 'K'

      final parts = _unzip(bytes);
      // All required package parts are present.
      expect(parts.keys, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      ]));
    });

    test('the sheet carries the shift-row grid content', () {
      final bytes = buildScheduleFinalXlsx(
        schedule: _schedule(),
        members: members,
        branchName: 'Drop The Shop | Arkan',
        managerName: 'Rana Fouad',
        generatedAt: DateTime(2026, 7, 9),
      );
      final sheet = _unzip(bytes)['xl/worksheets/sheet1.xml']!;

      // Header block.
      expect(sheet, contains('Drop The Shop | Arkan'));
      expect(sheet, contains('Weekly staff schedule'));
      expect(sheet, contains('Manager: Rana Fouad'));

      // Shift rows down the side.
      expect(sheet, contains('Morning'));
      expect(sheet, contains('Night'));
      expect(sheet, contains('Off'));

      // People named in the cells.
      expect(sheet, contains('Salah Ahmed'));
      expect(sheet, contains('Mona Adel'));

      // Names land in their *shift* row, not only the Off row: Salah works
      // Sunday morning, so his first appearance precedes the Night label; Mona
      // works Sunday night, so hers precedes the Off label. (Regression guard —
      // a shift row that forgot its day cells would push both into Off.)
      expect(sheet.indexOf('Salah Ahmed'), lessThan(sheet.indexOf('Night')));
      expect(sheet.indexOf('Mona Adel'), lessThan(sheet.indexOf('Off')));

      // A day header and the note carried through.
      expect(sheet, contains('Sun'));
      expect(sheet, contains('Inventory delivery'));
    });

    test('escapes XML-special characters in a branch name', () {
      final bytes = buildScheduleFinalXlsx(
        schedule: _schedule(),
        members: members,
        branchName: 'A & B <Ops>',
      );
      final sheet = _unzip(bytes)['xl/worksheets/sheet1.xml']!;
      expect(sheet, contains('A &amp; B &lt;Ops&gt;'));
      // The raw, unescaped form must never leak into the XML.
      expect(sheet, isNot(contains('A & B <Ops>')));
    });

    test('filename is stable and filesystem-safe', () {
      expect(
        scheduleFinalXlsxFilename('Drop The Shop | Arkan', DateTime(2026, 7, 5)),
        'drop_the_shop_arkan_schedule_2026-07-05.xlsx',
      );
    });
  });
}
