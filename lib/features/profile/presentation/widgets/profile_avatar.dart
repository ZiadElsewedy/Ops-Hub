import 'dart:io';

import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// A circular avatar that renders, in priority order: a locally-picked file,
/// a network image, or initials on a neutral surface. Used on the profile and
/// edit screens at different sizes.
class ProfileAvatar extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final File? localFile;
  final double size;
  final bool showRing;

  const ProfileAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.localFile,
    this.size = 88,
    this.showRing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkSurfaceElevated,
        border: showRing
            ? Border.all(color: AppColors.darkBg, width: 3)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    // Cap the decoded bitmap to ~3× the logical size (covers high-DPI) so the
    // avatar never decodes a full-resolution image into memory.
    final decodeWidth = (size * 3).round();
    if (localFile != null) {
      return Image.file(localFile!,
          fit: BoxFit.cover, width: size, height: size, cacheWidth: decodeWidth);
    }
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: decodeWidth,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _initialsLayer(),
        errorBuilder: (_, _, _) => _initialsLayer(),
      );
    }
    return _initialsLayer();
  }

  Widget _initialsLayer() => Center(
        child: Text(
          initials,
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary,
            fontSize: size * 0.34,
          ),
        ),
      );
}
