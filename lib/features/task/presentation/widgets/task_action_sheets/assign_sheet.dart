part of '../task_action_sheets.dart';

// ─── Assign (multi-select) ───────────────────────────────────────
class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.cubit, required this.task});
  final TaskCubit cubit;
  final TaskEntity task;
  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late final Future<List<UserEntity>> _future = widget.cubit.branchEmployees(
    widget.task.branchId ?? '',
  );

  late final Set<String> _selected = {...widget.task.assigneeIds};

  void _save() {
    widget.cubit.assignEmployees(
      taskId: widget.task.id,
      employeeIds: _selected.toList(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetTitle('Assign Employees'),
        FutureBuilder<List<UserEntity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final employees = snap.data ?? const [];
            if (employees.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'No employees in this branch yet.\nAsk an admin to assign '
                  'an approved employee to this branch first.',
                  style: AppTypography.bodySmall,
                ),
              );
            }
            final allSelected = employees.every(
              (u) => _selected.contains(u.uid),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick actions: whole team / clear.
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.groups_2_outlined,
                      label: allSelected
                          ? 'Team selected'
                          : 'Assign whole team',
                      active: allSelected,
                      onTap: () => setState(() {
                        if (allSelected) {
                          _selected.clear();
                        } else {
                          _selected.addAll(employees.map((u) => u.uid));
                        }
                      }),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _QuickAction(
                      icon: Icons.person_off_outlined,
                      label: 'Clear',
                      active: false,
                      onTap: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: employees.length,
                    itemBuilder: (context, i) {
                      final u = employees[i];
                      final name =
                          (u.displayName != null && u.displayName!.isNotEmpty)
                          ? u.displayName!
                          : u.email;
                      final selected = _selected.contains(u.uid);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar.fromUser(u, size: 38),
                        title: Text(name, style: AppTypography.label),
                        subtitle: Text(u.email, style: AppTypography.caption),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? AppColors.success
                              : AppColors.textTertiary,
                          size: 22,
                        ),
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(u.uid);
                          } else {
                            _selected.add(u.uid);
                          }
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _selected.isEmpty
                      ? 'Unassign'
                      : 'Assign ${_selected.length}',
                  onPressed: _save,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withAlpha(28)
                  : AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
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
