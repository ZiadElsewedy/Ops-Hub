import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/pages/schedule_final_view.dart';
import 'package:opshub/features/schedule/presentation/widgets/manager_schedule_view.dart';

/// Manager schedule screen (Phase 7 redesign) — a single operations-control
/// surface for the manager's own branch: the weekly coverage heatmap with the
/// branch's swap requests surfaced as a floating alert inside the grid (no
/// separate tab). The grid refreshes itself when a swap settles.
class BranchScheduleScreen extends StatefulWidget {
  const BranchScheduleScreen({super.key});

  @override
  State<BranchScheduleScreen> createState() => _BranchScheduleScreenState();
}

class _BranchScheduleScreenState extends State<BranchScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user == null) return;
    context.read<ShiftSwapCubit>().loadBranch(user.branchId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Schedule',
      constrainContent: false,
      actions: [
        // On mobile the Final view lives here (app bar) instead of on the
        // controls block; desktop keeps its toolbar button.
        if (!context.isDesktop) const ScheduleFinalViewAction(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: () {
            context.read<ScheduleCubit>().refresh();
            context.read<ShiftSwapCubit>().refresh();
          },
        ),
      ],
      body: const ManagerScheduleView(isAdmin: false),
    );
  }
}
