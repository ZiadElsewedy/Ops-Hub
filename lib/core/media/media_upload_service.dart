import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/errors/exceptions.dart';

/// The result of one successful media upload — the Storage object id (the
/// filename stem) and its download URL. Deliberately minimal: the uploader
/// identity, capture time and duration are known at the call site and belong to
/// each feature's own attachment entity, so `core` never depends on a feature
/// type.
class UploadedMedia {
  const UploadedMedia({required this.id, required this.url});
  final String id;
  final String url;
}

/// Thrown by [MediaUploadService.upload] when the upload was cancelled through an
/// [UploadCanceller]. Distinct from a real failure so the caller can restore the
/// UI quietly (no error snackbar) and keep the user's selection.
class UploadCancelledException implements Exception {
  const UploadCancelledException();
}

/// A cancellation handle for an in-flight batch of [MediaUploadService.upload]s.
/// The submission flow holds one per attempt and calls [cancel] (e.g. from the
/// overlay's Cancel button) to abort **every** active Firebase upload at once,
/// and to block any not-yet-started one. Idempotent.
class UploadCanceller {
  final List<UploadTask> _active = <UploadTask>[];
  bool _cancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Cancels every active upload and blocks any that hasn't started. Idempotent.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final t in List<UploadTask>.of(_active)) {
      t.cancel(); // fire-and-forget; surfaces as a `canceled` FirebaseException
    }
    _active.clear();
  }

  // ── Registration — used by MediaUploadService only (same library) ──
  void _attach(UploadTask task) {
    if (_cancelled) {
      task.cancel(); // raced past the pre-check → cancel immediately
      return;
    }
    _active.add(task);
  }

  void _detach(UploadTask task) => _active.remove(task);
}

/// The **single seam** for uploading media (images / videos) to Firebase
/// Storage. Task evidence, case attachments and request attachments all route
/// through here instead of each datasource re-implementing the same putFile +
/// progress + timeout + error-translation block (previously triplicated).
///
/// Behaviour is preserved verbatim from the per-feature implementations, plus:
/// - every object is written with a long `Cache-Control` (media is immutable
///   under the create-only Storage rules, so it can be cached hard — this cuts
///   repeat Firebase egress on the review/gallery surfaces for free);
/// - a fresh, collision-free id per upload so files are **never overwritten**.
class MediaUploadService {
  MediaUploadService(this._storage);

  final FirebaseStorage _storage;

  /// Hard ceiling so a misconfigured/disabled bucket or a dropped connection
  /// fails cleanly instead of hanging the submit flow indefinitely. Videos can
  /// be large, so the window is generous.
  static const _uploadTimeout = Duration(seconds: 180);

  /// One week. Media is immutable (create-only rules — the object at a given URL
  /// never changes), so it is safe to cache aggressively on clients / CDN.
  static const _cacheControl = 'public, max-age=604800';

  /// Uploads [file] under [basePath] (e.g. `tasks/{taskId}/attachments`) at a
  /// fresh unique id → `<basePath>/<id>.<ext>` (never overwrites). Reports byte
  /// progress via [onProgress] (transferred, total). Throws [ServerException]
  /// with an actionable message on failure.
  Future<UploadedMedia> upload({
    required String basePath,
    required File file,
    required AttachmentType type,
    UploadCanceller? canceller,
    void Function(int transferred, int total)? onProgress,
  }) async {
    // Already cancelled before we start → don't even begin the upload.
    if (canceller != null && canceller.isCancelled) {
      throw const UploadCancelledException();
    }
    final id = _uniqueId();
    final ext = _extensionFor(file.path, type);
    final task = _storage.ref('$basePath/$id.$ext').putFile(
          file,
          SettableMetadata(
            contentType: _contentType(ext, type),
            cacheControl: _cacheControl,
          ),
        );
    canceller?._attach(task);
    // Live byte progress for the caller's loading overlay.
    final sub = task.snapshotEvents
        .listen((s) => onProgress?.call(s.bytesTransferred, s.totalBytes));
    try {
      final snapshot = await task.timeout(
        _uploadTimeout,
        onTimeout: () {
          task.cancel();
          throw const ServerException(
              'Upload timed out. Check your connection and try again.');
        },
      );
      final url = await snapshot.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 30));
      return UploadedMedia(id: id, url: url);
    } on TimeoutException {
      throw const ServerException(
          'Upload timed out. Check your connection and try again.');
    } on FirebaseException catch (e) {
      // A cancel() surfaces as a `canceled` FirebaseException — translate it to a
      // clean cancellation (not a scary error) when a cancel was requested.
      if ((canceller != null && canceller.isCancelled) || e.code == 'canceled') {
        throw const UploadCancelledException();
      }
      throw ServerException(_storageError(e));
    } finally {
      canceller?._detach(task);
      await sub.cancel();
    }
  }

  // A fresh 20-char id (the Storage filename stem). Dependency-free and
  // collision-free for practical purposes (62^20 ≈ 7e35 space) — matching the
  // uniqueness guarantee the Firestore push id previously provided, without
  // needing a Firestore handle here.
  static final _rand = Random.secure();
  static const _idAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static String _uniqueId() => List.generate(
        20,
        (_) => _idAlphabet[_rand.nextInt(_idAlphabet.length)],
      ).join();

  /// Lower-case file extension, falling back to a sensible default per [type].
  static String _extensionFor(String path, AttachmentType type) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    return type.isVideo ? 'mp4' : 'jpg';
  }

  /// MIME type from extension (falls back to a generic image/video type).
  static String _contentType(String ext, AttachmentType type) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      default:
        return type.isVideo ? 'video/mp4' : 'image/jpeg';
    }
  }

  /// Translates a Storage [FirebaseException] into an actionable message.
  ///
  /// An `unauthorized` / `object-not-found` error almost always means the
  /// Storage rules aren't deployed or the bucket isn't enabled — not a bad
  /// connection. Surfacing the real code is what makes the pipeline diagnosable
  /// in the field.
  static String _storageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'unauthenticated':
        return 'Upload was blocked by Storage permissions (${e.code}). '
            'Firebase Storage rules likely need to be deployed.';
      case 'object-not-found':
      case 'bucket-not-found':
      case 'project-not-found':
        return 'Firebase Storage isn\'t set up for this project (${e.code}). '
            'Enable Storage in the Firebase console, then retry.';
      case 'retry-limit-exceeded':
      case 'canceled':
        return 'Upload failed — check your connection and try again.';
      default:
        return e.message ?? 'Upload failed (${e.code}).';
    }
  }
}
