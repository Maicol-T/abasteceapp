import 'dart:math';

import '../constants/app_constants.dart';
import 'pin_generator.dart';

/// Código de retiro leído desde el QR o dictado en la bodega.
class PickupCode {
  const PickupCode({required this.code, required this.pin});

  /// Cuatro caracteres sin ambigüedad (`K7P2`).
  final String code;

  /// PIN de seguridad de 6 dígitos.
  final String pin;

  String get display => '$code · $pin';
}

/// Generación y lectura de los códigos de retiro en bodega.
///
/// El QR transporta un texto corto y autodescriptivo (12 caracteres) para que
/// quepa en una versión 1 de QR y para que el operario pueda digitar el código
/// si la cámara no funciona:
///
/// ```text
/// AB K7P2 482913
/// └┬┘ └─┬─┘ └──┬──┘
///  │    │      └── PIN de 6 dígitos
///  │    └───────── código de retiro
///  └────────────── prefijo AbasteceApp
/// ```
class PickupCodes {
  PickupCodes._();

  static const String prefix = 'AB';

  /// Alfabeto sin caracteres confundibles (sin O/0, I/1, L, S/5).
  static const String alphabet = 'ABCDEFGHJKLMNPQRTUVWXY2346789';

  static const String payloadPrefix = prefix;

  static String generateCode(
      {int length = AppConstants.pickupCodeLength, Random? random}) {
    final Random generator = random ?? Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(alphabet[generator.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  static String generatePin() => PinGenerator.generate();

  /// Texto que se dibuja en el QR y que se puede digitar en la bodega.
  static String buildPayload({required String code, required String pin}) {
    final String cleanCode = code.trim().toUpperCase();
    final String cleanPin = pin.trim();
    return '$prefix$cleanCode$cleanPin';
  }

  /// Valida el texto leído del QR o digitado a mano.
  ///
  /// Acepta el payload completo (`ABK7P2482913`) o el código y el PIN
  /// separados por espacio, guion o dos puntos.
  static PickupCode? parse(String raw) {
    final String value = raw.trim().toUpperCase().replaceAll(' ', '');
    if (value.isEmpty) return null;

    final String compact = value.replaceAll(RegExp(r'[-:.·]'), '');
    if (compact.startsWith(prefix)) {
      final String rest = compact.substring(prefix.length);
      if (rest.length ==
          AppConstants.pickupCodeLength + AppConstants.pickupPinLength) {
        final String code = rest.substring(0, AppConstants.pickupCodeLength);
        final String pin = rest.substring(AppConstants.pickupCodeLength);
        if (PinGenerator.isValidFormat(pin)) {
          return PickupCode(code: code, pin: pin);
        }
      }
    }

    // Formato manual: código de 4 caracteres + PIN de 6 dígitos.
    final RegExpMatch? match = RegExp(
      r'^([A-Z0-9]{4})(\d{6})$',
    ).firstMatch(compact);
    if (match != null) {
      return PickupCode(code: match.group(1)!, pin: match.group(2)!);
    }
    return null;
  }

  /// `true` si el texto ingresado identifica el retiro de [expectedPin] y
  /// [expectedCode] (se acepta el PIN solo, el código solo o el payload).
  static bool matches({
    required String expectedCode,
    required String expectedPin,
    required String input,
  }) {
    final String value = input.trim().toUpperCase().replaceAll(' ', '');
    if (value.isEmpty) return false;

    final PickupCode? parsed = parse(value);
    final String candidateCode = parsed?.code ?? value;
    final String candidatePin = parsed?.pin ?? value;

    if (candidateCode == expectedCode.trim().toUpperCase()) return true;
    return candidatePin == expectedPin.trim();
  }

  /// Payload corto y estable a partir del pedido (útil para pruebas).
  static String demoPayload({required String code, required String pin}) =>
      buildPayload(code: code, pin: pin);
}
