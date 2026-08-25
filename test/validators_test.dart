import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('accepts a plain and an international number', () {
      expect(Validators.phone('01001234567'), isNull);
      expect(Validators.phone('+20 100 123 4567'), isNull);
      expect(Validators.phone('(020) 100-1234'), isNull);
    });

    test('rejects an email or any letters (the core requirement)', () {
      expect(Validators.phone('test@mail.com'), isNotNull);
      expect(Validators.phone('call me'), isNotNull);
      expect(Validators.phone('0100abc4567'), isNotNull);
    });

    test('rejects too few / too many digits', () {
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('1234567890123456'), isNotNull);
    });

    test('empty is required by default, optional when required:false', () {
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone(null), isNotNull);
      expect(Validators.phone('', required: false), isNull);
    });
  });

  group('Validators.name', () {
    test('accepts Latin and Arabic names', () {
      expect(Validators.name('Ahmed Hassan'), isNull);
      expect(Validators.name("O'Brien-Smith"), isNull);
      expect(Validators.name('أحمد حسن'), isNull);
    });

    test('rejects digits and symbols', () {
      expect(Validators.name('Ahmed123'), isNotNull);
      expect(Validators.name('user@x'), isNotNull);
    });

    test('optional when required:false', () {
      expect(Validators.name('', required: false), isNull);
      expect(Validators.name('Ahmed7', required: false), isNotNull);
    });
  });

  group('Validators.address', () {
    test('accepts a reasonable address, rejects too-short', () {
      expect(Validators.address('12 Tahrir St, Cairo'), isNull);
      expect(Validators.address('x'), isNotNull);
    });
  });

  group('Validators.emergencyContact', () {
    test('requires a phone number within the value', () {
      expect(Validators.emergencyContact('Mom 01001234567'), isNull);
      expect(Validators.emergencyContact('Just a name'), isNotNull);
    });
  });

  group('Validators.email', () {
    test('accepts a valid email, rejects a non-email', () {
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
  });
}
