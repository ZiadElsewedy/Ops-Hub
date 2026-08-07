import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/settings_tiles.dart';

/// One fact about the signed-in user, inside a [SettingsGroup].
///
/// It is the *value* the user came to read, so the value takes the bright step
/// of the ramp and its caption sits above it in tertiary — the inverse of
/// [SettingsRowLabel], which leads with a destination name. Everything else
/// (medallion, hairline, corner rounding, 16pt gutters) is the shared account
/// row vocabulary, not a fork of it.
///
/// A row does exactly one thing when tapped:
/// * has a value and [copyable] — copies it and says so;
/// * has no value and [onAdd] — opens Edit Profile to fill it in;
/// * otherwise it is inert and looks it (no chevron, no ink).
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.onAdd,
    this.leading,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;

  /// The fact. Empty / null renders the *Not set* affordance.
  final String? value;

  /// Offer tap-to-copy. Only honoured when there is a value — copying an empty
  /// string is the kind of "it did nothing" tap this screen is removing.
  final bool copyable;

  /// Where an unset value is filled in. Null ⇒ the blank row is inert (an admin
  /// cannot self-edit the contact block, so it must not be offered the door).
  final VoidCallback? onAdd;

  /// Replaces the glyph medallion (e.g. a branch logo).
  final Widget? leading;

  final bool isFirst;
  final bool isLast;

  bool get _hasValue => (value ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    final canCopy = copyable && _hasValue;
    final canAdd = !_hasValue && onAdd != null;

    void handleTap() {
      if (canCopy) {
        Clipboard.setData(ClipboardData(text: text));
        AppSnackbar.success(context, '$label copied');
      } else if (canAdd) {
        onAdd!();
      }
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          leading ?? SettingsIconMedallion(icon: icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _hasValue ? text : 'Not set',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _hasValue
                      ? AppTypography.label
                      : AppTypography.label.copyWith(
                          color: AppColors.textQuaternary,
                        ),
                ),
              ],
            ),
          ),
          if (canCopy || canAdd) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              canCopy ? Icons.copy_rounded : Icons.add_rounded,
              size: 17,
              color: AppColors.textQuaternary,
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (!isFirst) const SettingsRowDivider(),
        // Merged so a screen reader announces "Email, ziad@drop.test, button"
        // rather than the caption and the value as two unrelated nodes.
        MergeSemantics(
          child: Semantics(
            button: canCopy || canAdd,
            label: canCopy
                ? '$label $text. Double tap to copy.'
                : canAdd
                ? '$label not set. Double tap to add it.'
                : '$label ${_hasValue ? text : "not set"}',
            excludeSemantics: true,
            child: canCopy || canAdd
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: handleTap,
                      borderRadius: settingsRowRadius(
                        isFirst: isFirst,
                        isLast: isLast,
                      ),
                      child: row,
                    ),
                  )
                : row,
          ),
        ),
      ],
    );
  }
}
