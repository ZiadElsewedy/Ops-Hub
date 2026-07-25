import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';

/// What the user chose in the attachment sheet.
enum ChatAttachmentChoice { camera, gallery, document }

/// A premium attachment sheet — a grabber, a title, and a set of source rows
/// (icon chip · label · subtitle), iMessage/Telegram-style. Returns the choice
/// (or null if dismissed); the caller runs the matching picker.
///
/// Only the backend-supported sources are offered: Camera and Photos (images)
/// and Documents (PDF/Office/text/zip). Video is intentionally absent — the API
/// accepts no video attachment format, so a "Videos" option would fail on
/// upload; adding it needs a backend/contract change, not a UI one.
Future<ChatAttachmentChoice?> showChatAttachmentSheet(BuildContext context) {
  return showModalBottomSheet<ChatAttachmentChoice>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text('Share',
                  style: AppTypography.h3
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            _SourceRow(
              icon: Icons.photo_camera_rounded,
              label: 'Camera',
              subtitle: 'Take a photo',
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatAttachmentChoice.camera),
            ),
            _SourceRow(
              icon: Icons.photo_library_rounded,
              label: 'Photos',
              subtitle: 'Choose from your library',
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatAttachmentChoice.gallery),
            ),
            _SourceRow(
              icon: Icons.description_rounded,
              label: 'Documents',
              subtitle: 'PDF, Word, Excel, and more',
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatAttachmentChoice.document),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashFactory: NoSplash.splashFactory,
        highlightColor: AppColors.primarySurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 24, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textQuaternary),
            ],
          ),
        ),
      ),
    );
  }
}
