import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// Renders a **real poster frame** extracted from a video (network URL or local
/// file path), filling its parent. The caller draws the play overlay on top.
///
/// - **Generation:** `video_thumbnail` decodes one frame natively (it seeks the
///   source rather than downloading the whole file). Frames are small — 256px /
///   JPEG q60 — so decode + memory stay cheap.
/// - **Caching:** results are memoised in a bounded LRU ([_ThumbCache]) keyed by
///   source, so a frame is generated once per session and reused across rebuilds
///   / scrolls; concurrent requests for the same source share one future.
/// - **Fallback:** while generating it shows a quiet loader; on failure (or an
///   unsupported platform) it degrades to a dark tile with a film glyph — the UI
///   never blocks or breaks.
class VideoThumbnailImage extends StatefulWidget {
  const VideoThumbnailImage({super.key, required this.source});

  /// A remote download URL or a local file path.
  final String source;

  @override
  State<VideoThumbnailImage> createState() => _VideoThumbnailImageState();
}

class _VideoThumbnailImageState extends State<VideoThumbnailImage> {
  late Future<Uint8List?> _future = _ThumbCache.instance.get(widget.source);

  @override
  void didUpdateWidget(VideoThumbnailImage old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      _future = _ThumbCache.instance.get(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ThumbState(loading: true);
        }
        final bytes = snap.data;
        if (bytes == null) return const _ThumbState(loading: false);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 256,
          errorBuilder: (_, _, _) => const _ThumbState(loading: false),
        );
      },
    );
  }
}

/// Loading / fallback tile — a quiet dark surface with a spinner or a film glyph.
class _ThumbState extends StatelessWidget {
  const _ThumbState({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurfaceElevated,
      alignment: loading ? Alignment.center : Alignment.topLeft,
      padding: loading ? EdgeInsets.zero : const EdgeInsets.all(6),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.movie_outlined,
              size: 16, color: AppColors.textTertiary),
    );
  }
}

/// Process-lifetime LRU cache of generated thumbnails. Bounded so a long session
/// browsing many videos can't grow memory without limit (each entry is a small
/// JPEG ≈ 10–30 KB → ~1–2 MB at the cap).
class _ThumbCache {
  _ThumbCache._();
  static final _ThumbCache instance = _ThumbCache._();

  static const int _maxEntries = 60;
  final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?> get(String source) {
    // Move-to-most-recent on hit (simple LRU).
    final existing = _cache.remove(source);
    if (existing != null) {
      _cache[source] = existing;
      return existing;
    }
    final future = _generate(source);
    _cache[source] = future;
    // Don't permanently cache a failure — drop it so a later view can retry.
    future.then((bytes) {
      if (bytes == null) _cache.remove(source);
    });
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first); // evict oldest
    }
    return future;
  }

  Future<Uint8List?> _generate(String source) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        quality: 60,
      );
    } catch (_) {
      return null; // widget shows the fallback tile
    }
  }
}
