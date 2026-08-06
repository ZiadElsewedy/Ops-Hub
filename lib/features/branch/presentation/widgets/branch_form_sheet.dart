import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/schedule/domain/swap_policy.dart';

/// Create or edit a branch (admin). Editing also offers **branch media** (logo +
/// cover upload) and the **shift-swap rules**, both of which need a saved branch
/// to attach to.
///
/// The sheet is grouped into labelled sections — Details · Attendance · Sales ·
/// Shift swaps · Media — so each branch setting reads as a deliberate choice with
/// plain-language copy, not a wall of toggles.
Future<void> showBranchFormSheet({
  required BuildContext context,
  required BranchCubit cubit,
  BranchEntity? existing,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BranchFormSheet(cubit: cubit, existing: existing),
    );

class _BranchFormSheet extends StatefulWidget {
  const _BranchFormSheet({required this.cubit, required this.existing});
  final BranchCubit cubit;
  final BranchEntity? existing;

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _location =
      TextEditingController(text: widget.existing?.location ?? '');
  String? _error;

  // Live media preview (seeded from the branch; updated after each upload).
  late String? _logoUrl = widget.existing?.logoUrl;
  late String? _coverUrl = widget.existing?.coverUrl;
  bool _busyLogo = false;
  bool _busyCover = false;

  // Branch shift-swap policy (edit-only), seeded from the branch.
  late bool _restrictPositions =
      widget.existing?.swapPolicy?.restrictToSamePosition ?? false;
  late int _minRestHours = widget.existing?.swapPolicy?.minRestHours ?? 0;

  // Branch attendance policy, seeded from the loaded entity for safe form saves.
  late bool _managersCanClock = widget.existing?.managersCanClock ?? true;

  // Whether this branch runs the monthly sales target workflow. Seeded from the
  // loaded entity; a new branch is opted OUT until an admin turns it on.
  late bool _salesTargetEnabled = widget.existing?.salesTargetEnabled ?? false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Branch name is required.');
      return;
    }
    final location = _location.text.trim().isEmpty ? null : _location.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      // Swap rules are configured when editing (they default to permissive).
      widget.cubit.createBranch(
        name: name,
        location: location,
        managersCanClock: _managersCanClock,
        salesTargetEnabled: _salesTargetEnabled,
      );
    } else {
      widget.cubit.editBranch(existing.copyWith(
        name: name,
        location: location,
        swapPolicy: SwapPolicy(
          restrictToSamePosition: _restrictPositions,
          minRestHours: _minRestHours > 0 ? _minRestHours : null,
        ),
        managersCanClock: _managersCanClock,
        salesTargetEnabled: _salesTargetEnabled,
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _pick({required bool isLogo}) async {
    final existing = widget.existing;
    if (existing == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: isLogo ? 600 : 1600,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => isLogo ? _busyLogo = true : _busyCover = true);
    final url = await widget.cubit
        .uploadBranchImage(existing.id, File(picked.path), isLogo: isLogo);
    if (!mounted) return;
    setState(() {
      if (isLogo) {
        _busyLogo = false;
        if (url != null) _logoUrl = url;
      } else {
        _busyCover = false;
        if (url != null) _coverUrl = url;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final isNew = existing == null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A grab handle grounds the sheet as a modal you can flick away.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
            ),
            Text(isNew ? 'New branch' : 'Edit branch', style: AppTypography.h3),
            const SizedBox(height: 2),
            Text(
              isNew
                  ? 'Name the branch and set how it runs. Media and swap rules '
                      'unlock once it’s saved.'
                  : 'Configure how this branch runs — attendance, sales, swaps '
                      'and branding.',
              style: AppTypography.caption,
            ),

            // ── Details ──────────────────────────────────────────────────
            const _SectionHeader(title: 'BRANCH DETAILS'),
            AppTextField(
              controller: _name,
              label: 'Branch name',
              hint: 'e.g. Cairo Festival City',
              prefixIcon: Icons.store_mall_directory_outlined,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _location,
              label: 'Location (optional)',
              prefixIcon: Icons.place_outlined,
            ),

            // ── Attendance ───────────────────────────────────────────────
            const _SectionHeader(
              title: 'ATTENDANCE',
              subtitle: 'How this branch tracks time.',
            ),
            _SettingCard(
              children: [
                _ToggleRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Managers clock in / out',
                  subtitle: _managersCanClock
                      ? 'Managers keep an open shift here — they clock in and out '
                          'at any time, with no set hours.'
                      : 'Managers don’t clock here. They still review and '
                          'approve the team’s attendance.',
                  value: _managersCanClock,
                  onChanged: (v) => setState(() => _managersCanClock = v),
                ),
              ],
            ),

            // ── Sales ────────────────────────────────────────────────────
            const _SectionHeader(
              title: 'SALES',
              subtitle: 'Optional monthly sales target for this branch.',
            ),
            _SettingCard(
              children: [
                _ToggleRow(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Monthly sales target',
                  subtitle: _salesTargetEnabled
                      ? 'Employees submit a daily close and the manager approves '
                          'it against this branch’s monthly target.'
                      : 'Off — no target, no daily submissions, and no sales '
                          'screens for this branch.',
                  value: _salesTargetEnabled,
                  onChanged: (v) => setState(() => _salesTargetEnabled = v),
                ),
              ],
            ),

            // ── Shift swaps (edit-only — needs a saved branch) ────────────
            if (isNew) ...[
              const _SectionHeader(title: 'SHIFT SWAPS & MEDIA'),
              const _LockedHint(
                message:
                    'Save the branch first, then reopen it to set swap rules and '
                    'add a logo & cover.',
              ),
            ] else ...[
              const _SectionHeader(
                title: 'SHIFT SWAPS',
                subtitle:
                    'Rules checked when employees swap shifts with each other. '
                    'Both are off by default — anyone on the opposite shift '
                    'can swap.',
              ),
              _SettingCard(
                children: [
                  _ToggleRow(
                    icon: Icons.badge_outlined,
                    title: 'Same role only',
                    subtitle:
                        'Only allow a swap between people with the same job title '
                        '— a barista can swap with a barista, but not with a '
                        'cashier.',
                    value: _restrictPositions,
                    onChanged: (v) => setState(() => _restrictPositions = v),
                  ),
                  const _RowDivider(),
                  _StepperRow(
                    icon: Icons.bedtime_outlined,
                    title: 'Minimum rest',
                    subtitle:
                        'Reject a swap that would leave less than this many hours '
                        'between someone’s two shifts — stops a late '
                        'close followed by an early open.',
                    value: _minRestHours,
                    min: 0,
                    max: 16,
                    format: (v) => v == 0 ? 'Off' : '${v}h',
                    onChanged: (v) => setState(() => _minRestHours = v),
                  ),
                ],
              ),

              // ── Branch media ────────────────────────────────────────────
              const _SectionHeader(
                title: 'BRANCH MEDIA',
                subtitle: 'Logo and cover shown across the app.',
              ),
              _SettingCard(
                children: [
                  _LogoRow(
                    logoUrl: _logoUrl,
                    name: _name.text,
                    busy: _busyLogo,
                    onPick: () => _pick(isLogo: true),
                  ),
                  const _RowDivider(),
                  _CoverField(
                    coverUrl: _coverUrl,
                    busy: _busyCover,
                    onPick: () => _pick(isLogo: false),
                  ),
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: AppTypography.caption.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: isNew ? 'Create branch' : 'Save changes',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// A section eyebrow with an optional one-line explainer beneath it. One shared
/// rhythm across every group in the sheet.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// A grouped settings card — a single bordered surface holding one or more rows.
class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: AppSpacing.lg, color: AppColors.darkBorder);
}

/// A labelled toggle row: leading glyph · title + subtitle · switch.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _RuleLabel(title: title, subtitle: subtitle, icon: icon)),
        const SizedBox(width: AppSpacing.sm),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }
}

/// A labelled stepper row: leading glyph · title + subtitle · +/- stepper.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final String Function(int) format;
  final ValueChanged<int> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _RuleLabel(title: title, subtitle: subtitle, icon: icon)),
        const SizedBox(width: AppSpacing.sm),
        _Stepper(
          value: value,
          min: min,
          max: max,
          format: format,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RuleLabel extends StatelessWidget {
  const _RuleLabel({required this.title, required this.subtitle, this.icon});
  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTypography.caption),
      ],
    );
    if (icon == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: AppSpacing.md),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
        Expanded(child: text),
      ],
    );
  }
}

/// A short inline note explaining why a section is locked until the branch saves.
class _LockedHint extends StatelessWidget {
  const _LockedHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.caption)),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 40),
          alignment: Alignment.center,
          child: Text(format(value),
              style: AppTypography.label.copyWith(fontWeight: FontWeight.w700)),
        ),
        _StepBtn(
          icon: Icons.add_rounded,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
      ),
    );
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow({
    required this.logoUrl,
    required this.name,
    required this.busy,
    required this.onPick,
  });

  final String? logoUrl;
  final String name;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BranchAvatar(logoUrl: logoUrl, name: name, size: 56),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logo', style: AppTypography.label),
              SizedBox(height: 2),
              Text('Square mark shown across the app',
                  style: AppTypography.caption),
            ],
          ),
        ),
        busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2))
            : PremiumButton(
                label: (logoUrl ?? '').isEmpty ? 'Add' : 'Change',
                icon: Icons.image_outlined,
                onPressed: onPick,
              ),
      ],
    );
  }
}

class _CoverField extends StatelessWidget {
  const _CoverField({
    required this.coverUrl,
    required this.busy,
    required this.onPick,
  });

  final String? coverUrl;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasCover = (coverUrl ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.cardAll,
          child: Container(
            height: 120,
            width: double.infinity,
            color: AppColors.darkSurfaceElevated,
            child: busy
                ? const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2)))
                : hasCover
                    ? Image.network(coverUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 1200,
                        errorBuilder: (_, _, _) => _placeholder())
                    : _placeholder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumButton(
          label: hasCover ? 'Change cover' : 'Add cover',
          icon: Icons.photo_size_select_actual_outlined,
          onPressed: busy ? null : onPick,
        ),
      ],
    );
  }

  Widget _placeholder() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.textTertiary, size: 24),
            SizedBox(height: 4),
            Text('No cover yet', style: AppTypography.caption),
          ],
        ),
      );
}
