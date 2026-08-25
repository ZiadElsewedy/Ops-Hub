import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/premium_button.dart';

/// The values an attendance action sheet collects — proposed clock times (when
/// [AttendanceActionSheet.askTimes] is set) and a mandatory reason.
typedef AttendanceActionResult = ({
  DateTime? clockIn,
  DateTime? clockOut,
  String reason,
});

/// A **single reusable bottom sheet** for every attendance write action the engine
/// already exposes — employee *Request correction* / *Missed punch*, and manager
/// *Add record* / *Resolve* / *Excuse*. It only collects input; the caller passes
/// an [onSubmit] that invokes the matching cubit method (which owns all validation
/// via the pure validation engine) and returns whether it succeeded.
///
/// The sheet shows a loading state while [onSubmit] runs, closes with `true` on
/// success, and stays open on failure so the person can fix the input — the cubit
/// surfaces *why* through the screen's existing error snackbar. No business logic
/// lives here.
///
/// Times are entered as a time-of-day on [day]; an out-time earlier than the
/// in-time is treated as the next day (an overnight shift). Returns `true` when the
/// action succeeded, `null`/`false` when dismissed or failed.
Future<bool?> showAttendanceActionSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String submitLabel,
  required bool askTimes,
  required DateTime day,
  DateTime? seedClockIn,
  DateTime? seedClockOut,
  required Future<bool> Function(AttendanceActionResult) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => Padding(
      // Lift above the keyboard when the reason field is focused.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: AttendanceActionSheet(
        title: title,
        subtitle: subtitle,
        submitLabel: submitLabel,
        askTimes: askTimes,
        day: day,
        seedClockIn: seedClockIn,
        seedClockOut: seedClockOut,
        onSubmit: onSubmit,
      ),
    ),
  );
}

/// The sheet body (public for widget tests).
class AttendanceActionSheet extends StatefulWidget {
  const AttendanceActionSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.askTimes,
    required this.day,
    required this.onSubmit,
    this.seedClockIn,
    this.seedClockOut,
  });

  final String title;
  final String subtitle;
  final String submitLabel;
  final bool askTimes;
  final DateTime day;
  final DateTime? seedClockIn;
  final DateTime? seedClockOut;
  final Future<bool> Function(AttendanceActionResult) onSubmit;

  @override
  State<AttendanceActionSheet> createState() => _AttendanceActionSheetState();
}

class _AttendanceActionSheetState extends State<AttendanceActionSheet> {
  final _reason = TextEditingController();
  TimeOfDay? _in;
  TimeOfDay? _out;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.seedClockIn != null) _in = TimeOfDay.fromDateTime(widget.seedClockIn!);
    if (widget.seedClockOut != null) {
      _out = TimeOfDay.fromDateTime(widget.seedClockOut!);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime? _combine(TimeOfDay? tod, {bool nextDayIfBeforeIn = false}) {
    if (tod == null) return null;
    final d = widget.day;
    var out = DateTime(d.year, d.month, d.day, tod.hour, tod.minute);
    // Overnight: an out-time at/behind the in-time rolls to the next day.
    if (nextDayIfBeforeIn && _in != null) {
      final inDt = DateTime(d.year, d.month, d.day, _in!.hour, _in!.minute);
      if (!out.isAfter(inDt)) out = out.add(const Duration(days: 1));
    }
    return out;
  }

  Future<void> _pick(bool isIn) async {
    final seed = isIn ? _in : _out;
    final picked = await showTimePicker(
      context: context,
      initialTime: seed ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => isIn ? _in = picked : _out = picked);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onSubmit((
      clockIn: widget.askTimes ? _combine(_in) : null,
      clockOut: widget.askTimes
          ? _combine(_out, nextDayIfBeforeIn: true)
          : null,
      reason: _reason.text,
    ));
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, 0,
            AppSpacing.pagePadding, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(widget.subtitle,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13)),
            const SizedBox(height: AppSpacing.lg),
            if (widget.askTimes) ...[
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Clock in',
                      value: _in,
                      onTap: _submitting ? null : () => _pick(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TimeField(
                      label: 'Clock out',
                      value: _out,
                      onTap: _submitting ? null : () => _pick(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _reason,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Reason',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.darkSurfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumButton(
              label: _submitting ? 'Saving…' : widget.submitLabel,
              style: PremiumButtonStyle.filled,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, this.onTap});
  final String label;
  final TimeOfDay? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Set'
        : '${value!.hour.toString().padLeft(2, '0')}:'
            '${value!.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 11.5)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(text,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
