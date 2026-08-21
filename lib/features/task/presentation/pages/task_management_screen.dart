import 'package:flutter/material.dart';
import 'package:opshub/features/task/presentation/pages/admin_task_overview_screen.dart';

/// Admin task screen (Phase 4, redesigned). A **branch-based overview** — the
/// admin sees every branch with its operational vitals (Active / Pending Review
/// / Overdue / Completion Rate) and drills into a branch for the full task list
/// (create / assign / edit / review / delete). Replaces the former flat
/// all-branches list, which didn't scale. Backed by `TaskCubit`.
class TaskManagementScreen extends StatelessWidget {
  const TaskManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminTaskOverviewScreen();
}
