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

/// Create or edit a branch (admin). Editing also offers **branch media** —
/// logo + cover upload to Storage (§8).
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'New Branch' : 'Edit Branch',
                style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
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

            const SizedBox(height: AppSpacing.xl),
            Text('ATTENDANCE',
                style: AppTypography.caption.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                )),
            const SizedBox(height: AppSpacing.md),
            _ManagersClockSection(
              managersCanClock: _managersCanClock,
              onChanged: (value) => setState(() => _managersCanClock = value),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text('SALES',
                style: AppTypography.caption.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                )),
            const SizedBox(height: AppSpacing.md),
            _SalesTargetSection(
              enabled: _salesTargetEnabled,
              onChanged: (value) => setState(() => _salesTargetEnabled = value),
            ),

            // ── Branch media (editing only — needs an existing branch id) ──
            const SizedBox(height: AppSpacing.xl),
            Text('BRANCH MEDIA',
                style: AppTypography.caption.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                )),
            const SizedBox(height: AppSpacing.md),
            if (existing == null)
              const Text('Save the branch first, then reopen it to add a logo & cover.',
                  style: AppTypography.caption)
            else ...[
              _LogoRow(
                logoUrl: _logoUrl,
                name: _name.text,
                busy: _busyLogo,
                onPick: () => _pick(isLogo: true),
              ),
              const SizedBox(height: AppSpacing.md),
              _CoverField(
                coverUrl: _coverUrl,
                busy: _busyCover,
                onPick: () => _pick(isLogo: false),
              ),

              // ── Shift-swap rules (edit-only) ──
              const SizedBox(height: AppSpacing.xl),
              Text('SHIFT-SWAP RULES',
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  )),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                  'Optional limits applied when employees swap shifts. Off by '
                  'default — any coworker on the opposite shift can swap.',
                  style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              _SwapRulesSection(
                restrictPositions: _restrictPositions,
                minRestHours: _minRestHours,
                onRestrictChanged: (v) =>
                    setState(() => _restrictPositions = v),
                onRestChanged: (v) => setState(() => _minRestHours = v),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: AppTypography.caption.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: existing == null ? 'Create Branch' : 'Save Changes',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opts a branch in or out of the monthly sales target workflow. Off is the
/// default: a branch that does not run targets shows no sales surface at all.
class _SalesTargetSection extends StatelessWidget {
  const _SalesTargetSection({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RuleLabel(
              title: 'Monthly sales target',
              subtitle: enabled
                  ? 'Employees submit a daily close and the manager approves it '
                      'against this branch\u2019s monthly target.'
                  : 'Off \u2014 this branch has no sales target, no daily '
                      'submissions, and no sales screens.',
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ManagersClockSection extends StatelessWidget {
  const _ManagersClockSection({
    required this.managersCanClock,
    required this.onChanged,
  });

  final bool managersCanClock;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RuleLabel(
              title: 'Managers can clock in / out',
              subtitle: managersCanClock
                  ? 'Managers can clock their own attendance.'
                  : 'Managers keep attendance review and approval — they just '
                      'have no clock of their own.',
            ),
          ),
          Switch(
            value: managersCanClock,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// The branch swap-policy editor: a same-position toggle + a min-rest stepper
/// (0 = off). Monochrome, premium.
class _SwapRulesSection extends StatelessWidget {
  const _SwapRulesSection({
    required this.restrictPositions,
    required this.minRestHours,
    required this.onRestrictChanged,
    required this.onRestChanged,
  });

  final bool restrictPositions;
  final int minRestHours;
  final ValueChanged<bool> onRestrictChanged;
  final ValueChanged<int> onRestChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: _RuleLabel(
                  title: 'Same role only',
                  subtitle: 'Block swaps between different job positions',
                ),
              ),
              Switch(
                value: restrictPositions,
                onChanged: onRestrictChanged,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.darkBorder),
          Row(
            children: [
              const Expanded(
                child: _RuleLabel(
                  title: 'Minimum rest',
                  subtitle: 'Hours required between shifts after a swap',
                ),
              ),
              _Stepper(
                value: minRestHours,
                min: 0,
                max: 16,
                format: (v) => v == 0 ? 'Off' : '${v}h',
                onChanged: onRestChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleLabel extends StatelessWidget {
  const _RuleLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTypography.caption),
      ],
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
