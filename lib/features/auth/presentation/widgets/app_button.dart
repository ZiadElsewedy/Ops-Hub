import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.ghost;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _onTapCancel,
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedOpacity(
          opacity: disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: _buildContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _PrimaryButton(
          label: widget.label,
          icon: widget.icon,
          isLoading: widget.isLoading,
        );
      case AppButtonVariant.secondary:
        return _SecondaryButton(
          label: widget.label,
          icon: widget.icon,
          isLoading: widget.isLoading,
          isDark: isDark,
        );
      case AppButtonVariant.ghost:
        return _GhostButton(
          label: widget.label,
          icon: widget.icon,
          isLoading: widget.isLoading,
        );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // The primary action carries the white monochrome accent — the most
    // important interactive element on any screen. Flat (no glow), hairline-clean.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentHover, AppColors.accent],
        ),
        borderRadius: AppRadius.buttonAll,
      ),
      child: Center(child: _buildChild()),
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.onAccent,
        ),
      );
    }
    final textStyle = AppTypography.labelLarge.copyWith(color: AppColors.onAccent);
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: 10),
          Text(label, style: textStyle),
        ],
      );
    }
    return Text(label, style: textStyle);
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isLoading;
  final bool isDark;

  const _SecondaryButton({
    required this.label,
    required this.isLoading,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final text = isDark ? AppColors.textPrimary : AppColors.textDark;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.buttonAll,
        border: Border.all(color: border),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 10)],
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(color: text),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isLoading;

  const _GhostButton({
    required this.label,
    required this.isLoading,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(label,
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.primary)),
              ],
            ),
    );
  }
}
