import 'package:abasteceapp/utils/qr_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Multiplicación en GF(256) con el polinomio primitivo del estándar QR.
int _multiply(int x, int y) {
  int z = 0;
  for (int i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >> 7) * 0x11D);
    z ^= ((y >> i) & 1) * x;
  }
  return z & 0xFF;
}

/// α^exponente en GF(256).
int _alphaPow(int exponent) {
  int value = 1;
  for (int i = 0; i < exponent; i++) {
    value = _multiply(value, 0x02);
  }
  return value;
}

void main() {
  group('QrEncoder', () {
    test('genera una matriz de 21x21 para el pase de retiro', () {
      final QrCode code = QrEncoder.encode('ABK7P2482913');
      expect(code.version, 1);
      expect(code.size, 21);
      expect(code.modules.length, 21);
      expect(code.modules.every((List<bool> row) => row.length == 21), isTrue);
      expect(code.mask, inInclusiveRange(0, 7));
    });

    test('dibuja los tres patrones localizadores', () {
      final QrCode code = QrEncoder.encode('ABK7P2482913');
      for (final List<int> corner in <List<int>>[
        <int>[0, 0],
        <int>[14, 0],
        <int>[0, 14],
      ]) {
        final int x0 = corner[0];
        final int y0 = corner[1];
        // Borde oscuro de 7x7.
        expect(code.isDark(y0, x0), isTrue);
        expect(code.isDark(y0, x0 + 6), isTrue);
        expect(code.isDark(y0 + 6, x0), isTrue);
        // Anillo blanco interior.
        expect(code.isDark(y0 + 1, x0 + 1), isFalse);
        expect(code.isDark(y0 + 1, x0 + 5), isFalse);
        // Centro sólido de 3x3.
        expect(code.isDark(y0 + 2, x0 + 2), isTrue);
        expect(code.isDark(y0 + 4, x0 + 4), isTrue);
      }
    });

    test('respeta separadores y patrón de sincronía', () {
      final QrCode code = QrEncoder.encode('ABK7P2482913');
      // Separadores blancos junto a los localizadores.
      for (int i = 0; i < 8; i++) {
        expect(code.isDark(i, 7), isFalse);
        expect(code.isDark(7, i), isFalse);
      }
      // Patrón de sincronía: alterna oscuro/claro desde la columna 8.
      for (int i = 8; i < 13; i++) {
        expect(code.isDark(6, i), i.isEven);
        expect(code.isDark(i, 6), i.isEven);
      }
      // Módulo oscuro fijo de la versión 1.
      expect(code.isDark(13, 8), isTrue);
    });

    test('es determinista para el mismo texto', () {
      final QrCode first = QrEncoder.encode('ABK7P2482913');
      final QrCode second = QrEncoder.encode('ABK7P2482913');
      expect(first.toDebugString(), second.toDebugString());
    });

    test('controla la capacidad de 17 bytes del nivel L', () {
      expect(QrEncoder.canEncode('ABK7P2482913'), isTrue);
      expect(QrEncoder.canEncode('x' * 17), isTrue);
      expect(QrEncoder.canEncode('x' * 18), isFalse);
      expect(
        () => QrEncoder.encode('x' * 18),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('el polinomio generador coincide con el estándar', () {
      // Coeficientes de ∏(x - α^i) para 7 codewords de corrección.
      const List<int> expectedExponents = <int>[
        87,
        229,
        146,
        149,
        238,
        102,
        21,
      ];
      final List<int> divisor = QrEncoder.reedSolomonDivisor(7);
      expect(divisor.length, 7);
      for (int i = 0; i < divisor.length; i++) {
        expect(divisor[i], _alphaPow(expectedExponents[i]));
      }
    });
  });
}
