import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/domain/work_types/work_type_registry.dart';
import 'package:opshub/features/task/presentation/work_type_presenter.dart';

/// The **work-type selector** — the defining choice of the whole workflow. For a
/// small catalogue (≤ [_inlineThreshold]) it renders inline selectable cards, so
/// the first and most important decision needs no bottom sheet; a larger future
/// catalogue automatically falls back to the searchable chooser sheet. Locked to
/// a static summary card in edit mode — a task's fundamental kind never changes
/// mid-life (same stance as the assignment-type selector).
class WorkTypePicker extends StatelessWidget {
  const WorkTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Above this many types the inline cards would crowd the page, so the picker
  /// falls back to the searchable chooser sheet. Small sets (the current 5)
  /// render inline — no "page → bottom sheet" for the first decision.
  static const int _inlineThreshold = 6;

  @override
  Widget build(BuildContext context) {
    final registry = WorkTypeRegistry.instance;
    final selected = registry.byId(value);

    // Edit mode: a task's kind is fixed — show the locked summary card.
    if (!enabled) {
      return _WorkTypeCard(definition: selected, enabled: false, onTap: null);
    }

    // Large future catalogue → keep the searchable sheet (architecture intact).
    final all = registry.all;
    if (all.length > _inlineThreshold) {
      return _WorkTypeCard(
        definition: selected,
        enabled: true,
        onTap: () => _open(context),
      );
    }

    // Small set → inline selectable cards, no sheet.
    return _WorkTypeInlineCards(
      definitions: all,
      value: value,
      onChanged: onChanged,
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WorkTypeSheet(current: value),
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}

/// Inline, always-visible work-type selection — a compact grid of selectable
/// cards, so the first and most important decision needs no bottom sheet. The
/// chosen type's blurb sits beneath as live context. Used for small catalogues
/// (see [WorkTypePicker._inlineThreshold]).
class _WorkTypeInlineCards extends StatelessWidget {
  const _WorkTypeInlineCards({
    required this.definitions,
    required this.value,
    required this.onChanged,
  });

  final List<WorkTypeDefinition> definitions;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = definitions.firstWhere(
      (d) => d.id == value,
      orElse: () => definitions.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in definitions)
              _WorkTypeChip(
                definition: d,
                selected: d.id == value,
                onTap: () => onChanged(d.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // The selected type's blurb — live context, kept out of each chip so the
        // grid stays compact.
        Text(
          selected.blurb,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// One selectable work-type card in [_WorkTypeInlineCards]. Comfortably above
/// the 44px minimum tap target; announces its selected state to assistive tech.
class _WorkTypeChip extends StatelessWidget {
  const _WorkTypeChip({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final WorkTypeDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: selected,
      label: definition.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.darkSurfaceElevated
                : AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: selected ? AppColors.accentBorder : AppColors.darkBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                WorkTypePresenter.iconFor(definition.id),
                size: 18,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                definition.label,
                style: AppTypography.label.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tappable hero summarising the selected work type. Shows a labelled kind +
/// blurb behind a soft icon tile; the trailing glyph is a chooser affordance
/// when [enabled] and a lock when it isn't (edit mode).
class _WorkTypeCard extends StatelessWidget {
  const _WorkTypeCard({
    required this.definition,
    required this.enabled,
    required this.onTap,
  });

  final WorkTypeDefinition definition;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xlAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            _WorkTypeIcon(icon: WorkTypePresenter.iconFor(definition.id)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WORK TYPE',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(definition.label, style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(
                    definition.blurb,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              enabled ? Icons.unfold_more_rounded : Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The soft rounded icon tile used by the work-type card and chooser rows.
class _WorkTypeIcon extends StatelessWidget {
  const _WorkTypeIcon({required this.icon, this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.darkBorder,
        ),
      ),
      child: Icon(
        icon,
        size: 21,
        color: selected ? AppColors.onPrimary : AppColors.textSecondary,
      ),
    );
  }
}

/// The rich work-type chooser — one tap reveals every registered kind with its
/// icon, name and one-line blurb, so the operator picks by *meaning*, not by a
/// bare label in a dropdown. Returns the chosen id (or null if dismissed).
class _WorkTypeSheet extends StatelessWidget {
  const _WorkTypeSheet({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final defs = WorkTypeRegistry.instance.all;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetGrip(),
          const SizedBox(height: AppSpacing.md),
          const Text('Work type', style: AppTypography.h3),
          const SizedBox(height: 2),
          const Text(
            'What kind of work is this?',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: defs.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final def = defs[i];
                return _WorkTypeRow(
                  definition: def,
                  selected: def.id == current,
                  onTap: () => Navigator.of(context).pop(def.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTypeRow extends StatelessWidget {
  const _WorkTypeRow({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final WorkTypeDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
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
            _WorkTypeIcon(
              icon: WorkTypePresenter.iconFor(definition.id),
              selected: selected,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.label,
                    style: AppTypography.label.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.blurb,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

/// Small drag grip for this file's chooser sheet (mirrors the shared
/// `SheetHandle` without importing the form-sheet module).
class _SheetGrip extends StatelessWidget {
  const _SheetGrip();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.darkBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the dynamic fields a [WorkTypeDefinition] declares, driven purely by
/// its [WorkFieldSpec]s — the create screen never hardcodes a type's inputs.
/// Owns its own controllers (rebuilt when the type changes) and reports the full
/// value map up via [onChanged]. `errors` (keyed by field key) highlights
/// setup-validation failures inline.
class DynamicWorkForm extends StatefulWidget {
  const DynamicWorkForm({
    super.key,
    required this.definition,
    required this.onChanged,
    this.fields,
    this.initialData = const {},
    this.errors = const {},
  });

  final WorkTypeDefinition definition;

  /// The exact fields to render — defaults to the type's setup fields on the
  /// create form; the details screen passes [WorkTypeDefinition.completionFields].
  final List<WorkFieldSpec>? fields;

  final Map<String, dynamic> initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Map<String, String> errors;

  List<WorkFieldSpec> get resolvedFields => fields ?? definition.setupFields;

  @override
  State<DynamicWorkForm> createState() => _DynamicWorkFormState();
}

class _DynamicWorkFormState extends State<DynamicWorkForm> {
  late Map<String, dynamic> _data;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(covariant DynamicWorkForm old) {
    super.didUpdateWidget(old);
    // A new work type = a new field set. Rebuild controllers from the (reset)
    // initialData the parent hands down.
    if (old.definition.id != widget.definition.id) {
      _disposeControllers();
      _seed();
    }
  }

  void _seed() {
    _data = {...widget.initialData};
    for (final f in widget.resolvedFields) {
      if (_usesController(f.kind)) {
        _controllers[f.key] = TextEditingController(
          text: _display(_data[f.key]),
        );
      }
    }
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  bool _usesController(WorkFieldKind kind) =>
      kind == WorkFieldKind.text ||
      kind == WorkFieldKind.multiline ||
      kind == WorkFieldKind.number ||
      kind == WorkFieldKind.integer ||
      kind == WorkFieldKind.currency;

  static String _display(dynamic v) => v == null ? '' : '$v';

  void _set(String key, dynamic value) {
    setState(() {
      if (value == null) {
        _data.remove(key);
      } else {
        _data[key] = value;
      }
    });
    widget.onChanged(Map<String, dynamic>.of(_data));
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.resolvedFields;
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _field(f),
          ),
      ],
    );
  }

  Widget _field(WorkFieldSpec f) {
    final control = switch (f.kind) {
      WorkFieldKind.text || WorkFieldKind.multiline => _textField(f),
      WorkFieldKind.number ||
      WorkFieldKind.integer ||
      WorkFieldKind.currency => _numberField(f),
      WorkFieldKind.date => _dateField(f),
      WorkFieldKind.time => _timeField(f),
      WorkFieldKind.toggle => _toggleField(f),
      WorkFieldKind.select => _selectField(f),
    };
    final err = widget.errors[f.key];
    if (err == null) return control;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        control,
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(
            err,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  String _label(WorkFieldSpec f) =>
      f.required ? f.label : '${f.label} (optional)';

  Widget _textField(WorkFieldSpec f) {
    final multiline = f.kind == WorkFieldKind.multiline;
    return AppTextField(
      controller: _controllers[f.key]!,
      label: _label(f),
      hint: f.hint,
      prefixIcon: WorkTypePresenter.iconForField(f.kind),
      maxLines: multiline ? 4 : 1,
      minLines: multiline ? 2 : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      onChanged: (s) => _set(f.key, s.isEmpty ? null : s),
    );
  }

  Widget _numberField(WorkFieldSpec f) {
    final isInteger = f.kind == WorkFieldKind.integer;
    return AppTextField(
      controller: _controllers[f.key]!,
      label: _label(f),
      hint: f.hint,
      prefixIcon: WorkTypePresenter.iconForField(f.kind),
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      inputFormatters: [
        if (isInteger)
          FilteringTextInputFormatter.digitsOnly
        else
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: (s) {
        final num? v = isInteger ? int.tryParse(s) : num.tryParse(s);
        _set(f.key, v);
      },
    );
  }

  Widget _dateField(WorkFieldSpec f) {
    final value = _data[f.key];
    final dt = value is DateTime ? value : null;
    return _pickerBox(
      icon: WorkTypePresenter.iconForField(f.kind),
      text: dt == null ? _label(f) : '${f.label}: ${_dateLabel(dt)}',
      placeholder: dt == null,
      onClear: dt == null ? null : () => _set(f.key, null),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: dt ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
        );
        if (picked != null) _set(f.key, picked);
      },
    );
  }

  Widget _timeField(WorkFieldSpec f) {
    final value = _data[f.key];
    final dt = value is DateTime ? value : null;
    return _pickerBox(
      icon: WorkTypePresenter.iconForField(f.kind),
      text: dt == null ? _label(f) : '${f.label}: ${_timeLabel(dt)}',
      placeholder: dt == null,
      onClear: dt == null ? null : () => _set(f.key, null),
      onTap: () async {
        final now = TimeOfDay.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: dt == null ? now : TimeOfDay.fromDateTime(dt),
        );
        if (picked != null) {
          final d = DateTime.now();
          _set(
            f.key,
            DateTime(d.year, d.month, d.day, picked.hour, picked.minute),
          );
        }
      },
    );
  }

  Widget _toggleField(WorkFieldSpec f) {
    final on = _data[f.key] == true;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(
            WorkTypePresenter.iconForField(f.kind),
            size: 20,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(f.label, style: AppTypography.body)),
          Switch(
            value: on,
            onChanged: (v) => _set(f.key, v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _selectField(WorkFieldSpec f) {
    final selected = _data[f.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label(f), style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final opt in f.options)
              _TypeChip(
                icon: Icons.check_rounded,
                label: opt.label,
                selected: selected == opt.value,
                onTap: () =>
                    _set(f.key, selected == opt.value ? null : opt.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pickerBox({
    required IconData icon,
    required String text,
    required bool placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body.copyWith(
                  color: placeholder
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _timeLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
