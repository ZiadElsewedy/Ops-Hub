import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/utils/validators.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:opshub/features/profile/presentation/cubit/profile_state.dart';

/// First-login profile completion. Shown (and confined to by the router) when the
/// signed-in account has `isProfileCompleted == false`. Collects the onboarding
/// fields — phone, emergency contact, birth date and address are required; a
/// profile photo is optional. On save, `isProfileCompleted` is flipped and the
/// router advances to Home.
class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _birthDate;
  File? _avatarFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Ensure the profile doc is in the cubit so `save` has a base to merge onto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.currentUser?.uid;
      if (uid != null) context.read<ProfileCubit>().loadProfile(uid);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emergencyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      AppSnackbar.error(context, 'Please select your birth date.');
      return;
    }
    final uid = context.currentUser?.uid;
    if (uid == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    context.read<ProfileCubit>().save(
          uid: uid,
          phoneNumber: _phoneController.text.trim(),
          emergencyContact: _emergencyController.text.trim(),
          address: _addressController.text.trim(),
          birthDate: _birthDate,
          avatarFile: _avatarFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateLabel = _birthDate == null
        ? 'Select your birth date'
        : AppDateFormatter.numeric(_birthDate!);

    return AuthScaffold(
      actions: [
        TextButton(
          onPressed: () => context.read<AuthCubit>().signOut(),
          child: Text('Sign out',
              style: AppTypography.label
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ],
      child: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          state.mapOrNull(
            saved: (_) {
              // Profile fields persisted → mark onboarding complete; the router
              // then advances to Home.
              context.read<AuthCubit>().completeProfile();
            },
            error: (e) {
              setState(() => _submitting = false);
              AppSnackbar.error(context, e.message);
            },
          );
        },
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 40),
                  child: Text(
                    'Complete your profile',
                    style: AppTypography.displayMedium.copyWith(
                      color:
                          isDark ? AppColors.textPrimary : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const FadeSlideTransition(
                  delay: Duration(milliseconds: 90),
                  child: Text(
                    'A few details before you get started.',
                    style: AppTypography.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Optional profile photo.
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 130),
                  child: Center(child: _photoPicker()),
                ),
                const SizedBox(height: AppSpacing.xl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 170),
                  child: AppTextField(
                    controller: _phoneController,
                    label: 'Phone number',
                    hint: '+20 100 000 0000',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [Validators.phoneInput],
                    validator: Validators.phone,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 200),
                  child: AppTextField(
                    controller: _emergencyController,
                    label: 'Emergency contact',
                    hint: 'Name & phone',
                    prefixIcon: Icons.contact_phone_outlined,
                    validator: Validators.emergencyContact,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 230),
                  child: AppTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Street, city',
                    prefixIcon: Icons.home_outlined,
                    maxLines: 2,
                    validator: Validators.address,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Birth date (tappable field).
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 260),
                  child: GestureDetector(
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined,
                              size: 20, color: AppColors.textTertiary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              dateLabel,
                              style: AppTypography.body.copyWith(
                                color: _birthDate == null
                                    ? AppColors.textTertiary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 320),
                  beginOffset: const Offset(0, 16),
                  child: AppButton(
                    label: 'Continue',
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder, width: 1.5),
              image: _avatarFile != null
                  ? DecorationImage(
                      image: FileImage(_avatarFile!), fit: BoxFit.cover)
                  : null,
            ),
            child: _avatarFile == null
                ? const Icon(Icons.person_outline_rounded,
                    size: 40, color: AppColors.textTertiary)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkBg, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 15, color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
