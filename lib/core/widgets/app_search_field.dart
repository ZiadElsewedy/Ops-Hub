import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// A clean, monochrome search field used across the app.
///
/// Built as a single rounded surface that fully **neutralises** the global
/// [InputDecorationTheme] (no inherited fill, border, or 18px padding) so it
/// renders as ONE crisp box — not a field-inside-a-field. The border and leading
/// magnifier brighten on focus, and a circular clear button appears when there's
/// text. Black / white / grey only.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.height = 52,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  /// Optional caller-owned focus node. This lets compact header search fields
  /// participate in the same focus flow as their surrounding page chrome.
  final FocusNode? focusNode;
  final bool autofocus;

  /// Defaults to the established full-width field height; compact desktop
  /// headers can opt into a native-feeling 40px control without reimplementing
  /// the shared search treatment.
  final double height;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final bool _ownsFocusNode = widget.focusNode == null;
  late final FocusNode _focusNode = (widget.focusNode ?? FocusNode())
    ..addListener(_onFocusChange);
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    // Track the controller, not just keystrokes. A caller-owned controller can
    // be cleared from outside the field — an empty-state "Clear search" action,
    // a reset button — and keying the clear glyph off `onChanged` alone left it
    // sitting over an already-empty field until the next keypress.
    _controller.addListener(_syncHasText);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncHasText);
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _syncHasText() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText && mounted) setState(() => _hasText = has);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _onChanged(String v) {
    _syncHasText();
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _focused ? AppColors.textSecondary : AppColors.textTertiary;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: _focused ? AppColors.textSecondary : AppColors.darkBorder,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.textPrimary,
              cursorWidth: 1.5,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              // Fully neutralise the global InputDecorationTheme so the field
              // doesn't draw its own fill/border/padding inside this surface.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          if (_hasText) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: () {
                  _controller.clear();
                  _onChanged('');
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkSurfaceElevated,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
