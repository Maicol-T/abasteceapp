import 'package:abasteceapp/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.normalizePhone', () {
    test('limpia separadores e indicativo', () {
      expect(Validators.normalizePhone('+57 300 123 4567'), '3001234567');
      expect(Validators.normalizePhone('300-123-4567'), '3001234567');
      expect(Validators.normalizePhone('573001234567'), '3001234567');
      expect(Validators.normalizePhone('03001234567'), '3001234567');
      expect(Validators.normalizePhone('abc'), '');
    });

    test('formatea en formato colombiano', () {
      expect(Validators.formatPhone('3001234567'), '+57 300 123 4567');
      expect(Validators.formatPhone('123'), '123');
    });
  });

  group('Validators.mobileError', () {
    test('acepta celulares colombianos de 10 dígitos', () {
      expect(Validators.mobileError('300 123 4567'), isNull);
      expect(Validators.isValidMobile('+57 318 555 7788'), isTrue);
    });

    test('explica el error de longitud y de prefijo', () {
      expect(Validators.mobileError(''), contains('Escribe'));
      expect(Validators.mobileError('300123'), contains('10 dígitos'));
      expect(Validators.mobileError('2001234567'), contains('empieza por 3'));
    });
  });

  group('Correo y contraseña', () {
    test('valida correos', () {
      expect(Validators.emailError('tucorreo@ejemplo.com'), isNull);
      expect(Validators.emailError('sin-arroba'), isNotNull);
      expect(Validators.emailError(''), contains('Escribe'));
    });

    test('exige 8 caracteres con letras y números', () {
      expect(Validators.passwordError('Abastece2026'), isNull);
      expect(Validators.passwordError('corta'), contains('8'));
      expect(Validators.passwordError('sololetras'), contains('letras'));
      expect(Validators.passwordError('12345678'), contains('letras'));
    });
  });

  group('Documentos colombianos', () {
    test('cédula de 6 a 10 dígitos', () {
      expect(Validators.idDocumentError('1.130.456.789'), isNull);
      expect(Validators.idDocumentError('123'), isNotNull);
      expect(Validators.idDocumentError(''), isNotNull);
    });

    test('NIT con dígito de verificación opcional', () {
      expect(Validators.nitError('900.456.123-4'), isNull);
      expect(Validators.nitError('900456123'), isNull);
      expect(Validators.nitError('123'), isNotNull);
      expect(Validators.nitError(''), contains('Escribe'));
    });

    test('RUT de 9 a 12 dígitos', () {
      expect(Validators.rutError('901.234.567-8'), isNull);
      expect(Validators.rutError('901234567'), isNull);
      expect(Validators.rutError('12'), isNotNull);
      expect(Validators.rutError(''), isNotNull);
    });
  });

  group('Validators.otpError', () {
    test('solo acepta 6 dígitos', () {
      expect(Validators.otpError('482913'), isNull);
      expect(Validators.otpError('48291'), contains('6 dígitos'));
      expect(Validators.otpError('abcdef'), contains('6 dígitos'));
    });
  });
}
