import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/utils/platform_capabilities.dart';
import 'package:drop/core/utils/validators.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';
import 'package:drop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:drop/features/profile/presentation/cubit/profile_state.dart';
import 'package:drop/features/profile/presentation/widgets/profile_avatar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _emergency = TextEditingController();
  final _paymentNumber = TextEditingController();

  File? _avatarFile;
  File? _coverFile;

  bool _seeded = false;
  late ProfileEntity _initial;

  void _seed(ProfileEntity p) {
    if (_seeded) return;
    _initial = p;
    _name.text = p.fullName ?? '';
    _bio.text = p.bio ?? '';
    _phone.text = p.phoneNumber ?? '';
    _address.text = p.address ?? '';
    _emergency.text = p.emergencyContact ?? '';
    _paymentNumber.text = p.paymentNumber ?? '';
    _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _phone.dispose();
    _address.dispose();
    _emergency.dispose();
    _paymentNumber.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isCover}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.darkSurfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.textPrimary, size: 20),
              title: const Text('Choose from library', style: AppTypography.label),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (supportsCameraCapture)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.textPrimary, size: 20),
                title: const Text('Take a photo', style: AppTypography.label),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      // Compress/downscale in the picker (native, off the UI isolate) so the
      // upload stays small and the UI never stalls decoding a huge original.
      final picked = await picker.pickImage(
        source: source,
        maxWidth: isCover ? 1280 : 800,
        imageQuality: 70,
      );
      if (picked == null) return;
      setState(() {
        if (isCover) {
          _coverFile = File(picked.path);
        } else {
          _avatarFile = File(picked.path);
        }
      });
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not open the picker.');
    }
  }

  String? _orNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // The self-service contact + salary-payment sections are for managers and
    // employees — the admin MANAGES compensation and has no manager to reach
    // them, so an admin save never touches those fields (they aren't shown).
    final isAdmin = context.isAdmin;
    context.read<ProfileCubit>().save(
          uid: _initial.uid,
          fullName: _orNull(_name),
          bio: _orNull(_bio),
          phoneNumber: isAdmin ? null : _orNull(_phone),
          address: isAdmin ? null : _orNull(_address),
          emergencyContact: isAdmin ? null : _orNull(_emergency),
          paymentNumber: isAdmin ? null : _orNull(_paymentNumber),
          avatarFile: _avatarFile,
          coverFile: _coverFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Edit Profile',
      contentMaxWidth: 620,
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listenWhen: (prev, curr) => curr.isSavedOrError,
        listener: (context, state) {
          state.whenOrNull(
            saved: (_) {
              AppSnackbar.success(context, 'Profile updated');
              context.pop();
            },
            error: (msg) => AppSnackbar.error(context, msg),
          );
        },
        builder: (context, state) {
          final profile = state.maybeWhen(
            loaded: (p) => p,
            saving: (p, _) => p,
            saved: (p) => p,
            orElse: () => null,
          );
          if (profile == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          _seed(profile);
          final isSaving =
              state.maybeWhen(saving: (_, _) => true, orElse: () => false);
          final uploadProgress =
              state.maybeWhen(saving: (_, p) => p, orElse: () => null);

          return _Form(
            uploadProgress: uploadProgress,
            formKey: _formKey,
            initial: _initial,
            name: _name,
            bio: _bio,
            phone: _phone,
            address: _address,
            emergency: _emergency,
            paymentNumber: _paymentNumber,
            avatarFile: _avatarFile,
            coverFile: _coverFile,
            isSaving: isSaving,
            onPickAvatar: () => _pickImage(isCover: false),
            onPickCover: () => _pickImage(isCover: true),
            onSave: _save,
          );
        },
      ),
    );
  }
}

/// Convenience matcher so the listener only fires on terminal save outcomes.
extension on ProfileState {
  bool get isSavedOrError =>
      maybeWhen(saved: (_) => true, error: (_) => true, orElse: () => false);
}

class _Form extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final ProfileEntity initial;
  final TextEditingController name, bio, phone, address, emergency, paymentNumber;
  final File? avatarFile;
  final File? coverFile;
  final bool isSaving;
  final double? uploadProgress;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;
  final VoidCallback onSave;

  const _Form({
    required this.formKey,
    required this.initial,
    required this.name,
    required this.bio,
    required this.phone,
    required this.address,
    required this.emergency,
    required this.paymentNumber,
    required this.avatarFile,
    required this.coverFile,
    required this.isSaving,
    required this.uploadProgress,
    required this.onPickAvatar,
    required this.onPickCover,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImagesHeader(
              initials: initial.initials,
              avatarUrl: initial.profileImage,
              coverUrl: initial.coverImage,
              avatarFile: avatarFile,
              coverFile: coverFile,
              uploadProgress: uploadProgress,
              onPickAvatar: onPickAvatar,
              onPickCover: onPickCover,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                  AppSpacing.xl, AppSpacing.pagePadding, AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    controller: name,
                    hint: 'Full name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Full name is required'
                        : null,
                  ),
                  _Field(
                    controller: bio,
                    hint: 'Bio',
                    icon: Icons.notes_rounded,
                    maxLength: 160,
                    maxLines: 3,
                  ),
                  // Self-service sections for managers/employees only. The
                  // admin manages compensation (never receives it in-app)
                  // and has no manager to be reached by — owner ruling.
                  if (!context.isAdmin) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel(
                      'CONTACT DETAILS',
                      hint: 'Keep these current — your manager uses them to '
                          'reach you.',
                    ),
                    _Field(
                      controller: phone,
                      hint: 'Phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [Validators.phoneInput],
                      validator: (v) => Validators.phone(v, required: false),
                    ),
                    _Field(
                      controller: address,
                      hint: 'Address',
                      icon: Icons.home_outlined,
                      validator: (v) => Validators.address(v, required: false),
                    ),
                    _Field(
                      controller: emergency,
                      hint: 'Emergency contact (name · phone)',
                      icon: Icons.emergency_outlined,
                      validator: (v) =>
                          Validators.emergencyContact(v, required: false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel(
                      'SALARY PAYMENT NUMBER',
                      hint: 'The wallet or account number your salary is sent '
                          'to. Salary details are managed by your admin.',
                    ),
                    _Field(
                      controller: paymentNumber,
                      hint: 'Wallet / account number',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [Validators.phoneInput],
                      validator: (v) => Validators.phone(v, required: false),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: uploadProgress != null
                        ? 'Uploading ${(uploadProgress! * 100).round()}%'
                        : (isSaving ? 'Saving…' : 'Save Changes'),
                    isLoading: isSaving && uploadProgress == null,
                    onPressed: isSaving ? null : onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagesHeader extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final String? coverUrl;
  final File? avatarFile;
  final File? coverFile;
  final double? uploadProgress;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;

  const _ImagesHeader({
    required this.initials,
    required this.avatarUrl,
    required this.coverUrl,
    required this.avatarFile,
    required this.coverFile,
    required this.uploadProgress,
    required this.onPickAvatar,
    required this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    const coverH = 104.0;
    const avatarSize = 76.0;
    final uploading = uploadProgress != null;
    final coverUploading = uploading && coverFile != null;
    final avatarUploading = uploading && avatarFile != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: uploading ? null : onPickCover,
          child: SizedBox(
            height: coverH,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _coverImage(),
                if (coverUploading)
                  Container(
                    color: AppColors.black.withAlpha(120),
                    child: Center(child: _UploadOverlay(progress: uploadProgress!)),
                  )
                else
                  const Positioned(
                    right: 12,
                    bottom: 10,
                    child: Icon(Icons.photo_camera_outlined,
                        color: AppColors.textSecondary, size: 18),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
              top: coverH - avatarSize / 2, left: AppSpacing.pagePadding),
          child: GestureDetector(
            onTap: uploading ? null : onPickAvatar,
            child: Stack(
              children: [
                ProfileAvatar(
                  initials: initials,
                  imageUrl: avatarUrl,
                  localFile: avatarFile,
                  size: avatarSize,
                ),
                if (avatarUploading)
                  Positioned.fill(
                    child: ClipOval(
                      child: Container(
                        color: AppColors.black.withAlpha(130),
                        child: Center(
                            child: _UploadOverlay(
                                progress: uploadProgress!, size: 30)),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.darkBg, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: AppColors.textPrimary, size: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverImage() {
    // cacheWidth caps the decoded bitmap so a full-res image never decodes at
    // native size for a short cover strip (avoids memory spikes / jank).
    if (coverFile != null) {
      return Image.file(coverFile!, fit: BoxFit.cover, cacheWidth: 1280);
    }
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return Image.network(coverUrl!,
          fit: BoxFit.cover,
          cacheWidth: 1280,
          errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.darkSurface));
    }
    return const ColoredBox(color: AppColors.darkSurface);
  }
}

/// Small uppercase section header with an optional plain-language hint line —
/// keeps the longer form scannable for a first-time user.
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? hint;
  const _SectionLabel(this.text, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: AppTypography.caption.copyWith(letterSpacing: 1.0)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }
}

/// Compact, always-dark input — independent of the ambient theme.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        cursorColor: AppColors.primary,
        style: AppTypography.label.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w400, fontSize: 15),
        decoration: _fieldDecoration(hint, icon),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.darkSurface,
      isDense: true,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _border(AppColors.darkBorder),
      enabledBorder: _border(AppColors.darkBorder),
      focusedBorder: _border(AppColors.primary.withAlpha(110), 1.2),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, 1.2),
    );

OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );

class _UploadOverlay extends StatelessWidget {
  final double progress;
  final double size;
  const _UploadOverlay({required this.progress, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: AppColors.white,
            backgroundColor: AppColors.white.withAlpha(50),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(progress * 100).round()}%',
            style: AppTypography.caption.copyWith(color: AppColors.white)),
      ],
    );
  }
}
