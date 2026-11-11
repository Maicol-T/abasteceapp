import 'package:abasteceapp/services/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const VoiceCommandParser parser = VoiceCommandParser();

  group('VoiceCommandParser · intenciones', () {
    test('registra una venta con cantidad y producto', () {
      final VoiceCommand command = parser.parse('Véndeme 3 panelas');

      expect(command.intent, VoiceIntent.sell);
      expect(command.quantity, 3);
      expect(command.productQuery, contains('panela'));
      expect(command.confidence, greaterThan(0.5));
    });

    test('consulta el precio por libra de arroz', () {
      final VoiceCommand command =
          parser.parse('¿A cómo está la libra de arroz?');

      expect(command.intent, VoiceIntent.price);
      expect(command.productQuery, 'arroz');
      expect(command.quantity, isNull);
    });

    test('consulta existencias de aceite', () {
      final VoiceCommand command = parser.parse('¿Cuánto me queda de aceite?');

      expect(command.intent, VoiceIntent.stock);
      expect(command.productQuery, 'aceite');
    });

    test('arma un pedido mayorista', () {
      final VoiceCommand command = parser.parse('Pide 2 cajas de leche');

      expect(command.intent, VoiceIntent.order);
      expect(command.quantity, 2);
      expect(command.productQuery, 'leche');
    });

    test('detecta el cliente de un fiado', () {
      final VoiceCommand command = parser.parse('Abona el fiado de doña Marta');

      expect(command.intent, VoiceIntent.debt);
      expect(command.clientName, 'marta');
      expect(command.amount, isNull);
    });

    test('detecta abonos con monto en miles', () {
      final VoiceCommand command =
          parser.parse('Abona 20 mil del fiado de doña Marta');

      expect(command.intent, VoiceIntent.debt);
      expect(command.amount, 20000);
      expect(command.clientName, 'marta');
    });

    test('identifica productos por agotarse', () {
      final VoiceCommand command = parser.parse('¿Qué se está agotando?');

      expect(command.intent, VoiceIntent.lowStock);
      expect(command.productQuery, isNull);
    });

    test('reconoce el resumen de ventas del día', () {
      final VoiceCommand command = parser.parse('¿Cuánto he vendido hoy?');

      expect(command.intent, VoiceIntent.salesReport);
    });

    test('usa el número escrito en palabras', () {
      final VoiceCommand command = parser.parse('Vende dos panela');

      expect(command.intent, VoiceIntent.sell);
      expect(command.quantity, 2);
    });

    test('devuelve unknown con texto vacío', () {
      final VoiceCommand command = parser.parse('   ');

      expect(command.intent, VoiceIntent.unknown);
      expect(command.rawText, isEmpty);
    });

    test('expone los datos entendidos para la interfaz', () {
      final VoiceCommand command = parser.parse('Véndeme 3 panelas');

      expect(command.understood['Cantidad'], '3');
      expect(command.understood['Intención'], 'Registrar venta');
    });

    test('los ejemplos simulados se interpretan correctamente', () {
      for (final String example in VoiceCommandParser.simulatedCommands) {
        final VoiceCommand command = parser.parse(example);
        expect(
          command.intent,
          isNot(VoiceIntent.unknown),
          reason: 'El ejemplo "$example" no fue entendido',
        );
      }
    });
  });
}
