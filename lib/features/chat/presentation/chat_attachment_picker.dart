import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drop/core/enums/chat_attachment_format.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';

/// Thrown when the user picks a document whose type the backend does not accept
/// (AR-2). The composer catches it to show "Unsupported file type" instead of
/// silently attaching nothing.
class UnsupportedAttachmentException implements Exception {
  const UnsupportedAttachmentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The source of chat attachments — a thin seam over the platform pickers so
/// the composer can be widget-tested with a fake. Each method returns a ready
/// [ChatOutgoingAttachment] (bytes + validated format), or null when the user
/// cancels. Images route through `image_picker` (camera/gallery), documents
/// through `file_picker`, restricted to the formats the API accepts.
abstract class ChatAttachmentSource {
  Future<ChatOutgoingAttachment?> pickCameraImage();
  Future<ChatOutgoingAttachment?> pickGalleryImage();

  /// Throws [UnsupportedAttachmentException] for a disallowed document type.
  Future<ChatOutgoingAttachment?> pickDocument();
}

/// Real implementation backed by `image_picker` + `file_picker`.
class ChatAttachmentPicker implements ChatAttachmentSource {
  ChatAttachmentPicker({ImagePicker? imagePicker})
      : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  static const _docExtensions = <String>[
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip',
  ];

  @override
  Future<ChatOutgoingAttachment?> pickCameraImage() =>
      _pickImage(ImageSource.camera);

  @override
  Future<ChatOutgoingAttachment?> pickGalleryImage() =>
      _pickImage(ImageSource.gallery);

  Future<ChatOutgoingAttachment?> _pickImage(ImageSource source) async {
    // Downscale + recompress on pick so a phone photo doesn't become a
    // multi-megabyte base64 body (the API caps attachment size).
    final picked = await _images.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final format =
        ChatAttachmentFormat.fromExtension(_extensionOf(picked.name)) ??
            ChatAttachmentFormat.jpg;
    return ChatOutgoingAttachment(
      format: format,
      mimeType: picked.mimeType ?? mimeForFormat(format),
      originalFilename: picked.name,
      bytes: bytes,
    );
  }

  @override
  Future<ChatOutgoingAttachment?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: _docExtensions,
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    if (file == null) return null;
    final bytes = file.bytes;
    final format = ChatAttachmentFormat.fromExtension(file.extension);
    if (bytes == null || format == null) {
      throw const UnsupportedAttachmentException('Unsupported file type.');
    }
    return ChatOutgoingAttachment(
      format: format,
      mimeType: mimeForFormat(format),
      originalFilename: file.name,
      bytes: bytes,
    );
  }

  static String? _extensionOf(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? null : filename.substring(dot + 1);
  }
}

/// The MIME type the API expects for a given format (used when the picker does
/// not supply one). Kept beside the picker as the single format→MIME mapping.
String mimeForFormat(ChatAttachmentFormat format) => switch (format) {
      ChatAttachmentFormat.jpg ||
      ChatAttachmentFormat.jpeg =>
        'image/jpeg',
      ChatAttachmentFormat.png => 'image/png',
      ChatAttachmentFormat.pdf => 'application/pdf',
      ChatAttachmentFormat.doc => 'application/msword',
      ChatAttachmentFormat.docx =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ChatAttachmentFormat.xls => 'application/vnd.ms-excel',
      ChatAttachmentFormat.xlsx =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ChatAttachmentFormat.ppt => 'application/vnd.ms-powerpoint',
      ChatAttachmentFormat.pptx =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      ChatAttachmentFormat.txt => 'text/plain',
      ChatAttachmentFormat.zip => 'application/zip',
    };
