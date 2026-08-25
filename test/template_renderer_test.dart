import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/communications/domain/template_renderer.dart';

/// Phase 2 — the pure `{{placeholder}}` rendering engine.
void main() {
  group('TemplateRenderer.extract', () {
    test('finds tokens in first-seen order, de-duplicated', () {
      const text =
          'Hi {{employee_name}}, your {{task_name}} at {{branch_name}} is due '
          '{{date}}. Thanks {{employee_name}}.';
      expect(TemplateRenderer.extract(text),
          ['employee_name', 'task_name', 'branch_name', 'date']);
    });

    test('tolerates inner whitespace; empty when no tokens', () {
      expect(TemplateRenderer.extract('{{  sender_name  }}'), ['sender_name']);
      expect(TemplateRenderer.extract('plain text'), isEmpty);
    });
  });

  group('TemplateRenderer.render', () {
    const text = 'Hello {{employee_name}}, see {{task_name}}.';

    test('replaces present keys; leaves missing untouched by default', () {
      final out = TemplateRenderer.render(text, {'employee_name': 'Ziad'});
      expect(out, 'Hello Ziad, see {{task_name}}.');
    });

    test('blankMissing renders unknown tokens to empty', () {
      final out = TemplateRenderer.render(
        text,
        {'employee_name': 'Ziad'},
        blankMissing: true,
      );
      expect(out, 'Hello Ziad, see .');
    });

    test('renders all when full context provided', () {
      final out = TemplateRenderer.render(text, {
        'employee_name': 'Ziad',
        'task_name': 'Stock count',
      });
      expect(out, 'Hello Ziad, see Stock count.');
      expect(TemplateRenderer.hasUnresolved(out, const {}), isFalse);
    });

    test('hasUnresolved flags leftover tokens', () {
      expect(
          TemplateRenderer.hasUnresolved(text, {'employee_name': 'Ziad'}), isTrue);
      expect(
          TemplateRenderer.hasUnresolved(
              text, {'employee_name': 'Z', 'task_name': 'T'}),
          isFalse);
    });
  });
}
