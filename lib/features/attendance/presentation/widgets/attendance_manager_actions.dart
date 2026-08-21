import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/attendance/domain/attendance_board.dart';
import 'package:opshub/features/attendance/domain/attendance_write_outcome.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:opshub/features/attendance/presentation/widgets/attendance_action_sheet.dart';

/// The three manager write actions, in one place.
///
/// These were private to the admin live board. Daily Review needs the *same*
/// decisions on a past day, and two copies of a pay-affecting write path is how
/// they drift — so they moved here rather than being reimplemented. Every one
/// still goes through `AttendanceAdminCubit`, which owns the validation and the
/// approved-correction apply path; nothing here decides anything.
///
/// **They never claim more than happened.** A manager write creates an approved
/// correction; a Cloud Function applies it onto the record. Until that Function
/// is deployed the record does not move, so these report *saved, not applied
/// yet* instead of success — see [AttendanceWriteOutcome].
///
/// `dismissContext`, when given, is popped once the write lands — the live board
/// calls these from inside its detail sheet and wants it closed afterwards.

/// Settle a `pendingReview` record with real times and a mandatory reason
/// (spec workflow 12, R11).
Future<AttendanceWriteOutcome> resolveShiftDirectly(
  BuildContext context,
  AttendanceAdminCubit cubit,
  AttendanceEntity record, {
  BuildContext? dismissContext,
  String title = 'Resolve shift',
  String subtitle =
      'Set the real times — applied immediately with an audit note.',
  String submitLabel = 'Resolve',
  String appliedMessage = 'Shift resolved.',
}) async {
  var outcome = AttendanceWriteOutcome.failed;
  final submitted = await showAttendanceActionSheet(
    context,
    title: title,
    subtitle: subtitle,
    submitLabel: submitLabel,
    askTimes: true,
    day: record.date,
    seedClockIn: record.clockIn ?? record.scheduledStart,
    seedClockOut: record.clockOut ?? record.scheduledEnd,
    onSubmit: (r) async {
      final start = r.clockIn;
      if (start == null) return false;
      outcome = await cubit.resolveDirectly(
        record,
        clockIn: start,
        clockOut: r.clockOut,
        reason: r.reason,
      );
      return outcome.isWritten;
    },
  );
  if (!context.mounted) return outcome;
  return _finish(context, submitted, outcome, dismissContext, appliedMessage);
}

/// Materialize a shift the employee worked but never clocked into (spec
/// workflow 13, R11).
Future<AttendanceWriteOutcome> addAttendanceRecord(
  BuildContext context,
  AttendanceAdminCubit cubit,
  AttendanceBoardRow row, {
  BuildContext? dismissContext,
}) async {
  var outcome = AttendanceWriteOutcome.failed;
  final submitted = await showAttendanceActionSheet(
    context,
    title: 'Add attendance record',
    subtitle:
        'Record the shift ${row.name} worked — applied with an audit note.',
    submitLabel: 'Add record',
    askTimes: true,
    // The shift's own day, never `DateTime.now()`. On Daily Review the day
    // under review is not today, and seeding the time pickers from today would
    // build the times against the wrong date.
    day: row.entry.scheduledStart ?? DateTime.now(),
    seedClockIn: row.entry.scheduledStart,
    seedClockOut: row.entry.scheduledEnd,
    onSubmit: (r) async {
      final start = r.clockIn;
      if (start == null) return false;
      outcome = await cubit.addRecord(
        row,
        clockIn: start,
        clockOut: r.clockOut,
        reason: r.reason,
      );
      return outcome.isWritten;
    },
  );
  if (!context.mounted) return outcome;
  return _finish(context, submitted, outcome, dismissContext, 'Record added.');
}

/// Forgive a rostered no-show — zero worked minutes, mandatory reason
/// (spec R14).
Future<AttendanceWriteOutcome> excuseAttendanceAbsence(
  BuildContext context,
  AttendanceAdminCubit cubit,
  AttendanceBoardRow row, {
  BuildContext? dismissContext,
  String? title,
  String? subtitle,
  String? submitLabel,
  String? appliedMessage,
}) async {
  var outcome = AttendanceWriteOutcome.failed;
  final submitted = await showAttendanceActionSheet(
    context,
    title: title ?? 'Excuse absence',
    subtitle:
        subtitle ?? "Forgive ${row.name}'s missed shift — zero worked hours.",
    submitLabel: submitLabel ?? 'Excuse',
    askTimes: false,
    day: row.entry.scheduledStart ?? DateTime.now(),
    onSubmit: (r) async {
      outcome = await cubit.excuseAbsence(row, reason: r.reason);
      return outcome.isWritten;
    },
  );
  if (!context.mounted) return outcome;
  return _finish(
    context,
    submitted,
    outcome,
    dismissContext,
    appliedMessage ?? 'Absence excused.',
  );
}

/// Shown in place of the direct manager write actions on a reviewer's **own**
/// attendance row. Correcting your own attendance is forbidden server-side — no
/// self-approval (the `attendance_corrections` rules in `firestore.rules`) — so
/// rendering those buttons on your own shift would only ever produce a
/// permission failure. This states the real rule instead: file a correction from
/// My Attendance like anyone else, and a *different* reviewer approves it.
///
/// The server remains the gate; this is presentation only, so the UI stops
/// offering an action that is guaranteed to fail.
class OwnAttendanceNotice extends StatelessWidget {
  const OwnAttendanceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "You can't review your own shift. File a correction from My "
              'Attendance and another manager or admin will approve it.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Close the sheet and say what actually happened, in the manager's terms.
///
/// The pending case is deliberately **not** an error: nothing was lost, and the
/// manager should know their decision is recorded — only that the shift will not
/// look settled until an administrator finishes the setup. Reporting it as a
/// failure would push managers to redo a write that already succeeded.
AttendanceWriteOutcome _finish(
  BuildContext context,
  bool? submitted,
  AttendanceWriteOutcome outcome,
  BuildContext? dismissContext,
  String appliedMessage,
) {
  if (submitted != true || !outcome.isWritten) return outcome;
  final dismiss = dismissContext;
  if (dismiss != null && dismiss.mounted) Navigator.of(dismiss).pop();
  switch (outcome) {
    case AttendanceWriteOutcome.applied:
      AppSnackbar.success(context, appliedMessage);
    case AttendanceWriteOutcome.awaitingBackend:
      AppSnackbar.info(
        context,
        'Saved, but not applied yet — attendance updates are waiting on an '
        'administrator to finish setup. Nothing is lost.',
      );
    case AttendanceWriteOutcome.failed:
      break;
  }
  return outcome;
}
