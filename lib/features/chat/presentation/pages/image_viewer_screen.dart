import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_typography.dart';

/// A full-screen, pinch-to-zoom image viewer. Renders local bytes immediately
/// (an optimistic/just-sent image) or lazily resolves a brokered download URL
/// for a received image via [urlLoader]. Any failure resolves to a quiet
/// "unavailable" state — never a crash or a broken-image glyph.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    this.bytes,
    this.urlLoader,
    this.title,
    this.heroTag,
  });

  /// Local bytes to show directly (wins over [urlLoader] when present).
  final Uint8List? bytes;

  /// Lazily resolves the image URL (received attachments). Null → none.
  final Future<String?> Function()? urlLoader;

  final String? title;

  /// Shared-element tag matching the inline thumbnail, for the open transition.
  final Object? heroTag;

  static Future<void> push(
    BuildContext context, {
    Uint8List? bytes,
    Future<String?> Function()? urlLoader,
    String? title,
    Object? heroTag,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageViewerScreen(
          bytes: bytes,
          urlLoader: urlLoader,
          title: title,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late Future<String?>? _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = widget.bytes == null ? widget.urlLoader?.call() : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.title == null
            ? null
            : Text(
                widget.title!,
                style: AppTypography.body.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: widget.heroTag == null
              ? _buildImage()
              : Hero(tag: widget.heroTag!, child: _buildImage()),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final bytes = widget.bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    final future = _urlFuture;
    if (future == null) return const _Unavailable();
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        final url = snapshot.data;
        if (url == null || url.isEmpty) return const _Unavailable();
        return Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const CircularProgressIndicator(color: Colors.white),
          errorBuilder: (_, _, _) => const _Unavailable(),
        );
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined,
            size: 44, color: Colors.white38),
        const SizedBox(height: 12),
        Text(
          'Image unavailable',
          style: AppTypography.body.copyWith(color: Colors.white38),
        ),
      ],
    );
  }
}
