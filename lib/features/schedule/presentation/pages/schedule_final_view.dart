import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/presentation/widgets/final_schedule_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

/// Opens an opaque route on the root navigator so the final roster is shown
/// above the authenticated desktop shell and sidebar.
Future<void> showScheduleFinalView({
  required BuildContext context,
  required WeeklyScheduleEntity schedule,
  required List<UserEntity> members,
  required BranchEntity? branch,
  ScheduleShift? filter,
  Set<String> previousSaturdayNight = const {},
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: AppColors.darkBg,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: animation,
        child: ScheduleFinalView(
          schedule: schedule,
          members: members,
          branch: branch,
          filter: filter,
          previousSaturdayNight: previousSaturdayNight,
        ),
      ),
    ),
  );
}

/// A real export surface: the toolbar remains visible for navigation while the
/// isolated landscape [RepaintBoundary] (the [FinalScheduleSheet]) is saved as a
/// controls-free PNG.
class ScheduleFinalView extends StatefulWidget {
  const ScheduleFinalView({
    super.key,
    required this.schedule,
    required this.members,
    required this.branch,
    this.filter,
    this.previousSaturdayNight = const {},
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final BranchEntity? branch;

  /// Retained for the editor's launch signature. The published sheet always
  /// shows the whole week (both shifts), so this no longer narrows the output.
  final ScheduleShift? filter;

  /// Retained for the editor's launch signature. The redesigned sheet carries no
  /// health/short-rest cues, so this is no longer consumed here.
  final Set<String> previousSaturdayNight;

  @override
  State<ScheduleFinalView> createState() => _ScheduleFinalViewState();
}

class _ScheduleFinalViewState extends State<ScheduleFinalView> {
  final _captureKey = GlobalKey();
  bool _saving = false;

  void _openDashboard() {
    final user = context.currentUser;
    if (user == null) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(RouteNames.homeForRole(user.role));
  }

  /// The branch manager's name for the printed header (null when the roster has
  /// no manager among its members).
  String? _managerName() {
    for (final m in widget.members) {
      if (m.role == UserRole.manager) return userDisplayName(m);
    }
    return null;
  }

  Future<void> _savePng() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Export canvas is unavailable.');

      // 1600-wide landscape sheet captured at 1.5× — crisp on Retina and for
      // print, without an unnecessarily huge file or any preview toolbar chrome.
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('PNG encoding failed.');

      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filename = scheduleExportFilename(
        widget.branch?.name ?? 'branch',
        widget.schedule.weekStart,
      );
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (mounted) {
        AppSnackbar.success(context, 'Saved to Downloads · $filename');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not save the schedule PNG.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF080809),
          body: SafeArea(
            child: Column(
              children: [
                _PreviewToolbar(
                  saving: _saving,
                  onBack: () => Navigator.of(context).maybePop(),
                  onDashboard: _openDashboard,
                  onSave: _savePng,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.darkBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withAlpha(150),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: _captureKey,
                            child: FinalScheduleSheet(
                              schedule: widget.schedule,
                              members: widget.members,
                              branch: widget.branch,
                              managerName: _managerName(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stable, filesystem-safe name for the exported schedule image.
String scheduleExportFilename(String branchName, DateTime weekStart) {
  final safe = branchName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .toLowerCase();
  final y = weekStart.year.toString().padLeft(4, '0');
  final m = weekStart.month.toString().padLeft(2, '0');
  final d = weekStart.day.toString().padLeft(2, '0');
  return '${safe.isEmpty ? 'branch' : safe}_schedule_$y-$m-$d.png';
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.saving,
    required this.onBack,
    required this.onDashboard,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onDashboard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            return Row(
              children: [
              Tooltip(
                message: 'Back to schedule',
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: compact
                      ? const SizedBox.shrink()
                      : const Text('Back to schedule'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: 'Dashboard',
                child: TextButton.icon(
                  onPressed: onDashboard,
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: compact
                      ? const SizedBox.shrink()
                      : const Text('Dashboard'),
                ),
              ),
              if (constraints.maxWidth >= 980) ...[
                const SizedBox(width: AppSpacing.md),
                const Text(
                  'Export preview · controls are not included in the PNG',
                  style: AppTypography.caption,
                ),
              ],
              const Spacer(),
              Tooltip(
                message: saving ? 'Saving PNG' : 'Save PNG',
                child: FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: compact
                      ? const SizedBox.shrink()
                      : Text(saving ? 'Saving…' : 'Save PNG'),
                ),
              ),
            ],
            );
          },
        ),
      ),
    );
  }
}
