import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// The **Metadata** section — the audit-log block on the Details screen. Collapsed
/// by default; expands to a flat list of the record's technical facts.
///
/// It surfaces **only fields the record actually persists** — deliberately no
/// invented `timezone` / `app version` / `platform` / `sync status`, which OpsHub
/// does not record (adding them was declined as over-engineering). What isn't
/// stored isn't shown, so the block never implies more provenance than exists.
class AttendanceMetadataSection extends StatefulWidget {
  const AttendanceMetadataSection({
    super.key,
    required this.record,
    this.branchName,
  });

  final AttendanceEntity record;

  /// Resolved via the branch directory by the caller (falls back to the id).
  final String? branchName;

  @override
  State<AttendanceMetadataSection> createState() =>
      _AttendanceMetadataSectionState();
}

class _AttendanceMetadataSectionState extends State<AttendanceMetadataSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final rows = <_Meta>[
      _Meta('Record ID', r.id),
      _Meta('Employee', r.userName ?? '—'),
      _Meta('Employee ID', r.userId),
      _Meta('Branch', widget.branchName ?? r.branchId ?? '—'),
      _Meta('Shift', r.shift.label),
      _Meta('Attendance date', AppDateFormatter.dayMonthYear(r.date)),
      _Meta('Status', r.status.label),
      _Meta('Source', r.source.label),
      _Meta('Clock-in GPS', _gps(r.clockInVerification)),
      _Meta('Clock-out GPS', _gps(r.clockOutVerification)),
      if ((r.deviceId ?? '').isNotEmpty) _Meta('Device', r.deviceId!),
      if (r.createdAt != null)
        _Meta('Created', AppDateFormatter.dayMonthYearTime(r.createdAt!)),
      if (r.updatedAt != null)
        _Meta('Updated', AppDateFormatter.dayMonthYearTime(r.updatedAt!)),
      if (r.resolvedByName != null || r.resolvedAt != null)
        _Meta(
          'Resolved by',
          '${r.resolvedByName ?? '—'}'
              '${r.resolvedAt == null ? '' : ' · ${AppDateFormatter.dayMonth(r.resolvedAt!)}'}',
        ),
      _Meta('Data version', 'v${r.schemaVersion}'),
      if (r.deletedAt != null)
        _Meta('Deleted', AppDateFormatter.dayMonthYearTime(r.deletedAt!)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          _Header(open: _open, onTap: () => setState(() => _open = !_open)),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md,
                  AppSpacing.md),
              child: Column(
                children: [
                  const Divider(color: AppColors.darkBorder, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  for (final m in rows) _MetaRow(meta: m),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _gps(AttendanceVerification? v) {
    if (v == null) return '—';
    return '${v.verified ? 'At branch' : 'Off-site'} · '
        '${v.distanceMeters.round()} m · '
        '±${(v.location.accuracyMeters ?? 0).round()} m';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      label: 'Metadata',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.data_object_rounded,
                  size: 18, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Metadata',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: open ? 0.5 : 0,
                child: const Icon(Icons.expand_more_rounded,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.meta});
  final _Meta meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(meta.label,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12.5)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              meta.value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta {
  final String label;
  final String value;
  const _Meta(this.label, this.value);
}
