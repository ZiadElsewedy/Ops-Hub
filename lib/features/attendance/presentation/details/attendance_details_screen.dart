import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/opshub_loading_state.dart';
import 'package:opshub/core/widgets/status_badge.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_event.dart';
import 'package:opshub/features/attendance/presentation/details/attendance_details_cubit.dart';
import 'package:opshub/features/attendance/presentation/details/attendance_details_state.dart';
import 'package:opshub/features/attendance/presentation/details/widgets/attendance_correction_section.dart';
import 'package:opshub/features/attendance/presentation/details/widgets/attendance_metadata_section.dart';
import 'package:opshub/features/attendance/presentation/details/widgets/attendance_shift_section.dart';
import 'package:opshub/features/attendance/presentation/details/widgets/attendance_timeline.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';

/// The **Attendance record Details** screen — the canonical, audit-log view of
/// one record. Deep-linkable by [recordId]; when opened from a history list the
/// tapped record is handed over as [seed] for an instant first paint. Access is
/// enforced by `firestore.rules` (employee = own · manager = branch · admin =
/// all), so this screen never re-checks the caller's role.
class AttendanceDetailsScreen extends StatelessWidget {
  const AttendanceDetailsScreen({
    super.key,
    required this.recordId,
    this.seed,
  });

  final String recordId;
  final AttendanceEntity? seed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AttendanceDetailsCubit>(
      create: (_) => AppDependencies.createAttendanceDetailsCubit(
        recordId,
        seed: seed,
      )..load(),
      child: const _DetailsView(),
    );
  }
}

class _DetailsView extends StatelessWidget {
  const _DetailsView();

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Attendance record',
      subtitle: 'Audit detail',
      body: BlocBuilder<AttendanceDetailsCubit, AttendanceDetailsState>(
        builder: (context, state) => state.maybeMap(
          loaded: (s) => _Content(
            record: s.record,
            events: s.events,
            corrections: s.corrections,
          ),
          error: (e) => _CenterMessage(message: e.message),
          orElse: () => const OpsHubLoadingState(),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.record,
    required this.events,
    required this.corrections,
  });

  final AttendanceEntity record;
  final List<AttendanceEvent> events;
  final List<AttendanceCorrectionEntity> corrections;

  @override
  Widget build(BuildContext context) {
    final branchName =
        context.read<BranchCubit>().branchById(record.branchId)?.name;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        _Header(record: record),
        const SizedBox(height: AppSpacing.lg),
        AttendanceShiftSection(record: record),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Timeline'),
        const SizedBox(height: AppSpacing.md),
        AttendanceTimeline(record: record, events: events),
        if (corrections.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Corrections'),
          const SizedBox(height: AppSpacing.md),
          AttendanceCorrectionSection(corrections: corrections),
        ],
        const SizedBox(height: AppSpacing.xl),
        AttendanceMetadataSection(record: record, branchName: branchName),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.record});
  final AttendanceEntity record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppDateFormatter.weekdayDayMonth(r.date),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text('${r.shift.label} shift',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge.attendance(r.status),
          ],
        ),
        if (r.userName != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(r.userName!,
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 13)),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
