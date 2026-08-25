import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/app_motion.dart';

/// The **account-surface row vocabulary** — one grouped glass card, rows
/// separated by an inset hairline, each row a 40px medallion + label +
/// supporting line.
///
/// Extracted from `settings_page.dart` unchanged so every account surface draws
/// the *same* row rather than a lookalike. It now lives in `core/widgets/`
/// because Profile shares it with Settings (a feature must not import another
/// feature's widget). Nothing here is new visual language; adding a screen must
/// not fork it.

/// The small uppercase label above a [SettingsGroup].
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    ),
  );
}

/// The card that holds a run of rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppGlassCard(
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );
}

/// A navigating (or inert) settings row.
///
/// [onTap] may be null — an inert row keeps the exact resting appearance and
/// simply does nothing, which is how a "Coming soon" destination is expressed
/// without inventing a second row style.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the chevron (e.g. a version string, a "Coming soon" label).
  final Widget? trailing;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst) const SettingsRowDivider(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: settingsRowRadius(isFirst: isFirst, isLast: isLast),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  SettingsIconMedallion(icon: icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SettingsRowLabel(label: label, subtitle: subtitle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  trailing ??
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textQuaternary,
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A settings row whose trailing control is a platform-native switch.
///
/// [enabled] governs both halves of "disabled": the row dims, and the switch
/// receives a null `onChanged`, which is what makes it non-interactive on both
/// Material and Cupertino. The stored value is still shown — a dependent switch
/// keeps its own setting while its master is off, so turning the master back on
/// restores the user's exact choices.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst) const SettingsRowDivider(),
        // Merged so a screen reader announces "<label>, <subtitle>, switch,
        // on/off" as ONE control rather than three unrelated nodes.
        MergeSemantics(
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                // The whole row toggles, so the target is the full 72pt row and
                // not just the switch.
                onTap: enabled ? () => onChanged(!value) : null,
                borderRadius: settingsRowRadius(
                  isFirst: isFirst,
                  isLast: isLast,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      SettingsIconMedallion(icon: icon),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SettingsRowLabel(
                          label: label,
                          subtitle: subtitle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Fixed box so a Cupertino switch (31pt) and a Material
                      // one (48pt) both leave the row at the same 72pt height
                      // as every navigating settings row.
                      SizedBox(
                        height: 48,
                        child: Center(
                          child: Switch.adaptive(
                            value: value,
                            onChanged: enabled ? onChanged : null,
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The label + supporting line of any settings row.
class SettingsRowLabel extends StatelessWidget {
  const SettingsRowLabel({super.key, required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.labelLarge),
      if ((subtitle ?? '').isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall,
        ),
      ],
    ],
  );
}

/// The inset hairline between two rows of a [SettingsGroup].
class SettingsRowDivider extends StatelessWidget {
  const SettingsRowDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.darkBorder, indent: 68);
}

/// The 40px bordered glyph plate that leads every settings row.
class SettingsIconMedallion extends StatelessWidget {
  const SettingsIconMedallion({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Icon(icon, size: 19, color: AppColors.textSecondary),
  );
}

/// A quiet trailing label for a destination that exists but is not built yet.
/// Monochrome by design — this is not a status, so it never takes a semantic
/// colour (ADR-004).
class SettingsComingSoonLabel extends StatelessWidget {
  const SettingsComingSoonLabel({super.key, this.label = 'Coming soon'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: AppRadius.fullAll,
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    ),
  );
}

/// Respects the system's reduced-motion preference without changing the shared
/// animation primitive for every other feature.
class SettingsReveal extends StatelessWidget {
  const SettingsReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return EntranceFade(delay: staggerDelay(index), child: child);
  }
}

/// Rounds only the corners a row actually owns, so a group reads as one card.
BorderRadius settingsRowRadius({required bool isFirst, required bool isLast}) {
  if (isFirst && isLast) return AppRadius.cardAll;
  if (isFirst) {
    return const BorderRadius.vertical(top: Radius.circular(AppRadius.card));
  }
  if (isLast) {
    return const BorderRadius.vertical(bottom: Radius.circular(AppRadius.card));
  }
  return BorderRadius.zero;
}
