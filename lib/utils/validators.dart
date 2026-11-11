/// Validaciones de los formularios de autenticación y registro.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$',
  );

  /// Deja solo dígitos y descarta el indicativo 57 y el cero inicial.
  static String normalizePhone(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length > 10 && digits.startsWith('57')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Celular colombiano: 10 dígitos que empiezan por 3.
  static bool isValidMobile(String input) {
    final String digits = normalizePhone(input);
    return RegExp(r'^3\d{9}$').hasMatch(digits);
  }

  static String? mobileError(String input) {
    final String digits = normalizePhone(input);
    if (digits.isEmpty) return 'Escribe tu número de celular.';
    if (digits.length != 10) return 'El celular debe tener 10 dígitos.';
    if (!digits.startsWith('3')) {
      return 'El celular colombiano empieza por 3.';
    }
    return null;
  }

  /// Presentación legible: `3001234567` -> `+57 300 123 4567`.
  static String formatPhone(String input) {
    final String digits = normalizePhone(input);
    if (digits.length != 10) return input.trim();
    return '+57 ${digits.substring(0, 3)} ${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }

  static bool isValidEmail(String input) => _email.hasMatch(input.trim());

  static String? emailError(String input) {
    final String value = input.trim();
    if (value.isEmpty) return 'Escribe tu correo.';
    if (!isValidEmail(value)) return 'Ese correo no parece válido.';
    return null;
  }

  static String? passwordError(String input) {
    if (input.isEmpty) return 'Escribe una contraseña.';
    if (input.length < 8) return 'Usa al menos 8 caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(input) ||
        !RegExp(r'\d').hasMatch(input)) {
      return 'Combina letras y números.';
    }
    return null;
  }

  /// Código OTP de 6 dígitos.
  static bool isValidOtp(String input) =>
      RegExp(r'^\d{6}$').hasMatch(input.trim());

  static String? otpError(String input) {
    final String value = input.trim();
    if (value.isEmpty) return 'Escribe el código que recibiste.';
    if (!isValidOtp(value)) return 'El código tiene 6 dígitos.';
    return null;
  }

  /// Cédula de ciudadanía: entre 6 y 10 dígitos (sin puntos).
  static bool isValidIdDocument(String input) {
    final String digits = input.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 6 && digits.length <= 10;
  }

  static String? idDocumentError(String input) {
    if (input.trim().isEmpty) return 'Escribe la cédula.';
    if (!isValidIdDocument(input)) {
      return 'La cédula debe tener 6 a 10 dígitos.';
    }
    return null;
  }

  /// NIT: 9 o 10 dígitos, con guion de verificación opcional.
  static bool isValidNit(String input) {
    final String clean = input.trim().replaceAll('.', '').replaceAll(' ', '');
    return RegExp(r'^\d{9}(-\d)?$').hasMatch(clean);
  }

  static String? nitError(String input) {
    if (input.trim().isEmpty) return 'Escribe el NIT.';
    if (!isValidNit(input)) {
      return 'El NIT debe tener 9 dígitos y dígito de verificación.';
    }
    return null;
  }

  static String? requiredError(String input, String label) {
    if (input.trim().isEmpty) return 'Escribe $label.';
    if (input.trim().length < 3) return '$label es demasiado corto.';
    return null;
  }

  /// RUT: 9 a 12 dígitos con guion opcional.
  static String? rutError(String input) {
    final String clean = input.trim().replaceAll('.', '').replaceAll(' ', '');
    if (clean.isEmpty) return 'Escribe el número de RUT.';
    if (!RegExp(r'^\d{9,12}(-\d)?$').hasMatch(clean)) {
      return 'El RUT debe tener entre 9 y 12 dígitos.';
    }
    return null;
  }
}
