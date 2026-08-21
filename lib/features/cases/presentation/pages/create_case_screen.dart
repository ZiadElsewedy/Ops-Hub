import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/cases/presentation/case_format.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_picker.dart';

/// The ≤30-second case-opening flow: Category → Subject → Description → Urgent? →
/// Send to (smart-routed default, editable) → Privacy → Attachments → Open.
/// Strictly monochrome; minimal friction for non-technical retail staff.
class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _subjectC = TextEditingController();
  final _descC = TextEditingController();

  CaseCategory _category = CaseCategory.operations;
  CaseRecipient _recipient = CaseCategory.operations.defaultRecipient;
  CasePrivacy _privacy = CaseCategory.operations.defaultPrivacy;
  bool _urgent = false;
  List<PickedAttachment> _attachments = const [];
  bool _recipientTouched = false;
  bool _privacyTouched = false;
  bool _recipientLocked = false; // manager: escalation always goes to admin
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.currentUser;
    final role = user?.role;
    // A manager who opens a case is escalating UP — it always goes to the admin.
    // Locked, not chosen. Employees keep the full manager / admin / both choice.
    if (role != null && role.isManager) {
      _recipient = CaseRecipient.admin;
      _recipientLocked = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Admins receive cases; they don't open them — bounce them back.
      if (role != null && role.isAdmin) {
        context.showError("Admins receive cases — they don't open them.");
        context.pop();
        return;
      }
      if (user != null) context.read<CaseListCubit>().load(user);
    });
  }

  @override
  void dispose() {
    _subjectC.dispose();
    _descC.dispose();
    super.dispose();
  }

  void _onCategory(CaseCategory c) {
    setState(() {
      _category = c;
      // Smart routing/privacy: adopt the category's defaults until the user
      // overrides them. A manager's recipient stays locked to admin.
      if (!_recipientTouched && !_recipientLocked) {
        _recipient = c.defaultRecipient;
      }
      if (!_privacyTouched) _privacy = c.defaultPrivacy;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final subject = _subjectC.text.trim();
    if (subject.isEmpty) {
      context.showError('Add a short subject so the case is easy to scan.');
      return;
    }
    setState(() => _submitting = true);
    final created = await context.read<CaseListCubit>().openCase(
          subject: subject,
          description: _descC.text.trim().isEmpty ? null : _descC.text.trim(),
          category: _category,
          recipient: _recipient,
          privacy: _privacy,
          urgent: _urgent,
          attachments: _attachments,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created != null) {
      // Select it so the desktop split-pane opens straight into the new case.
      context.read<CaseListCubit>().select(created.id);
      context.showSuccess('Case opened');
      context.pop();
    } else {
      context.showError('Could not open the case. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'New Case',
      subtitle: 'Start a private conversation about an issue',
      contentMaxWidth: 620,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md,
            AppSpacing.pagePadding, AppSpacing.huge),
        children: [
          const _SectionLabel('Category'),
          _CategoryPicker(selected: _category, onSelect: _onCategory),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _subjectC,
            label: 'Subject',
            hint: 'A short summary',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _descC,
            label: 'Description',
            hint: 'What happened? Add any detail that helps.',
            maxLines: 5,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: AppSpacing.xl),
          _UrgentToggle(
            value: _urgent,
            onChanged: (v) => setState(() => _urgent = v),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Send to'),
          if (_recipientLocked)
            const _EscalationNote()
          else
            _EnumChips<CaseRecipient>(
              values: CaseRecipient.values,
              selected: _recipient,
              labelOf: (r) => r.label,
              onSelect: (r) => setState(() {
                _recipient = r;
                _recipientTouched = true;
              }),
            ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Privacy'),
          _EnumChips<CasePrivacy>(
            values: CasePrivacy.values,
            selected: _privacy,
            labelOf: (p) => p.label,
            onSelect: (p) => setState(() {
              _privacy = p;
              _privacyTouched = true;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_privacy.hint, style: AppTypography.caption),
          ),
          const SizedBox(height: AppSpacing.xl),
          AttachmentPickerField(
            attachments: _attachments,
            onChanged: (v) => setState(() => _attachments = v),
            title: 'Attachments',
            hint: 'Add photos or a short video (optional)',
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Open Case',
            onPressed: _submitting ? null : _submit,
            isLoading: _submitting,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(text,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
      );
}

/// A single optional escalation signal — the lean replacement for a 4-level
/// severity. Off by default; on for incident-type issues (theft, cash mismatch,
/// outage). Urgent cases sort above normal ones and carry an urgent badge.
class _UrgentToggle extends StatelessWidget {
  const _UrgentToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? AppColors.error.withAlpha(24) : AppColors.darkSurfaceElevated,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
                color: value ? AppColors.error.withAlpha(130) : AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.priority_high_rounded,
                  size: 18,
                  color: value ? AppColors.error : AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mark as Urgent',
                        style: AppTypography.label
                            .copyWith(fontWeight: FontWeight.w600)),
                    const Text('For incidents that need immediate attention',
                        style: AppTypography.caption),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the recipient chips when a **manager** opens a case — the
/// recipient is fixed (a manager escalates UP to the admin).
class _EscalationNote extends StatelessWidget {
  const _EscalationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_upward_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Escalated to the Admin',
                style:
                    AppTypography.label.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onSelect});
  final CaseCategory selected;
  final ValueChanged<CaseCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final c in CaseCategory.values)
          _CategoryChip(
            category: c,
            selected: c == selected,
            onTap: () => onSelect(c),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final CaseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.darkSurfaceElevated,
      borderRadius: AppRadius.fullAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.fullAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: AppRadius.fullAll,
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(caseCategoryIcon(category),
                  size: 15,
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(
                category.label,
                style: AppTypography.label.copyWith(
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
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

/// A generic single-select chip row for a small enum (recipient / privacy).
class _EnumChips<T> extends StatelessWidget {
  const _EnumChips({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [for (final v in values) _pill(context, v)],
    );
  }

  Widget _pill(BuildContext context, T v) {
    final isSel = v == selected;
    return Material(
      color: isSel ? AppColors.primary : AppColors.darkSurfaceElevated,
      borderRadius: AppRadius.fullAll,
      child: InkWell(
        onTap: () => onSelect(v),
        borderRadius: AppRadius.fullAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.fullAll,
            border: Border.all(
                color: isSel ? AppColors.primary : AppColors.darkBorder),
          ),
          child: Text(
            labelOf(v),
            style: AppTypography.label.copyWith(
                color: isSel ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
