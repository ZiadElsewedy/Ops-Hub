import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';

/// A branch's identity mark — its uploaded **logo**, else monochrome **initials**
/// from the name (a store glyph when the name is empty). A rounded square (a
/// branch reads as a "place", not a person, so it isn't a circle).
///
/// §8 Branch Media / §11 reusable components. Strictly monochrome.
class BranchAvatar extends StatelessWidget {
  const BranchAvatar({
    super.key,
    this.logoUrl,
    this.name,
    this.size = 46,
    this.radius = 14,
  });

  final String? logoUrl;
  final String? name;
  final double size;
  final double radius;

  factory BranchAvatar.fromBranch(BranchEntity branch, {double size = 46}) =>
      BranchAvatar(logoUrl: branch.logoUrl, name: branch.name, size: size);

  @override
  Widget build(BuildContext context) {
    final hasImage = (logoUrl ?? '').isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: hasImage
          ? Image.network(
              logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => Center(child: _fallback()),
            )
          : Center(child: _fallback()),
    );
  }

  Widget _fallback() {
    final initials = _initials(name);
    if (initials.isEmpty) {
      return Icon(Icons.store_mall_directory_outlined,
          size: size * 0.5, color: AppColors.textTertiary);
    }
    return Text(
      initials,
      style: AppTypography.label.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.34,
      ),
    );
  }

  static String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
