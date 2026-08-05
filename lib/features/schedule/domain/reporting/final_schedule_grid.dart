import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';

/// The final weekly schedule reshaped into the **shift-row × day-column** grid
/// the owner asked for — shifts down the side (Morning · Night · Off), days
/// across the top, and the people who work each slot named **inside** the cell.
///
/// This is the single source of truth for the published roster's *content*: the
/// on-screen [FinalScheduleSheet], the vector [buildScheduleFinalPdf] and the
/// [buildScheduleFinalXlsx] Excel export all render from one grid, so the three
/// outputs can never disagree about who is on when. Pure Dart — it reads the
/// schedule/user entities and derives nothing that isn't already there.
///
/// A person appears in the grid only if they are **on the schedule that week**
/// (at least one morning/night slot); an orphaned assignment (a uid no longer in
/// [members]) is dropped, exactly as everywhere else coverage is counted.
class FinalScheduleGrid {
  const FinalScheduleGrid({
    required this.weekStart,
    required this.days,
    required this.rosterCount,
  });

  final DateTime weekStart;

  /// The seven days, Sunday → Saturday (canonical [ScheduleDay] order).
  final List<FinalScheduleDay> days;

  /// How many distinct people are on the schedule this week.
  final int rosterCount;

  bool get isEmpty => rosterCount == 0;

  /// Representative Morning hours for the row label — the first day's resolved
  /// hours. Per-day overrides still surface in the per-cell data; the label is a
  /// single "the shift runs about here" summary, matching the source Excel.
  ShiftHours get morningHours => days.first.morningHours;

  /// Representative **weekday** Night hours for the row label (Sunday's), since
  /// the operational weekend runs later. [weekendNightDiffers] says whether the
  /// weekend override is worth spelling out.
  ShiftHours get nightHours => days.first.nightHours;

  /// True when the weekend night hours differ from the weekday night hours, so
  /// the label can note "· weekend …" instead of implying one time all week.
  bool get weekendNightDiffers {
    final weekday = days
        .firstWhere((d) => !d.day.isWeekend, orElse: () => days.first)
        .nightHours;
    final weekend = days.where((d) => d.day.isWeekend);
    return weekend.any((d) =>
        d.nightHours.startMinutes != weekday.startMinutes ||
        d.nightHours.endMinutes != weekday.endMinutes);
  }

  /// The weekend Night hours (Thursday's, a weekend day) for the label suffix.
  ShiftHours get weekendNightHours =>
      days.firstWhere((d) => d.day.isWeekend, orElse: () => days.first).nightHours;

  /// Whether any day carries a manager note (drives the optional notes row).
  bool get hasNotes => days.any((d) => d.notes.isNotEmpty);

  /// Whether anyone is explicitly off/on-leave this week (drives the optional
  /// Off row — an all-working week shows no Off row rather than a row of dashes).
  bool get hasOff => days.any((d) => d.off.isNotEmpty);
}

/// One day column of the grid — who is on each shift, who is off, the resolved
/// hours, and the day's notes.
class FinalScheduleDay {
  const FinalScheduleDay({
    required this.day,
    required this.date,
    required this.morning,
    required this.night,
    required this.off,
    required this.morningHours,
    required this.nightHours,
    required this.notes,
  });

  final ScheduleDay day;
  final DateTime date;

  /// Display names of the people on the Morning shift, sorted.
  final List<String> morning;

  /// Display names of the people on the Night shift, sorted.
  final List<String> night;

  /// Scheduled people who are **not** working this day, sorted — a plain day off
  /// or, when tagged, on leave/vacation. Mirrors the Excel sheet's OFF row.
  final List<FinalOffPerson> off;

  final ShiftHours morningHours;
  final ShiftHours nightHours;
  final List<String> notes;
}

/// A person in the Off row, with why they're off (null → a plain day off).
class FinalOffPerson {
  const FinalOffPerson(this.name, this.leave);

  final String name;
  final LeaveType? leave;

  /// A short parenthetical for the cell — `(V)` vacation, `(L)` leave, none for
  /// a plain day off.
  String get tag => switch (leave) {
        LeaveType.annual => 'V',
        LeaveType.sick || LeaveType.pending => 'L',
        _ => '',
      };
}

/// Best display name for [u] — the display name, else the email. Kept here (a
/// two-line duplicate of the presentation helper) so this stays a pure domain
/// unit with no presentation import.
String _display(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty) ? u.displayName! : u.email;

/// Builds the [FinalScheduleGrid] from a week's [schedule] and the branch
/// [members]. Pure and deterministic — names are resolved and sorted so the
/// same week always renders the same grid.
FinalScheduleGrid buildFinalScheduleGrid(
  WeeklyScheduleEntity schedule,
  List<UserEntity> members,
) {
  final byUid = {for (final m in members) m.uid: m};

  // Everyone actually on the schedule this week (≥1 slot), orphans dropped.
  final rosterUids = <String>{
    for (final day in ScheduleDay.values)
      for (final shift in ScheduleShift.values)
        for (final uid in schedule.employeesFor(day, shift))
          if (byUid.containsKey(uid)) uid,
  };

  List<String> namesFor(ScheduleDay day, ScheduleShift shift) {
    final names = <String>[
      for (final uid in schedule.employeesFor(day, shift))
        if (byUid[uid] case final u?) _display(u),
    ];
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  final days = <FinalScheduleDay>[
    for (final day in ScheduleDay.values)
      () {
        final working = schedule.employeesOn(day);
        // The Off row lists only people **explicitly** marked off/on-leave that
        // day (the leave record) — a designated day off, sick, pending or annual
        // — never everyone who simply isn't rostered. Dumping every non-working
        // member made the row swallow the sheet; a published roster's job is to
        // show who works, plus who is deliberately away.
        final off = <FinalOffPerson>[
          for (final entry in schedule.leaveOn(day).entries)
            if (byUid[entry.key] case final u? when !working.contains(entry.key))
              FinalOffPerson(_display(u), entry.value),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return FinalScheduleDay(
          day: day,
          date: schedule.weekStart.add(Duration(days: day.index)),
          morning: namesFor(day, ScheduleShift.morning),
          night: namesFor(day, ScheduleShift.night),
          off: off,
          morningHours: schedule.hoursFor(day, ScheduleShift.morning),
          nightHours: schedule.hoursFor(day, ScheduleShift.night),
          notes: schedule.noteLinesFor(day),
        );
      }(),
  ];

  return FinalScheduleGrid(
    weekStart: schedule.weekStart,
    days: days,
    rosterCount: rosterUids.length,
  );
}
