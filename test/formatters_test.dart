import 'package:abasteceapp/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('money', () {
    test('usa separador de miles colombiano', () {
      expect(money(1234), r'$1.234');
      expect(money(1234567), r'$1.234.567');
      expect(money(0), r'$0');
      expect(money(1234.9), r'$1.235');
    });

    test('permite omitir el símbolo', () {
      expect(money(2500, withSymbol: false), '2.500');
    });

    test('muestra valores negativos', () {
      expect(money(-5000), r'-$5.000');
    });

    test('formatea con decimales', () {
      expect(money(2450.5, decimals: 2), r'$2.450,50');
    });
  });

  group('parseMoneyInput', () {
    test('interpreta puntos de miles', () {
      expect(parseMoneyInput('2.450'), 2450);
      expect(parseMoneyInput('1.234.567'), 1234567);
    });

    test('interpreta coma decimal', () {
      expect(parseMoneyInput('2.450,50'), 2450.5);
    });

    test('devuelve null con texto vacío', () {
      expect(parseMoneyInput(''), isNull);
    });
  });

  group('fechas y textos', () {
    test('dateShort usa dd/MM/yyyy', () {
      expect(dateShort(DateTime(2026, 7, 12)), '12/07/2026');
    });

    test('dateTimeLabel incluye hora de 12 horas', () {
      expect(
        dateTimeLabel(DateTime(2026, 7, 12, 15, 45)),
        '12/07 · 03:45 p. m.',
      );
      expect(
        dateTimeLabel(DateTime(2026, 7, 12, 9, 5)),
        '12/07 · 09:05 a. m.',
      );
    });

    test('initials toma nombre y apellido', () {
      expect(initials('Doña Marta Riascos'), 'DR');
      expect(initials('Marta'), 'M');
      expect(initials(''), '?');
    });

    test('pinDisplay agrupa de tres en tres', () {
      expect(pinDisplay('482913'), '482 913');
      expect(pinDisplay('12'), '12');
    });

    test('normalizeText quita tildes y mayúsculas', () {
      expect(normalizeText('Véndeme 3 Panelas'), 'vendeme 3 panelas');
    });

    test('plural concuerda', () {
      expect(plural(1, 'producto', 'productos'), '1 producto');
      expect(plural(3, 'producto', 'productos'), '3 productos');
    });
  });
}
