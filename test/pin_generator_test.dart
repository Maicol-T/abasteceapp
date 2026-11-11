import 'dart:math';

import 'package:abasteceapp/utils/pin_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinGenerator', () {
    test('genera 6 dígitos por defecto', () {
      final String pin = PinGenerator.generate();
      expect(pin.length, 6);
      expect(RegExp(r'^\d{6}$').hasMatch(pin), isTrue);
    });

    test('es determinista con un Random con semilla', () {
      final String first = PinGenerator.generate(random: Random(42));
      final String second = PinGenerator.generate(random: Random(42));
      expect(first, second);
    });

    test('respeta longitudes personalizadas', () {
      expect(PinGenerator.generate(length: 4, random: Random(1)).length, 4);
    });

    test('valida el formato de 6 dígitos', () {
      expect(PinGenerator.isValidFormat('482913'), isTrue);
      expect(PinGenerator.isValidFormat('48291'), isFalse);
      expect(PinGenerator.isValidFormat('48A913'), isFalse);
    });

    test('compara PIN ignorando espacios', () {
      expect(
        PinGenerator.matches(expected: '482913', input: ' 482913 '),
        isTrue,
      );
      expect(
          PinGenerator.matches(expected: '482913', input: '482914'), isFalse);
    });
  });
}
