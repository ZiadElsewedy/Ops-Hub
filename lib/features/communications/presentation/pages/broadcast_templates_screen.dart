import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/broadcast_category.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/domain/entities/broadcast_template_entity.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_template_cubit.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_template_state.dart';
import 'package:drop/features/communications/presentation/widgets/template_card.dart';
import 'package:drop/core/widgets/app_error_state.dart';

/// The broadcast Template Library (Communications Center — Phase 2 Commit 2).
/// Grid/list toggle, search, category filter, favorites + recents, and a
/// create/edit editor. Opened from the Communications Center, or in [pickMode]
/// from the composer (tapping/using a template pops it back).
class BroadcastTemplatesScreen extends StatefulWidget {
  const BroadcastTemplatesScreen({super.key, this.pickMode = false});

  /// When true, the screen is a picker — selecting a template pops it back to
  /// the caller (the composer) instead of opening it for editing.
  final bool pickMode;

  @override
  State<BroadcastTemplatesScreen> createState() =>
      _BroadcastTemplatesScreenState();
}

class _BroadcastTemplatesScreenState extends State<BroadcastTemplatesScreen> {
  String _query = '';
  BroadcastCategory? _category; // null = all
  bool _grid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<BroadcastTemplateCubit>().load(),
    );
  }

  List<BroadcastTemplateEntity> _visible(List<BroadcastTemplateEntity> all) {
    final q = _query.trim().toLowerCase();
    return all.where((t) {
      if (_category != null && t.category != _category) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.message.toLowerCase().contains(q);
    }).toList();
  }

  void _select(BroadcastTemplateEntity t) {
    if (widget.pickMode) {
      context.read<BroadcastTemplateCubit>().markUsed(t.id);
      context.pop(t);
    } else {
      _openEditor(existing: t);
    }
  }

  Future<void> _onAction(
    BroadcastTemplateEntity t,
    TemplateCardAction action,
  ) async {
    final cubit = context.read<BroadcastTemplateCubit>();
    switch (action) {
      case TemplateCardAction.use:
        if (widget.pickMode) {
          _select(t);
        } else {
          // From the library: open the composer prefilled from the template.
          cubit.markUsed(t.id);
          context.push(RouteNames.communicationsCompose, extra: _asPrefill(t));
        }
      case TemplateCardAction.edit:
        _openEditor(existing: t);
      case TemplateCardAction.favorite:
        await cubit.toggleFavorite(t);
      case TemplateCardAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Delete template?',
          message: 'This removes "${t.title}" for everyone who can use it.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) await cubit.deleteTemplate(t.id);
    }
  }

  /// A template → a composer prefill (audience/recipient are chosen in compose).
  BroadcastEntity _asPrefill(BroadcastTemplateEntity t) => BroadcastEntity(
    id: '',
    title: t.title,
    message: t.message,
    senderId: '',
    senderName: '',
    category: t.category.value,
  );

  Future<void> _openEditor({BroadcastTemplateEntity? existing}) =>
      showTemplateEditor(context, existing: existing);

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: widget.pickMode ? 'Choose a template' : 'Templates',
      subtitle: widget.pickMode ? null : 'Reusable broadcast messages',
      actions: [
        IconButton(
          tooltip: _grid ? 'List view' : 'Grid view',
          onPressed: () => setState(() => _grid = !_grid),
          icon: Icon(
            _grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ],
      floatingActionButton: widget.pickMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'New template',
                style: AppTypography.label.copyWith(color: AppColors.onPrimary),
              ),
            ),
      body: BlocBuilder<BroadcastTemplateCubit, BroadcastTemplateState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (templates, _) => _content(templates),
          error: (m) => AppEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load templates',
            message: m,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _content(List<BroadcastTemplateEntity> all) {
    final visible = _visible(all);
    final favorites = visible.where((t) => t.isFavorite).toList();
    final recents =
        ([...visible]..sort((a, b) {
              final au = a.updatedAt ?? a.createdAt;
              final bu = b.updatedAt ?? b.createdAt;
              if (au == null && bu == null) return 0;
              if (au == null) return 1;
              if (bu == null) return -1;
              return bu.compareTo(au);
            }))
            .take(3)
            .toList();

    return Column(
      children: [
        _toolbar(),
        Expanded(
          child: visible.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.sm,
                    AppSpacing.pagePadding,
                    AppSpacing.xxxl,
                  ),
                  children: [
                    _LibraryHero(
                      total: all.length,
                      favorites: favorites.length,
                      pickMode: widget.pickMode,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (favorites.isNotEmpty && _query.isEmpty) ...[
                      _sectionLabel('Favorites'),
                      ..._render(favorites),
                    ],
                    if (recents.isNotEmpty && _query.isEmpty) ...[
                      _sectionLabel('Recent'),
                      ..._render(recents),
                    ],
                    _sectionLabel('All templates'),
                    ..._render(visible),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _render(List<BroadcastTemplateEntity> items) {
    if (_grid) {
      return [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.95,
          children: [
            for (final t in items)
              TemplateCard(
                template: t,
                compact: true,
                onTap: () => _select(t),
                onAction: (a) => _onAction(t, a),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ];
    }
    return [
      for (final t in items)
        TemplateCard(
          template: t,
          onTap: () => _select(t),
          onAction: (a) => _onAction(t, a),
        ),
    ];
  }

  Widget _toolbar() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.sm,
          AppSpacing.pagePadding,
          AppSpacing.sm,
        ),
        child: AppSearchField(
          hint: 'Search templates',
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          children: [
            _filterChip(
              'All',
              _category == null,
              () => setState(() => _category = null),
            ),
            for (final c in BroadcastCategory.values)
              _filterChip(
                c.label,
                _category == c,
                () => setState(() => _category = c),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.darkSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, AppSpacing.md, 0, AppSpacing.sm),
    child: Text(
      t.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _empty() => AppEmptyState(
    icon: Icons.dashboard_customize_outlined,
    title: _query.isNotEmpty || _category != null
        ? 'No matching templates'
        : 'No templates yet',
    message: _query.isNotEmpty || _category != null
        ? 'Try a different search or category.'
        : 'Save a reusable broadcast as a template to send it again in '
              'seconds.',
  );
}

/// A compact, monochrome inventory summary makes the library feel intentional
/// without competing with its cards or picker behavior.
class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.total,
    required this.favorites,
    required this.pickMode,
  });

  final int total;
  final int favorites;
  final bool pickMode;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.darkSurfaceElevated,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickMode
                    ? 'Start with a proven message'
                    : 'Your message library',
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                pickMode
                    ? 'Choose a template to fill your draft instantly.'
                    : 'Reusable messages, ready when the moment matters.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$total',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
            Text(
              favorites == 1 ? 'favorite' : '$favorites favorites',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The placeholder keys offered as quick-insert chips in the editor.
const List<String> kBroadcastPlaceholders = [
  'employee_name',
  'task_name',
  'branch_name',
  'date',
  'sender_name',
];

/// Opens the create/edit template editor (a modal bottom sheet). When [existing]
/// is null it creates; otherwise it edits. When [prefill] is provided (Save as
/// template from the composer), the title/message/category/priority/channel are
/// seeded.
Future<void> showTemplateEditor(
  BuildContext context, {
  BroadcastTemplateEntity? existing,
  BroadcastTemplateEntity? prefill,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TemplateEditor(
      existing: existing ?? prefill,
      isEdit: existing != null,
    ),
  );
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({this.existing, required this.isEdit});
  final BroadcastTemplateEntity? existing;
  final bool isEdit;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final TextEditingController _title;
  late final TextEditingController _message;
  late BroadcastCategory _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _message = TextEditingController(text: e?.message ?? '');
    _category = e?.category ?? BroadcastCategory.announcement;
    _title.addListener(() => setState(() {}));
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _title.text.trim().isNotEmpty &&
      _message.text.trim().isNotEmpty &&
      !_saving;

  void _insertPlaceholder(String key) {
    final token = '{{$key}}';
    final sel = _message.selection;
    final text = _message.text;
    final at = sel.isValid ? sel.start : text.length;
    final newText = text.replaceRange(at, sel.isValid ? sel.end : at, token);
    _message.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: at + token.length),
    );
  }

  Future<void> _save() async {
    final user = context.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    final cubit = context.read<BroadcastTemplateCubit>();
    final existing = widget.isEdit ? widget.existing : null;
    final entity = BroadcastTemplateEntity(
      id: existing?.id ?? '',
      title: _title.text.trim(),
      message: _message.text.trim(),
      category: _category,
      ownerId: existing?.ownerId ?? user.uid,
      // Admin templates are global ('' branch); a manager's are branch-scoped.
      branchId: user.role.isAdmin ? null : (user.branchId ?? ''),
      isFavorite: existing?.isFavorite ?? false,
      usageCount: existing?.usageCount ?? 0,
    );
    if (widget.isEdit) {
      await cubit.updateTemplate(entity);
    } else {
      await cubit.saveTemplate(entity);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        // Tap anywhere outside a field to dismiss the iOS keyboard (it has no
        // "Done" key for a multiline field, and tapping outside doesn't unfocus
        // by default — this is what made the keyboard feel "stuck").
        builder: (context, controller) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            controller: controller,
            // Dragging the sheet content also lowers the keyboard.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              AppSpacing.xl,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isEdit ? 'Edit template' : 'New template',
                      style: AppTypography.h3,
                    ),
                  ),
                  // Always-available exit: drops the keyboard, then closes the sheet.
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Close',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('Title'),
              AppTextField(controller: _title, label: 'Template title'),
              const SizedBox(height: AppSpacing.lg),
              _label('Category'),
              _chips<BroadcastCategory>(
                BroadcastCategory.values,
                _category,
                (c) => c.label,
                (c) => setState(() => _category = c),
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('Message'),
              AppTextField(
                controller: _message,
                label: 'Write the template — use placeholders below',
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in kBroadcastPlaceholders)
                    ActionChip(
                      label: Text(
                        '{{$p}}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      backgroundColor: AppColors.darkSurfaceElevated,
                      side: const BorderSide(color: AppColors.darkBorder),
                      onPressed: () => _insertPlaceholder(p),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: widget.isEdit ? 'Save changes' : 'Save template',
                isLoading: _saving,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      t.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _chips<T>(
    List<T> values,
    T selected,
    String Function(T) label,
    ValueChanged<T> onTap,
  ) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final v in values)
        GestureDetector(
          onTap: () => onTap(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: v == selected
                  ? AppColors.primary
                  : AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: v == selected ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: Text(
              label(v),
              style: AppTypography.label.copyWith(
                color: v == selected
                    ? AppColors.onPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    ],
  );
}
