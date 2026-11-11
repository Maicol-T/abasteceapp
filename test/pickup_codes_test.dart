import 'package:abasteceapp/utils/pickup_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickupCodes', () {
    test('genera códigos de 4 caracteres sin ambigüedades', () {
      final String code = PickupCodes.generateCode();
      expect(code.length, 4);
      for (final String char in code.split('')) {
        expect(PickupCodes.alphabet.contains(char), isTrue);
      }
    });

    test('construye el payload que viaja en el QR', () {
      final String payload = PickupCodes.buildPayload(
        code: 'K7P2',
        pin: '482913',
      );
      expect(payload, 'ABK7P2482913');
      expect(payload.length, 12);
    });

    test('lee el payload completo o el código y el PIN separados', () {
      final PickupCode? fromPayload = PickupCodes.parse('ABK7P2482913');
      expect(fromPayload?.code, 'K7P2');
      expect(fromPayload?.pin, '482913');

      final PickupCode? manual = PickupCodes.parse('K7P2-482913');
      expect(manual?.code, 'K7P2');
      expect(manual?.pin, '482913');
    });

    test('rechaza textos que no son códigos de retiro', () {
      expect(PickupCodes.parse(''), isNull);
      expect(PickupCodes.parse('7702001000011'), isNull);
      expect(PickupCodes.parse('ABK7P2'), isNull);
    });

    test('valida PIN, código o payload contra el retiro esperado', () {
      bool matches(String input) => PickupCodes.matches(
            expectedCode: 'K7P2',
            expectedPin: '482913',
            input: input,
          );

      expect(matches('482913'), isTrue);
      expect(matches('K7P2'), isTrue);
      expect(matches('ABK7P2482913'), isTrue);
      expect(matches('ab k7p2 482913'), isTrue);
      expect(matches('000000'), isFalse);
      expect(matches('ZZZZ'), isFalse);
    });
  });
}
