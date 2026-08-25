import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// The per-employee state on the attendance board — the **join of the roster and
/// today's attendance records**, derived against the current time. This is the
/// single source of "who's working / late / absent" and it is **role-agnostic**:
/// the Admin dashboard and a future Manager view both render the same rows; only
/// the branch *scope* differs.
enum AttendanceBoardStatus {
  /// Rostered, hasn't clocked in yet, still inside the grace window.
  notStarted,

  /// Rostered, hasn't clocked in, the shift is under way and grace has passed.
  late,

  /// Clocked in, not yet out.
  working,

  /// Clocked out.
  completed,

  /// Rostered, the shift is over, never clocked in.
  absent,

  /// On leave today (from the schedule) — not expected.
  onLeave,

  /// A manager forgave the absence (a materialized `excused` record) — benign,
  /// not expected to work.
  excused,

  /// Auto-closed / flagged, waiting on a correction or review.
  pendingReview,

  /// Clocked in with no rostered shift ([ADR-018]). Real, recorded work that
  /// the roster does not vouch for — it needs a manager's decision before it
  /// counts anywhere.
  unscheduled;

  String get label => switch (this) {
        AttendanceBoardStatus.notStarted => 'Not started',
        AttendanceBoardStatus.late => 'Late',
        AttendanceBoardStatus.working => 'Working',
        AttendanceBoardStatus.completed => 'Completed',
        AttendanceBoardStatus.absent => 'Absent',
        AttendanceBoardStatus.onLeave => 'On leave',
        AttendanceBoardStatus.excused => 'Excused',
        AttendanceBoardStatus.pendingReview => 'Needs review',
        AttendanceBoardStatus.unscheduled => 'Unscheduled',
      };

  /// Sort weight — problems first (an admin scanning the board sees what needs
  /// action at the top), routine states last.
  int get priority => switch (this) {
        AttendanceBoardStatus.pendingReview => 0,
        // Above absent: an unrecognised punch means someone worked and the
        // record does not yet count. That is money and hours, not just coverage.
        AttendanceBoardStatus.unscheduled => 1,
        AttendanceBoardStatus.absent => 2,
        AttendanceBoardStatus.late => 3,
        AttendanceBoardStatus.working => 4,
        AttendanceBoardStatus.notStarted => 5,
        AttendanceBoardStatus.completed => 6,
        AttendanceBoardStatus.onLeave => 7,
        AttendanceBoardStatus.excused => 8,
      };
}

/// One rostered slot for today, resolved from the schedule (the cubit builds
/// these from `WeeklyScheduleEntity` + `ShiftWindow` + branch users). Pure input
/// to [computeAttendanceBoard].
class AttendanceRosterEntry {
  final String uid;
  final String name;
  final ScheduleShift shift;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final LeaveType? leave;

  const AttendanceRosterEntry({
    required this.uid,
    required this.name,
    required this.shift,
    this.scheduledStart,
    this.scheduledEnd,
    this.leave,
  });
}

/// One board row — a roster entry joined with its attendance [record] (null when
/// the employee hasn't clocked in) and the derived [status].
class AttendanceBoardRow {
  final AttendanceRosterEntry entry;
  final AttendanceEntity? record;
  final AttendanceBoardStatus status;

  /// Late in any sense — clocked in after grace, OR overdue and not yet in.
  final bool isLate;

  const AttendanceBoardRow({
    required this.entry,
    required this.record,
    required this.status,
    required this.isLate,
  });

  String get uid => entry.uid;
  String get name => entry.name;
  ScheduleShift get shift => entry.shift;

  /// The clock-in GPS verification, when the employee clocked in.
  bool get isVerified => record?.isClockInVerified ?? false;
  bool get hasGps => record?.clockInVerification != null;
}

/// The whole board — rows (sorted problems-first) plus the headline counts the
/// admin KPIs read.
class AttendanceBoard {
  final List<AttendanceBoardRow> rows;

  const AttendanceBoard(this.rows);

  static const AttendanceBoard empty = AttendanceBoard(<AttendanceBoardRow>[]);

  int get rostered => rows.length;
  int _count(AttendanceBoardStatus s) =>
      rows.where((r) => r.status == s).length;

  int get working => _count(AttendanceBoardStatus.working);
  int get completed => _count(AttendanceBoardStatus.completed);
  int get absent => _count(AttendanceBoardStatus.absent);
  int get notStarted => _count(AttendanceBoardStatus.notStarted);
  int get onLeave => _count(AttendanceBoardStatus.onLeave);
  int get excused => _count(AttendanceBoardStatus.excused);
  int get pendingReview => _count(AttendanceBoardStatus.pendingReview);

  /// Everyone late in any sense (overdue no-shows + late arrivals).
  int get late => rows.where((r) => r.isLate).length;

  /// Showed up today (working, completed, or pending-review — they clocked in).
  int get present => rows.where((r) => r.record?.hasClockedIn ?? false).length;

  /// Rows filtered to a single status (for the KPI drill-downs).
  List<AttendanceBoardRow> withStatus(AttendanceBoardStatus s) =>
      rows.where((r) => r.status == s).toList();
}

/// Joins [roster] with today's [records] and derives each employee's board
/// status against [now]. Pure + framework-free — the single place the
/// "Not started → Late → Absent" policy lives (see [AttendanceBoardStatus]).
///
/// A no-show is timed against the schedule: before `start + lateGrace` →
/// notStarted; after grace while the shift runs → late; after the scheduled end
/// → absent. A record present resolves to working / completed / pendingReview,
/// carrying a late flag when the clock-in itself was late.
AttendanceBoard computeAttendanceBoard({
  required List<AttendanceRosterEntry> roster,
  required List<AttendanceEntity> records,
  required DateTime now,
  AttendanceConfig config = AttendanceConfig.defaults,
}) {
  final rows = <AttendanceBoardRow>[];

  for (final entry in roster) {
    final record = _recordFor(records, entry.uid, entry.shift);

    final AttendanceBoardStatus status;
    var isLate = false;

    if (record != null) {
      isLate = record.isLate;
      if (record.status == AttendanceStatus.excused) {
        status = AttendanceBoardStatus.excused;
      } else if (record.needsReview) {
        status = AttendanceBoardStatus.pendingReview;
      } else if (record.isOpen) {
        status = AttendanceBoardStatus.working;
      } else {
        status = AttendanceBoardStatus.completed;
      }
    } else if (entry.leave != null) {
      status = AttendanceBoardStatus.onLeave;
    } else {
      final start = entry.scheduledStart;
      if (start == null) {
        status = AttendanceBoardStatus.notStarted;
      } else {
        final opensLate =
            start.add(Duration(minutes: config.lateGraceMinutes));
        final end = entry.scheduledEnd;
        if (now.isBefore(opensLate)) {
          status = AttendanceBoardStatus.notStarted;
        } else if (end != null && now.isAfter(end)) {
          status = AttendanceBoardStatus.absent;
        } else {
          status = AttendanceBoardStatus.late; // overdue, shift still running
          isLate = true;
        }
      }
    }

    // A leave day with a clock-in (they came in anyway) stays a real record
    // status; leave only wins when there's no record.
    rows.add(AttendanceBoardRow(
      entry: entry,
      record: record,
      status: status,
      isLate: isLate,
    ));
  }

  // Records with no roster slot — an unscheduled shift ([ADR-018]). The loop
  // above walks the roster, so without this the punch exists in Firestore and is
  // invisible to every manager surface. A synthesized entry carries the identity
  // the record already holds and, deliberately, **no scheduled window** — that
  // absence is what marks the shift unscheduled everywhere downstream.
  for (final record in records) {
    if (record.isDeleted) continue;
    final matched = roster.any(
      (e) => e.uid == record.userId && e.shift == record.shift,
    );
    if (matched) continue;
    rows.add(
      AttendanceBoardRow(
        entry: AttendanceRosterEntry(
          uid: record.userId,
          name: record.userName ?? record.userId,
          shift: record.shift,
        ),
        record: record,
        status: record.status == AttendanceStatus.excused
            ? AttendanceBoardStatus.excused
            : AttendanceBoardStatus.unscheduled,
        isLate: false, // nothing to be late for
      ),
    );
  }

  rows.sort((a, b) {
    final byPriority = a.status.priority.compareTo(b.status.priority);
    if (byPriority != 0) return byPriority;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return AttendanceBoard(rows);
}

AttendanceEntity? _recordFor(
  List<AttendanceEntity> records,
  String uid,
  ScheduleShift shift,
) {
  for (final r in records) {
    if (r.userId == uid && r.shift == shift && !r.isDeleted) return r;
  }
  return null;
}
