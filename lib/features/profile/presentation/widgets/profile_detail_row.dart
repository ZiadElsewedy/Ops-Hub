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
/// **A detail the user owns is edited by tapping it**, set or not — that is the
/// whole point of a profile, and the row says so with a pencil. Copying is its
/// own trailing button rather than the row's tap, so a value can be both read
/// out and corrected without the two gestures competing.
///
/// [onEdit] is null for anything the user does not own — their email, the
/// branch an admin assigned them, when they joined — and such a row is inert
/// apart from an optional copy.
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.onEdit,
    this.leading,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;

  /// The fact. Empty / null renders the *Not set* affordance.
  final String? value;

  /// Offer a copy button. Only honoured when there is a value — copying an
  /// empty string is the kind of "it did nothing" tap this screen removes.
  final bool copyable;

  /// Opens the form that owns this field. Null ⇒ the user cannot change it
  /// here, and the row must not pretend otherwise (an admin cannot self-edit
  /// contact details, so their rows are read-only).
  final VoidCallback? onEdit;

  /// Replaces the glyph medallion (e.g. a branch logo).
  final Widget? leading;

  final bool isFirst;
  final bool isLast;

  bool get _hasValue => (value ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    final canCopy = copyable && _hasValue;
    final editable = onEdit != null;

    final row = Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
        // The copy button carries its own 44pt target, so the row's own right
        // gutter closes up behind it.
        right: AppSpacing.sm,
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
          if (canCopy)
            _CopyButton(label: label, value: text)
          else
            SizedBox(
              width: 44,
              child: editable
                  ? const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textQuaternary,
                    )
                  : null,
            ),
        ],
      ),
    );

    return Column(
      children: [
        if (!isFirst) const SettingsRowDivider(),
        // Merged so a screen reader announces "Phone, 1212122443, button"
        // rather than the caption and the value as two unrelated nodes. The
        // copy button keeps its own node — it is a separate action.
        MergeSemantics(
          child: Semantics(
            button: editable,
            label: editable
                ? '$label ${_hasValue ? text : "not set"}. Double tap to edit.'
                : '$label ${_hasValue ? text : "not set"}',
            child: editable
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
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

/// Copy-to-clipboard for one value. Its own 44pt control rather than the row's
/// tap, so editing and copying never contend for the same gesture.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () {
      Clipboard.setData(ClipboardData(text: value));
      AppSnackbar.success(context, '$label copied');
    },
    icon: const Icon(Icons.copy_rounded, size: 17),
    color: AppColors.textQuaternary,
    iconSize: 17,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    splashRadius: 20,
    tooltip: 'Copy $label',
  );
}
