import 'package:flutter/material.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';

/// Password input built on [AppTextField]: obscured with the same built-in
/// show/hide toggle, lock prefix, and unified focus/error styling. Use this on
/// every login / register / change-password / delete-account screen instead of
/// re-wiring `obscureText` + a visibility toggle by hand.
class AppPasswordField extends StatelessWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.prefixIcon = Icons.lock_outline_rounded,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) => AppTextField(
        controller: controller,
        label: label,
        hint: hint,
        prefixIcon: prefixIcon,
        obscureText: true,
        validator: validator,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
      );
}
