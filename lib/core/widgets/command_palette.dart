import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_sidebar.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';

/// ⌘K command palette — the keyboard-first way around OpsHub on desktop.
/// Three result groups: **Go to** (the role's sidebar destinations, with
/// their ⌘n shortcuts), **Actions** (role-gated jumps to where the action
/// lives), and **People** (the already-loaded task directory; admin/manager
/// only). Fuzzy-free by design: prefix + substring matching is predictable
/// for a small internal tool.
Future<void> showCommandPalette(
  BuildContext context, {
  required UserEntity user,
  required List<SidebarSection> sections,
}) {
  // The directory is warm-preloaded at sign-in; read once at open.
  final people = context.read<TaskCubit>().state.maybeWhen(
        loaded: (tasks, busy, directory, isSubmitting, progress) =>
            directory.values.toList(),
        orElse: () => const <UserEntity>[],
      );
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.black.withAlpha(150),
    builder: (_) => _CommandPalette(
      user: user,
      sections: sections,
      people: people,
      go: (route) => context.go(route),
    ),
  );
}

enum _EntryKind { destination, action, person }

class _PaletteEntry {
  const _PaletteEntry({
    required this.kind,
    required this.label,
    required this.route,
    this.icon,
    this.sublabel,
    this.shortcut,
    this.person,
  });

  final _EntryKind kind;
  final String label;
  final String route;
  final IconData? icon;
  final String? sublabel;
  final String? shortcut;
  final UserEntity? person;
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({
    required this.user,
    required this.sections,
    required this.people,
    required this.go,
  });

  final UserEntity user;
  final List<SidebarSection> sections;
  final List<UserEntity> people;
  final void Function(String route) go;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _query = TextEditingController();
  int _selected = 0;

  late final List<_PaletteEntry> _destinations = [
    for (final (i, item) in widget.sections
        .expand((s) => s.items)
        .toList()
        .indexed)
      _PaletteEntry(
        kind: _EntryKind.destination,
        label: item.label,
        icon: item.icon,
        route: item.route,
        shortcut: i < 9 ? '⌘${i + 1}' : null,
      ),
  ];

  late final List<_PaletteEntry> _actions = _actionsForRole(widget.user.role);

  static List<_PaletteEntry> _actionsForRole(UserRole role) {
    _PaletteEntry action(IconData icon, String label, String route) =>
        _PaletteEntry(
            kind: _EntryKind.action, icon: icon, label: label, route: route);
    switch (role) {
      case UserRole.admin:
        return [
          action(Icons.add_task_rounded, 'New task', RouteNames.adminTasks),
          action(Icons.person_add_alt_1_rounded, 'Create account',
              RouteNames.adminCreateAccount),
          action(Icons.campaign_outlined, 'Send broadcast',
              RouteNames.communicationsCompose),
          action(Icons.fact_check_outlined, 'Review submissions',
              RouteNames.adminReview),
          action(Icons.edit_outlined, 'Edit profile', RouteNames.editProfile),
        ];
      case UserRole.manager:
        return [
          action(Icons.add_task_rounded, 'New task', RouteNames.managerTasks),
          action(Icons.campaign_outlined, 'Send broadcast',
              RouteNames.communicationsCompose),
          action(Icons.edit_outlined, 'Edit profile', RouteNames.editProfile),
        ];
      case UserRole.employee:
        return [
          action(Icons.edit_outlined, 'Edit profile', RouteNames.editProfile),
          action(
              Icons.settings_outlined, 'Settings', RouteNames.settings),
        ];
    }
  }

  /// Where a person result lands: the surface that can act on people.
  String get _peopleRoute => widget.user.role == UserRole.admin
      ? RouteNames.adminEmployees
      : RouteNames.managerTasks;

  List<_PaletteEntry> get _filtered {
    final q = _query.text.trim().toLowerCase();
    bool matches(String label) =>
        q.isEmpty || label.toLowerCase().contains(q);

    final people = widget.user.role == UserRole.employee || q.isEmpty
        ? const <_PaletteEntry>[]
        : [
            for (final p in widget.people.where((p) =>
                (p.displayName ?? p.email).toLowerCase().contains(q)))
              _PaletteEntry(
                kind: _EntryKind.person,
                label: p.displayName ?? p.email,
                sublabel: [
                  if ((p.position ?? '').isNotEmpty) p.position!,
                  p.role.value,
                ].join(' · '),
                route: _peopleRoute,
                person: p,
              ),
          ].take(5).toList();

    int rank(_PaletteEntry e) =>
        e.label.toLowerCase().startsWith(q) ? 0 : 1;
    final destinations =
        _destinations.where((e) => matches(e.label)).toList()
          ..sort((a, b) => rank(a).compareTo(rank(b)));
    final actions = _actions.where((e) => matches(e.label)).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return [...destinations, ...actions, ...people];
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _activate(List<_PaletteEntry> entries) {
    if (entries.isEmpty) return;
    final entry = entries[_selected.clamp(0, entries.length - 1)];
    Navigator.of(context).pop();
    widget.go(entry.route);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int count) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = count == 0 ? 0 : (_selected + 1) % count);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
          () => _selected = count == 0 ? 0 : (_selected - 1 + count) % count);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    if (_selected >= entries.length) _selected = 0;

    return Dialog(
      alignment: const Alignment(0, -0.55),
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF3A3A40)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Focus(
          onKeyEvent: (node, event) => _onKey(node, event, entries.length),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _query,
                        autofocus: true,
                        onChanged: (_) => setState(() => _selected = 0),
                        onSubmitted: (_) => _activate(entries),
                        cursorColor: AppColors.primary,
                        style: AppTypography.label
                            .copyWith(fontWeight: FontWeight.w400),
                        decoration: InputDecoration(
                          hintText: 'Search or run a command…',
                          hintStyle: AppTypography.body
                              .copyWith(color: AppColors.textTertiary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    _kbd('esc'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.darkBorder),
              Flexible(
                child: entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('No matches',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        children: [
                          for (final (i, entry) in entries.indexed) ...[
                            if (i == 0 ||
                                entries[i - 1].kind != entry.kind)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 10, 4),
                                child: Text(
                                  switch (entry.kind) {
                                    _EntryKind.destination => 'GO TO',
                                    _EntryKind.action => 'ACTIONS',
                                    _EntryKind.person => 'PEOPLE',
                                  },
                                  style: AppTypography.caption.copyWith(
                                      letterSpacing: 1,
                                      color: AppColors.textTertiary),
                                ),
                              ),
                            _row(entry, i == _selected, entries),
                          ],
                        ],
                      ),
              ),
              const Divider(height: 1, color: AppColors.darkBorder),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _hint('↑↓', 'navigate'),
                    const SizedBox(width: 14),
                    _hint('↵', 'open'),
                    const Spacer(),
                    _hint('⌘K', 'anywhere'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(_PaletteEntry entry, bool selected, List<_PaletteEntry> entries) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _selected = entries.indexOf(entry);
          _activate(entries);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF26262B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (entry.person != null)
                UserAvatar.fromUser(entry.person!, size: 20)
              else
                Icon(entry.icon,
                    size: 16,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (entry.sublabel != null) ...[
                const SizedBox(width: 8),
                Text(entry.sublabel!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
              if (entry.shortcut != null) ...[
                const SizedBox(width: 8),
                Text(entry.shortcut!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kbd(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.darkBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style:
                AppTypography.caption.copyWith(color: AppColors.textTertiary)),
      );

  Widget _hint(String key, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _kbd(key),
          const SizedBox(width: 5),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary)),
        ],
      );
}
