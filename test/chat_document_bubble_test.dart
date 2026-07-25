import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/chat/presentation/chat_message_preview.dart';
import 'package:drop/features/chat/presentation/widgets/chat_message_list.dart';

/// Pure-function coverage for the document-bubble helpers: the format → icon
/// mapping (Part 6) and the human-readable size line.
void main() {
  group('chatDocumentIcon', () {
    test('maps each supported format to a distinct, sensible icon', () {
      expect(chatDocumentIcon('PDF'), Icons.picture_as_pdf_rounded);
      expect(chatDocumentIcon('pdf'), Icons.picture_as_pdf_rounded); // case-insensitive
      expect(chatDocumentIcon('DOC'), Icons.description_rounded);
      expect(chatDocumentIcon('DOCX'), Icons.description_rounded);
      expect(chatDocumentIcon('TXT'), Icons.description_rounded);
      expect(chatDocumentIcon('XLS'), Icons.table_chart_rounded);
      expect(chatDocumentIcon('XLSX'), Icons.table_chart_rounded);
      expect(chatDocumentIcon('PPT'), Icons.slideshow_rounded);
      expect(chatDocumentIcon('PPTX'), Icons.slideshow_rounded);
    });

    test('falls back to a generic file icon for anything unknown', () {
      expect(chatDocumentIcon('ZIP'), Icons.insert_drive_file_rounded);
      expect(chatDocumentIcon(''), Icons.insert_drive_file_rounded);
    });
  });

  group('chatHumanBytes', () {
    test('renders binary units', () {
      expect(chatHumanBytes(842), '842 B');
      expect(chatHumanBytes(577 * 1024), '577 KB');
      expect(chatHumanBytes(3 * 1024 * 1024 + 512 * 1024), '3.5 MB');
    });
  });
}
