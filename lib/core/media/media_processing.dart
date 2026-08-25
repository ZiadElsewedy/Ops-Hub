import 'dart:io';

import 'package:image_cropper/image_cropper.dart';
import 'package:video_compress/video_compress.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// Pre-upload media processing (Phase 10 · P1): the on-device **image editor**
/// (crop / rotate / flip / aspect) and **video compression** that run between
/// picking a file and adding it to the upload queue.
///
/// Both are **mobile-only** and best-effort — every caller must gate on
/// `supportsImageEditing` / `supportsVideoCompression` (platform_capabilities)
/// so the desktop/web build never invokes the underlying plugin (which has no
/// implementation there). On any failure the caller keeps the original file so
/// evidence is never lost.
class MediaProcessing {
  MediaProcessing._();

  /// Opens the native crop / rotate / flip / aspect editor on [source]. Returns
  /// the edited image as a **new** temp file (the original is untouched and
  /// never uploaded), or null if the user cancelled or anything failed — in
  /// which case the caller keeps the original pick. The result is re-encoded as
  /// JPEG at [_imageQuality], which also strips EXIF/GPS metadata.
  static Future<File?> editImage(File source) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: source.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: _imageQuality,
        maxWidth: _imageMaxWidth,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit photo',
            toolbarColor: AppColors.darkSurface,
            toolbarWidgetColor: AppColors.textPrimary,
            backgroundColor: AppColors.darkBg,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            aspectRatioPresets: _aspectPresets,
          ),
          IOSUiSettings(
            title: 'Edit photo',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPresets: _aspectPresets,
          ),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (_) {
      return null; // caller keeps the original pick
    }
  }

  /// Transcodes [source] to a smaller medium-quality file before upload — the
  /// single biggest Storage/egress saving for operational videos. [onProgress]
  /// reports 0–100. Returns the compressed file, or **null** on failure/cancel
  /// so the caller can decide (fall back to the original, or abort on an
  /// explicit user cancel).
  static Future<File?> compressVideo(
    File source, {
    void Function(double percent)? onProgress,
  }) async {
    Subscription? sub;
    try {
      if (onProgress != null) {
        sub = VideoCompress.compressProgress$.subscribe(onProgress);
      }
      final info = await VideoCompress.compressVideo(
        source.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info == null || info.isCancel == true) return null;
      return info.file;
    } catch (_) {
      return null;
    } finally {
      sub?.unsubscribe();
    }
  }

  /// Cancels an in-flight [compressVideo] (wired to the progress dialog's
  /// Cancel button). Safe to call when nothing is compressing.
  static Future<void> cancelVideoCompression() =>
      VideoCompress.cancelCompression();

  // Match the picker's image baseline (AttachmentLimits.imageQuality /
  // imageMaxWidth) so an edited image is optimized the same way a freshly-picked
  // one is. Kept as local consts because AttachmentLimits lives in the task
  // feature and `core` must not depend on a feature.
  static const int _imageQuality = 70;
  static const int _imageMaxWidth = 1600;
  static const _aspectPresets = <CropAspectRatioPreset>[
    CropAspectRatioPreset.original,
    CropAspectRatioPreset.square,
    CropAspectRatioPreset.ratio4x3,
    CropAspectRatioPreset.ratio16x9,
  ];
}
