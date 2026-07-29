import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_typography.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;

  /// Live input filters (e.g. restrict a phone field to digits and `+ - ( )`),
  /// so disallowed characters can't be typed at all.
  final List<TextInputFormatter>? inputFormatters;

  /// Multi-line support (default single line). Set [maxLines] > 1 (and optionally
  /// [minLines]) for a textarea-style field; ignored when [obscureText] is true.
  final int maxLines;
  final int? minLines;

  /// An externally-controlled inline error. When non-null the border turns red
  /// and the message is shown directly under the field (used for on-blur /
  /// on-submit validation driven by the parent form).
  final String? errorText;

  /// Notifies the parent when focus enters/leaves — enables on-blur validation.
  final ValueChanged<bool>? onFocusChange;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.errorText,
    this.onFocusChange,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _borderColor;
  bool _isFocused = false;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _borderColor = ColorTween(
      begin: AppColors.darkBorder,
      end: AppColors.primary,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange(bool focused) {
    setState(() => _isFocused = focused);
    widget.onFocusChange?.call(focused);
    if (focused) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final defaultBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final hasError = widget.errorText != null;
    final field = AnimatedBuilder(
      animation: _borderColor,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.xlAll,
          border: Border.all(
            color: hasError
                ? AppColors.error
                : (_isFocused ? AppColors.primary : defaultBorder),
            width: (_isFocused || hasError) ? 1.5 : 1,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: child,
      ),
      child: Focus(
        onFocusChange: _onFocusChange,
        child: TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.obscureText ? 1 : widget.minLines,
          style: AppTypography.body.copyWith(
            color: isDark ? AppColors.textPrimary : AppColors.textDark,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            counterText: '',
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: _isFocused
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  )
                : null,
            suffixIcon: widget.obscureText
                ? GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  )
                : widget.suffix ??
                      (widget.suffixIcon != null
                          ? Icon(
                              widget.suffixIcon,
                              size: 20,
                              color: _isFocused
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            )
                          : null),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            labelStyle: AppTypography.body.copyWith(
              color: _isFocused ? AppColors.primary : AppColors.textTertiary,
            ),
            floatingLabelStyle: AppTypography.bodySmall.copyWith(
              color: _isFocused ? AppColors.primary : AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );

    if (!hasError) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 6),
          child: Text(
            widget.errorText!,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
