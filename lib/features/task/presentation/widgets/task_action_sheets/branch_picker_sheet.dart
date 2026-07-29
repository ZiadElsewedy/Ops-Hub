part of '../task_action_sheets.dart';

/// Branch picker for the admin task form — loads active branches from Firestore
/// and surfaces the choice as a premium summary tile that opens a searchable
/// chooser sheet (never a bare dropdown, so a long branch list stays scannable).
class _BranchField extends StatelessWidget {
  const _BranchField({
    required this.future,
    required this.value,
    required this.onChanged,
  });

  final Future<List<BranchEntity>> future;
  final String? value;
  final ValueChanged<String?> onChanged;

  static String _label(BranchEntity b) =>
      (b.location == null || b.location!.isEmpty)
      ? b.name
      : '${b.name} · ${b.location}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchEntity>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final branches = snap.data ?? const <BranchEntity>[];
        BranchEntity? selected;
        for (final b in branches) {
          if (b.id == value) selected = b;
        }
        final ready = !loading && branches.isNotEmpty;
        return _PickerTile(
          icon: Icons.store_mall_directory_outlined,
          label: 'Branch',
          value: selected == null ? null : _label(selected),
          placeholder: loading
              ? 'Loading branches…'
              : branches.isEmpty
              ? 'No branches — create one first'
              : 'Select a branch',
          enabled: ready,
          onTap: () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.darkSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) =>
                  _BranchPickerSheet(branches: branches, selectedId: value),
            );
            if (picked != null) onChanged(picked);
          },
        );
      },
    );
  }
}

/// Searchable branch chooser opened from [_BranchField].
class _BranchPickerSheet extends StatefulWidget {
  const _BranchPickerSheet({required this.branches, required this.selectedId});
  final List<BranchEntity> branches;
  final String? selectedId;

  @override
  State<_BranchPickerSheet> createState() => _BranchPickerSheetState();
}

class _BranchPickerSheetState extends State<_BranchPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.branches
        : [
            for (final b in widget.branches)
              if ('${b.name} ${b.location ?? ''}'.toLowerCase().contains(q)) b,
          ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: AppSpacing.sm),
          const Text('Select branch', style: AppTypography.h3),
          const SizedBox(height: 2),
          const Text('Where this work happens', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          if (widget.branches.length > 6) ...[
            AppTextField(
              controller: _search,
              label: 'Search branches',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (s) => setState(() => _query = s),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final b = items[i];
                return _BranchRow(
                  branch: b,
                  selected: b.id == widget.selectedId,
                  onTap: () => Navigator.of(context).pop(b.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.branch,
    required this.selected,
    required this.onTap,
  });
  final BranchEntity branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLocation = branch.location != null && branch.location!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primarySurface
              : AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
        child: Row(
          children: [
            const _LeadIcon(icon: Icons.store_mall_directory_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 1),
                    Text(
                      branch.location!,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
