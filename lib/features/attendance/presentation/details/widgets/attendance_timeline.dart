import 'package:flutter/material.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/timeline_tile.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_event.dart';

/// The record's **timeline** — its server-derived audit trail
/// ([AttendanceEvent]s) rendered through the shared [TimelineTile], so it reads
/// the same as the Task activity timeline and already supports every future kind
/// (breaks, corrections, manager edits) without a redesign.
///
/// The audit trail is written by a Cloud Function (`onAttendanceWritten`). Until
/// that is deployed the `events` stream is empty, so this **falls back to
/// synthesizing** the clock-in / clock-out / auto-close steps directly from the
/// record — the timeline is useful immediately and upgrades to the authoritative
/// trail automatically once the Function lands.
class AttendanceTimeline extends StatelessWidget {
  const AttendanceTimeline({
    super.key,
    required this.record,
    required this.events,
  });

  final AttendanceEntity record;
  final List<AttendanceEvent> events;

  @override
  Widget build(BuildContext context) {
    final items = events.isNotEmpty ? _fromEvents() : _synthesize();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('No activity recorded for this shift.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          TimelineTile(
            title: items[i].title,
            titleColor: items[i].color,
            time: AppDateFormatter.time(items[i].at),
            subtitle: items[i].actor,
            note: items[i].note,
            dotColor: items[i].color,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }

  List<_Item> _fromEvents() => [
        for (final e in events)
          _Item(
            title: e.kind.label,
            at: e.createdAt,
            actor: e.actorName,
            note: e.note,
            color: _eventColor(e.kind),
          ),
      ];

  /// Best-effort reconstruction from the record when the audit trail is empty.
  List<_Item> _synthesize() {
    final actor = record.userName;
    final out = <_Item>[];
    if (record.clockIn != null) {
      out.add(_Item(
        title: AttendanceEventKind.clockedIn.label,
        at: record.clockIn!,
        actor: actor,
        color: AppColors.success,
      ));
    }
    if (record.clockOut != null) {
      out.add(_Item(
        title: AttendanceEventKind.clockedOut.label,
        at: record.clockOut!,
        actor: record.source.isSelfClocked ? actor : record.source.label,
        color: AppColors.textSecondary,
      ));
    } else if (record.status == AttendanceStatus.pendingReview) {
      out.add(_Item(
        title: AttendanceEventKind.autoClosed.label,
        at: record.updatedAt ?? record.date,
        note: 'This shift was auto-closed — no clock-out was recorded.',
        color: AppColors.warning,
      ));
    }
    if (record.status == AttendanceStatus.absent) {
      out.add(_Item(
        title: AttendanceEventKind.markedAbsent.label,
        at: record.updatedAt ?? record.date,
        color: AppColors.error,
      ));
    }
    return out;
  }
}

class _Item {
  final String title;
  final DateTime at;
  final String? actor;
  final String? note;
  final Color color;
  const _Item({
    required this.title,
    required this.at,
    required this.color,
    this.actor,
    this.note,
  });
}

Color _eventColor(AttendanceEventKind kind) => switch (kind) {
      AttendanceEventKind.clockedIn => AppColors.success,
      AttendanceEventKind.clockedOut => AppColors.textSecondary,
      AttendanceEventKind.breakStarted ||
      AttendanceEventKind.breakEnded =>
        AppColors.textTertiary,
      AttendanceEventKind.autoClosed ||
      AttendanceEventKind.correctionRequested =>
        AppColors.warning,
      AttendanceEventKind.correctionApproved => AppColors.success,
      AttendanceEventKind.correctionRejected ||
      AttendanceEventKind.markedAbsent =>
        AppColors.error,
      AttendanceEventKind.reviewed ||
      AttendanceEventKind.managerEdited =>
        AppColors.primary,
    };
