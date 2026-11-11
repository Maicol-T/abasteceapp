import 'dart:math';

/// Generación y validación de PIN de seguridad de entrega.
///
/// El PIN se genera con [Random.secure] cuando está disponible para que no sea
/// predecible, y permite inyectar un generador con semilla en pruebas.
class PinGenerator {
  PinGenerator._();

  static const int defaultLength = 6;

  /// Devuelve un PIN numérico de [length] dígitos (puede iniciar en cero).
  static String generate({int length = defaultLength, Random? random}) {
    assert(length > 0 && length <= 12, 'Longitud de PIN no soportada');
    final Random generator = random ?? Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(generator.nextInt(10));
    }
    return buffer.toString();
  }

  /// Compara el PIN esperado contra lo digitado por el tendero.
  static bool matches({required String expected, required String input}) {
    return expected.trim() == input.trim();
  }

  /// Un PIN válido tiene exactamente 6 dígitos.
  static bool isValidFormat(String pin) =>
      RegExp(r'^\d{6}$').hasMatch(pin.trim());
}
