part of '../task_action_sheets.dart';

/// Assign-on-create field shown inside the task form — a summary tile (stacked
/// avatars + count) that opens a searchable employee sheet. State (the selected
/// set + the loaded future) lives on [_TaskFormSheetState]; this widget renders
/// + returns the new selection through [onChanged].
///
/// [single] switches the whole field into **one-owner** mode (Individual on a
/// new task): the tile speaks in the singular and the sheet behaves like a radio
/// list rather than a capped multi-select — picking someone *replaces* the
/// current choice instead of refusing the tap.
class _AssigneeField extends StatelessWidget {
  const _AssigneeField({
    required this.future,
    required this.selected,
    required this.onChanged,
    this.single = false,
  });

  final Future<List<UserEntity>>? future;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// One-owner mode. **Never set while editing**: a task created before this
  /// existed can carry several assignees under `individual`, and reopening it
  /// must not silently drop them.
  final bool single;

  static String _name(UserEntity u) =>
      (u.displayName != null && u.displayName!.isNotEmpty)
      ? u.displayName!
      : u.email;

  String get _label => single ? 'Assignee' : 'Assignees';
  IconData get _icon =>
      single ? Icons.person_add_alt_1_outlined : Icons.group_add_outlined;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return _PickerTile(
        icon: _icon,
        label: _label,
        placeholder: 'Pick a branch first',
        enabled: false,
      );
    }
    return FutureBuilder<List<UserEntity>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _PickerTile(
            icon: _icon,
            label: _label,
            placeholder: 'Loading people…',
            enabled: false,
          );
        }
        final employees = snap.data ?? const <UserEntity>[];
        if (employees.isEmpty) {
          return _PickerTile(
            icon: _icon,
            label: _label,
            placeholder: 'No employees in this branch yet',
            enabled: false,
          );
        }
        final chosen = [
          for (final u in employees)
            if (selected.contains(u.uid)) u,
        ];
        final value = chosen.isEmpty
            ? null
            : chosen.length == 1
            ? _name(chosen.first)
            : '${chosen.length} people';
        return _PickerTile(
          icon: _icon,
          label: _label,
          value: value,
          placeholder: single
              ? 'Choose who owns this'
              : 'Unassigned — pick who runs it',
          leading: chosen.isEmpty ? null : _AvatarStack(users: chosen),
          onTap: () async {
            final result = await showModalBottomSheet<Set<String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.darkSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => _AssigneePickerSheet(
                employees: employees,
                initial: selected,
                single: single,
              ),
            );
            if (result != null) onChanged(result);
          },
        );
      },
    );
  }
}

/// Overlapping avatar cluster (up to 3 faces + a `+N` overflow) shown as the
/// leading glyph of the assignee tile once someone is picked.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.users});
  final List<UserEntity> users;

  static const double _size = 30;
  static const double _step = 19;

  @override
  Widget build(BuildContext context) {
    const maxFaces = 3;
    final faces = users.take(maxFaces).toList();
    final extra = users.length - faces.length;
    final slots = faces.length + (extra > 0 ? 1 : 0);
    final width = _size + (slots - 1) * _step;
    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < faces.length; i++)
            Positioned(
              left: i * _step,
              child: _ringed(child: UserAvatar.fromUser(faces[i], size: 26)),
            ),
          if (extra > 0)
            Positioned(
              left: faces.length * _step,
              child: _ringed(
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.darkBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '+$extra',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ringed({required Widget child}) => Container(
    padding: const EdgeInsets.all(2),
    decoration: const BoxDecoration(
      color: AppColors.darkSurface,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

/// Searchable employee chooser opened from [_AssigneeField]. Owns a local
/// working set and returns it on "Done" (or null if dismissed), so the form only
/// commits a deliberate selection.
///
/// In [single] mode it is a radio list: the bulk actions disappear, a tap
/// *replaces* the choice, and the sheet closes immediately — one decision, one
/// gesture, no Done button to hunt for. Dismissing without tapping anyone still
/// returns null (no change).
class _AssigneePickerSheet extends StatefulWidget {
  const _AssigneePickerSheet({
    required this.employees,
    required this.initial,
    this.single = false,
  });
  final List<UserEntity> employees;
  final Set<String> initial;
  final bool single;

  @override
  State<_AssigneePickerSheet> createState() => _AssigneePickerSheetState();
}

class _AssigneePickerSheetState extends State<_AssigneePickerSheet> {
  late final Set<String> _sel = {...widget.initial};
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _name(UserEntity u) =>
      (u.displayName != null && u.displayName!.isNotEmpty)
      ? u.displayName!
      : u.email;

  @override
  Widget build(BuildContext context) {
    final single = widget.single;
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.employees
        : [
            for (final u in widget.employees)
              if ('${_name(u)} ${u.email}'.toLowerCase().contains(q)) u,
          ];
    final allSelected =
        widget.employees.isNotEmpty &&
        widget.employees.every((u) => _sel.contains(u.uid));
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
          Text(
            single ? 'Choose the owner' : 'Assign a group',
            style: AppTypography.h3,
          ),
          const SizedBox(height: 2),
          Text(
            single
                ? 'One person is accountable for this task'
                : 'Pick the people who share this work',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          // Bulk actions only make sense for a group — in one-owner mode a tap
          // is already the whole interaction.
          if (!single)
            Row(
              children: [
                _QuickAction(
                  icon: Icons.groups_2_outlined,
                  label: allSelected ? 'All selected' : 'Select all',
                  active: allSelected,
                  onTap: () => setState(() {
                    if (allSelected) {
                      _sel.clear();
                    } else {
                      _sel.addAll(widget.employees.map((u) => u.uid));
                    }
                  }),
                ),
                const SizedBox(width: AppSpacing.sm),
                _QuickAction(
                  icon: Icons.person_off_outlined,
                  label: 'Clear',
                  active: false,
                  onTap: _sel.isEmpty ? null : () => setState(_sel.clear),
                ),
              ],
            ),
          if (widget.employees.length > 6) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _search,
              label: 'Search people',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (s) => setState(() => _query = s),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final u = items[i];
                final selected = _sel.contains(u.uid);
                return _AssigneeRow(
                  name: _name(u),
                  email: u.email,
                  avatar: UserAvatar.fromUser(u, size: 38),
                  selected: selected,
                  radio: single,
                  onTap: single
                      // One owner: the tap *is* the decision — replace and
                      // close, so choosing a person is a single gesture.
                      ? () => Navigator.of(context).pop({u.uid})
                      : () => setState(() {
                          if (selected) {
                            _sel.remove(u.uid);
                          } else {
                            _sel.add(u.uid);
                          }
                        }),
                );
              },
            ),
          ),
          if (!single) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _sel.isEmpty ? 'Done' : 'Assign ${_sel.length}',
              onPressed: () => Navigator.of(context).pop(_sel),
            ),
          ],
        ],
      ),
    );
  }
}

/// A quiet one-line notice under the assignee field, explaining a reconciliation
/// the form performed on the manager's behalf (today: Group → Individual keeping
/// one owner). Switching modes should never silently discard a pick — say what
/// happened, in the manager's own words, and move on.
class _AssignmentNote extends StatelessWidget {
  const _AssignmentNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      offset: 6,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable employee row inside [_AssigneePickerSheet].
class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({
    required this.name,
    required this.email,
    required this.avatar,
    required this.selected,
    required this.onTap,
    this.radio = false,
  });

  final String name;
  final String email;
  final Widget avatar;
  final bool selected;
  final VoidCallback onTap;

  /// Draw a radio dot instead of a checkmark — the affordance has to say
  /// "exactly one of these", not "tick as many as you like".
  final bool radio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected
                  ? (radio
                        ? Icons.radio_button_checked_rounded
                        : Icons.check_circle_rounded)
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.success : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
