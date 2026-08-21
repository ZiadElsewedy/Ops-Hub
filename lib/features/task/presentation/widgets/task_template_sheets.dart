import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/task_type.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/task_template_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/widgets/task_action_sheets.dart';

/// How the manager/admin wants to start a new task.
enum NewTaskChoice { blank, fromTemplate }

/// Drives the full "New Task" entry flow shared by the manager view and the
/// admin branch overview / drill-down: pick blank vs. from-template, then open
/// the (optionally prefilled) task form. [templateBranchFilter] scopes which
/// templates are offered (null = all, for admins); [defaultBranchId] seeds the
/// branch for managers (admins pick it in the form).
Future<void> startNewTaskFlow({
  required BuildContext context,
  required TaskCubit cubit,
  required bool isAdmin,
  required String defaultBranchId,
  String? templateBranchFilter,
}) async {
  final templates = await cubit.templates(branchId: templateBranchFilter);
  if (!context.mounted) return;

  final choice =
      await showNewTaskChooserSheet(context, hasTemplates: templates.isNotEmpty);
  if (!context.mounted || choice == null) return;

  if (choice == NewTaskChoice.blank) {
    await showTaskFormSheet(
      context: context,
      cubit: cubit,
      isAdmin: isAdmin,
      defaultBranchId: defaultBranchId,
    );
    return;
  }

  final template = await showTemplatePickerSheet(
    context: context,
    cubit: cubit,
    branchId: templateBranchFilter,
  );
  if (!context.mounted || template == null) return;
  await showTaskFormSheet(
    context: context,
    cubit: cubit,
    prefill: template,
    isAdmin: isAdmin,
    defaultBranchId: defaultBranchId,
  );
}

/// Step 1 of New Task: a blank task or one started from a saved template (e.g.
/// "Open Shop", "Night Checklist"). Returns the chosen path (or null if
/// dismissed). [hasTemplates] hides the template path when none exist.
///
/// A 2-option chooser is correct as a sheet — it stays one (out of the
/// fullscreen conversion below).
Future<NewTaskChoice?> showNewTaskChooserSheet(
  BuildContext context, {
  required bool hasTemplates,
}) =>
    showSheet<NewTaskChoice>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Create a task'),
          _ChoiceTile(
            icon: Icons.add_task_rounded,
            title: 'Blank task',
            subtitle: 'Start from scratch',
            onTap: () => Navigator.of(context).pop(NewTaskChoice.blank),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChoiceTile(
            // "Saved checklist", not "customize dashboard" — see the Templates
            // icon change (2026-08-01), applied everywhere Templates appears.
            icon: kTemplatesIcon,
            title: 'From a template',
            subtitle: hasTemplates
                ? 'Reuse a saved checklist'
                : 'No templates yet — create one from “Templates”',
            enabled: hasTemplates,
            onTap: () => Navigator.of(context).pop(NewTaskChoice.fromTemplate),
          ),
        ],
      ),
    );

/// Step 2 (when "From a template" is chosen): pick which template to use.
/// Returns the selected template, or null if dismissed. Stays a sheet — a
/// pick-from-a-short-list step, not a destination.
Future<TaskTemplateEntity?> showTemplatePickerSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required String? branchId,
}) =>
    showSheet<TaskTemplateEntity>(
      context,
      _TemplateList(
        future: cubit.templates(branchId: branchId),
        onTap: (t) => Navigator.of(context).pop(t),
        emptyMessage: 'No templates available.',
      ),
    );

/// Manage reusable templates (list · add · delete). A manager's templates are
/// scoped to their branch; an admin's are global (available to every branch).
///
/// **Full-screen, not a modal sheet** (2026-08-01) — the destination behind the
/// app bar's Templates button is a management screen, not a quick pick, and
/// reads as a first-class page: `CupertinoPageRoute(fullscreenDialog: true)`,
/// the same presentation `showTaskFormSheet` already established for the task
/// form (`task_action_sheets.dart`). Same public name and signature as before,
/// so every call site (`admin_task_overview_screen.dart`) is unchanged.
Future<void> showManageTemplatesSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required bool isAdmin,
  required String defaultBranchId,
}) => Navigator.of(context).push<void>(
  CupertinoPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _ManageTemplates(
      cubit: cubit,
      isAdmin: isAdmin,
      defaultBranchId: defaultBranchId,
    ),
  ),
);

/// The single Templates glyph — "saved checklist", not "customize dashboard"
/// (the old `Icons.dashboard_customize_outlined`, which read as a settings
/// screen). One constant so the app bar action, the "From a template" tile,
/// and the template list rows can never drift onto different icons again.
const IconData kTemplatesIcon = Icons.checklist_rounded;

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.cardAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.label),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrollable list of templates with an optional trailing builder (used for
/// the delete button in the manager). [showTitle] renders the sheet-style
/// [SheetTitle] heading; the fullscreen [_ManageTemplates] page carries its own
/// hero instead and passes `false` so "Templates" doesn't appear twice.
class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.future,
    required this.onTap,
    required this.emptyMessage,
    this.trailingBuilder,
    this.showTitle = true,
  });

  final Future<List<TaskTemplateEntity>> future;
  final ValueChanged<TaskTemplateEntity> onTap;
  final String emptyMessage;
  final Widget Function(TaskTemplateEntity)? trailingBuilder;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) const SheetTitle('Templates'),
        FutureBuilder<List<TaskTemplateEntity>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final templates = snap.data ?? const [];
            if (templates.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(emptyMessage, style: AppTypography.bodySmall),
              );
            }
            return ConstrainedBox(
              // Unbounded in the fullscreen page (its own scroll view owns the
              // height); capped in the sheet, which sizes to content instead.
              constraints: showTitle
                  ? const BoxConstraints(maxHeight: 360)
                  : const BoxConstraints(),
              child: ListView.builder(
                shrinkWrap: true,
                physics: showTitle
                    ? null
                    : const NeverScrollableScrollPhysics(),
                itemCount: templates.length,
                itemBuilder: (context, i) {
                  final t = templates[i];
                  final global = (t.branchId ?? '').isEmpty;
                  final count = t.checklistItems.length;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(kTemplatesIcon, color: AppColors.primary),
                    title: Text(t.title, style: AppTypography.label),
                    subtitle: Text(
                      // A human label, not the raw `daily`/`special` wire id
                      // written to `tasks/{taskId}.type` — see `TaskType.label`.
                      '${count == 0 ? 'no steps' : '$count steps'} · '
                      '${t.type.label}${global ? ' · global' : ''}',
                      style: AppTypography.caption,
                    ),
                    trailing: trailingBuilder?.call(t),
                    onTap: () => onTap(t),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ManageTemplates extends StatefulWidget {
  const _ManageTemplates({
    required this.cubit,
    required this.isAdmin,
    required this.defaultBranchId,
  });
  final TaskCubit cubit;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_ManageTemplates> createState() => _ManageTemplatesState();
}

class _ManageTemplatesState extends State<_ManageTemplates> {
  late Future<List<TaskTemplateEntity>> _future = _load();
  bool _busy = false;

  Future<List<TaskTemplateEntity>> _load() => widget.cubit.templates(
      branchId: widget.isAdmin ? null : widget.defaultBranchId);

  /// Block body, deliberately: `setState(() => _future = _load())` returns the
  /// assignment's value — a Future — and `setState` asserts on a closure that
  /// returns one. The assert is stripped in release, so this only ever bit
  /// debug builds (on every template create/delete), which is why it survived.
  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _delete(TaskTemplateEntity t) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.deleteTemplate(t.id);
      _reload();
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not delete the template.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => _TemplateForm(
          cubit: widget.cubit,
          isAdmin: widget.isAdmin,
          defaultBranchId: widget.defaultBranchId,
        ),
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _TemplatesTopBar(onClose: () => Navigator.of(context).pop()),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                  AppSpacing.pagePadding,
                  AppSpacing.xxxl * 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TemplatesHero(),
                    _TemplateList(
                      future: _future,
                      onTap: (_) {},
                      showTitle: false,
                      emptyMessage: widget.isAdmin
                          ? 'No templates yet. Add reusable global checklists '
                              'like “Open Shop” or “Night Checklist”.'
                          : 'No templates for your branch yet. Add reusable '
                              'checklists like “Open Shop” or “Night '
                              'Checklist”.',
                      trailingBuilder: (t) => IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 20),
                        tooltip: 'Delete template',
                        onPressed: _busy ? null : () => _delete(t),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Template',
          style: AppTypography.label.copyWith(color: AppColors.onAccent),
        ),
      ),
    );
  }
}

/// Fixed top bar for the fullscreen Templates page — a Close action and a
/// centred title. Persistent rather than condensing-on-scroll (unlike the
/// longer task form below): this page's content is a short list, not a
/// multi-section workflow, so there's no long hero scroll to collapse.
class _TemplatesTopBar extends StatelessWidget {
  const _TemplatesTopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SizedBox(
        height: 50,
        child: Stack(
          children: [
            Center(child: Text('Templates', style: AppTypography.label)),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Templates page's identity header — mirrors the task form's hero
/// language (glyph tile · eyebrow · title · one-line intent) so the two
/// full-screen surfaces read as one system.
class _TemplatesHero extends StatelessWidget {
  const _TemplatesHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.subtleGradient,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(kTemplatesIcon,
                    size: 19, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'SAVED CHECKLISTS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Checklist Templates', style: AppTypography.displayMedium),
          const SizedBox(height: 6),
          Text(
            'Reusable checklists your team can start a task from.',
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

/// Form to create a new template. Pops `true` once saved so the manager
/// refreshes its list. **Full-screen, not a modal sheet** (2026-08-01) — same
/// presentation as [showTaskFormSheet]. Every behavioural detail below is
/// unchanged from the sheet version: only the container and presentation were
/// elevated (owner-signed ruling from the Create-Task fullscreen conversion).
class _TemplateForm extends StatefulWidget {
  const _TemplateForm({
    required this.cubit,
    required this.isAdmin,
    required this.defaultBranchId,
  });
  final TaskCubit cubit;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

/// Holds the live editing state of one checklist row (its text + required flag).
class _ChecklistRow {
  _ChecklistRow(this.id, {String text = ''})
      : controller = TextEditingController(text: text);
  final String id;
  final TextEditingController controller;
  bool isRequired = true;
}

class _TemplateFormState extends State<_TemplateForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  TaskType _type = TaskType.daily;
  TaskPriority _priority = TaskPriority.normal;
  final List<_ChecklistRow> _items = [];
  int _idSeq = 0;
  bool _saving = false;
  String? _error;

  // ── Presentation-only state (no business logic) ──────────────────
  final ScrollController _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    // Start with a couple of empty steps to invite a checklist.
    _items
      ..add(_ChecklistRow('c${_idSeq++}'))
      ..add(_ChecklistRow('c${_idSeq++}'));
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 12;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  void _addItem() => setState(() => _items.add(_ChecklistRow('c${_idSeq++}')));

  void _removeItem(_ChecklistRow row) {
    setState(() {
      _items.remove(row);
      row.controller.dispose();
    });
  }

  /// Moves an existing row — the same `_ChecklistRow` objects (and their
  /// controllers) are kept, just reordered, so no controller is ever disposed
  /// or recreated here. Keyed list items ([_StepTile]'s `key:`) are what let
  /// Flutter carry each `TextField`'s focus/state across the move.
  ///
  /// `newIndex` arrives already adjusted for the removed item (that's the
  /// contract of `onReorderItem`, the non-deprecated replacement for the
  /// classic `onReorder` — no manual "if newIndex > oldIndex, -1" needed).
  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      final row = _items.removeAt(oldIndex);
      _items.insert(newIndex, row);
    });
  }

  void _toggleRequired(_ChecklistRow row) =>
      setState(() => row.isRequired = !row.isRequired);

  bool get _dirty =>
      _title.text.trim().isNotEmpty ||
      _desc.text.trim().isNotEmpty ||
      _items.any((r) => r.controller.text.trim().isNotEmpty);

  Future<void> _confirmCancel() async {
    FocusScope.of(context).unfocus();
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Discard new template?'),
        content: const Text('Your edits will not be saved.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  // ── Business logic — UNCHANGED from the sheet version ─────────────
  // Elevate presentation only: this method's validation, the `_saving`
  // re-entrancy guard, dropping blank rows, and the `''` global-branchId wire
  // value for an admin are exactly as they were (owner-signed ruling from the
  // Create-Task fullscreen conversion).
  Future<void> _save() async {
    // Clear any stale error from a previous attempt.
    if (_error != null) setState(() => _error = null);

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    final checklist = <ChecklistItemTemplate>[
      for (final row in _items)
        if (row.controller.text.trim().isNotEmpty)
          ChecklistItemTemplate(
            id: row.id,
            title: row.controller.text.trim(),
            isRequired: row.isRequired,
          ),
    ];
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.cubit.saveTemplate(
        title: title,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        type: _type,
        priority: _priority,
        checklistItems: checklist,
        // Admin templates are global ('' = every branch); a manager's are
        // scoped to their own branch.
        branchId: widget.isAdmin ? '' : widget.defaultBranchId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      // Always clear the loading state — even if mounted becomes false while
      // awaiting (e.g. the sheet was dismissed externally).
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filledSteps =
        _items.where((r) => r.controller.text.trim().isNotEmpty).length;

    var step = 0;
    Widget section({
      required String label,
      required IconData icon,
      String? hint,
      required Widget child,
    }) {
      return EntranceFade(
        delay: staggerDelay(step++),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label, icon: icon),
            if (hint != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  hint,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
            child,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      // A pinned top bar (Cancel · condensing title), a scrolling body, and a
      // Save action pinned to the bottom — the full-screen frame a bottom
      // sheet never had. The footer rides above the keyboard automatically
      // (bottomNavigationBar), so a phone's on-screen keyboard never covers it.
      body: Column(
        children: [
          _TemplateFormTopBar(scrolled: _scrolled, onCancel: _confirmCancel),
          Expanded(
            child: CupertinoScrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                  AppSpacing.pagePadding,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EntranceFade(
                      offset: 10,
                      duration: Duration(milliseconds: 420),
                      child: _TemplateFormHero(),
                    ),

                    // ── Template details ──────────────────────────────
                    section(
                      label: 'Template Details',
                      icon: Icons.subject_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _title,
                            label: 'Title',
                            hint: 'e.g. Open Shop',
                            prefixIcon: Icons.title_rounded,
                            autofocus: true,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _desc,
                            label: 'Description (optional)',
                            prefixIcon: Icons.notes_rounded,
                            maxLines: 3,
                            minLines: 1,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // The scope this template will save with — made
                          // visible instead of silently deciding it (§B.4).
                          _ScopeBanner(isAdmin: widget.isAdmin),
                          const SizedBox(height: AppSpacing.lg),
                          _SegmentedField<TaskType>(
                            label: 'Type',
                            icon: Icons.category_outlined,
                            value: _type,
                            options: [
                              for (final t in TaskType.values) (t, t.label),
                            ],
                            onChanged: (v) => setState(() => _type = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SegmentedField<TaskPriority>(
                            label: 'Priority',
                            icon: Icons.flag_outlined,
                            value: _priority,
                            options: [
                              for (final p in TaskPriority.values)
                                (p, p.label),
                            ],
                            onChanged: (v) => setState(() => _priority = v),
                          ),
                        ],
                      ),
                    ),

                    // ── Checklist steps ────────────────────────────────
                    section(
                      label: 'Checklist Steps',
                      icon: kTemplatesIcon,
                      hint: 'Add the steps someone follows to complete this '
                          'work. Drag ⠿ to reorder — order is the procedure.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ReorderableChecklist(
                            items: _items,
                            onReorder: _reorderItems,
                            onToggleRequired: _toggleRequired,
                            onRemove: _removeItem,
                            onTextChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add step'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              // Blank rows are dropped on save — say so out
                              // loud instead of letting them vanish silently
                              // (§B.5).
                              Text(
                                '$filledSteps step${filledSteps == 1 ? '' : 's'} '
                                'will be saved',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ErrorNote(message: _error!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _TemplateStickyBar(
        saving: _saving,
        onSubmit: _save,
      ),
    );
  }
}

// ─── Full-screen chrome (elevates the form into a first-class page) ──────

/// The pinned nav bar: a Cupertino **Cancel**, and a title that condenses in
/// from the hero as the body scrolls — same behaviour as the task form's own
/// top bar, built locally (this file is a separate library from
/// `task_action_sheets.dart`'s private part-file widgets).
class _TemplateFormTopBar extends StatelessWidget {
  const _TemplateFormTopBar({
    required this.scrolled,
    required this.onCancel,
  });

  final bool scrolled;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        border: Border(
          bottom: BorderSide(
            color: scrolled ? AppColors.darkBorder : AppColors.transparent,
          ),
        ),
      ),
      child: SizedBox(
        height: 50,
        child: Stack(
          children: [
            Center(
              child: AnimatedOpacity(
                opacity: scrolled ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text('New Template', style: AppTypography.label),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                onPressed: onCancel,
                child: Text(
                  'Cancel',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero — the page's visual identity, mirroring the task form's language
/// (glyph tile · eyebrow · title · one-line intent) so this reads as a
/// destination, not a converted sheet.
class _TemplateFormHero extends StatelessWidget {
  const _TemplateFormHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.subtleGradient,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(kTemplatesIcon,
                    size: 19, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'CREATE · TEMPLATE',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('New Checklist Template', style: AppTypography.displayMedium),
          const SizedBox(height: 6),
          Text(
            'Build a reusable checklist your team can start a task from.',
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

/// A group divider — a small labelled heading with a trailing hairline. Local
/// twin of the task form's `_SectionLabel` (a different library, so it can't
/// be imported — see the file doc).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider(color: AppColors.darkBorder, height: 1)),
        ],
      ),
    );
  }
}

/// States out loud who this template will be available to — an admin's save
/// silently sends `''` (every branch); a manager's silently sends their own
/// branch id. The wire value doesn't change; this only makes it visible
/// (§B.4).
class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradient,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.public_rounded : Icons.store_mall_directory_outlined,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isAdmin
                  ? 'This template will be available to every branch.'
                  : 'This template will be scoped to your branch.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium monochrome segmented field — the replacement for the raw native
/// `DropdownButton` (`_SimpleDropdown`), which is the "too old" look the
/// owner pointed at. Renders each option's **display label**, never the
/// persisted `value` wire string (§B.1) — callers pass `(T, String)` pairs so
/// this stays a dumb presentation control with no enum knowledge of its own.
class _SegmentedField<T> extends StatelessWidget {
  const _SegmentedField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<(T value, String label)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: AppColors.subtleGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              for (final (v, l) in options)
                Expanded(
                  child: _SegChip(
                    label: l,
                    selected: v == value,
                    onTap: () => onChanged(v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onPrimary : AppColors.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// The checklist steps, in a `ReorderableListView` shrink-wrapped inside the
/// page's outer scroll — a standard, supported nesting (the list owns no
/// scroll physics of its own; the page does). `buildDefaultDragHandles:
/// false` because the default long-press-anywhere handle would fight with
/// tapping into the step's own `TextField`; dragging starts only from the
/// explicit ⠿ handle via [ReorderableDragStartListener].
class _ReorderableChecklist extends StatelessWidget {
  const _ReorderableChecklist({
    required this.items,
    required this.onReorder,
    required this.onToggleRequired,
    required this.onRemove,
    required this.onTextChanged,
  });

  final List<_ChecklistRow> items;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<_ChecklistRow> onToggleRequired;
  final ValueChanged<_ChecklistRow> onRemove;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: onReorder,
      children: [
        for (var i = 0; i < items.length; i++)
          _StepTile(
            key: ValueKey(items[i].id),
            index: i,
            row: items[i],
            onToggleRequired: () => onToggleRequired(items[i]),
            onRemove: () => onRemove(items[i]),
            onTextChanged: onTextChanged,
          ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required super.key,
    required this.index,
    required this.row,
    required this.onToggleRequired,
    required this.onRemove,
    required this.onTextChanged,
  });

  final int index;
  final _ChecklistRow row;
  final VoidCallback onToggleRequired;
  final VoidCallback onRemove;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'Reorder step ${index + 1}',
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13, horizontal: 6),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 18, color: AppColors.textTertiary),
              ),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkBg,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text(
              '${index + 1}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: row.controller,
              onChanged: (_) => onTextChanged(),
              style: AppTypography.body
                  .copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Step description',
                hintStyle:
                    AppTypography.body.copyWith(color: AppColors.textQuaternary),
              ),
            ),
          ),
          _RequiredToggle(required: row.isRequired, onTap: onToggleRequired),
          Semantics(
            button: true,
            label: 'Remove step ${index + 1}',
            child: IconButton(
              tooltip: 'Remove step',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The required/optional control — a legible **labelled** two-state chip,
/// replacing the old unlabelled star icon nobody could read (§B.2). A step is
/// required by default (`_ChecklistRow.isRequired` starts `true`), which is
/// now visible instead of only implied.
class _RequiredToggle extends StatelessWidget {
  const _RequiredToggle({required this.required, required this.onTap});
  final bool required;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = required ? AppColors.primary : AppColors.textTertiary;
    return Semantics(
      button: true,
      label: required
          ? 'Required step. Double tap to make optional.'
          : 'Optional step. Double tap to make required.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: required
                    ? AppColors.primary.withAlpha(28)
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: required
                      ? AppColors.primary.withAlpha(90)
                      : AppColors.darkBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    required
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    required ? 'Required' : 'Optional',
                    style: AppTypography.caption
                        .copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline validation note above the sticky footer.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.error.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Save action, pinned to the bottom — reachable without hunting, exactly
/// like the task form's own sticky footer. Rides above the on-screen keyboard
/// automatically because it's a `bottomNavigationBar`, not inline content.
class _TemplateStickyBar extends StatelessWidget {
  const _TemplateStickyBar({required this.saving, required this.onSubmit});
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.md,
            AppSpacing.pagePadding,
            AppSpacing.md,
          ),
          child: AppButton(
            label: 'Save Template',
            isLoading: saving,
            onPressed: saving ? null : onSubmit,
          ),
        ),
      ),
    );
  }
}
