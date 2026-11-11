import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// SHA-256 y PBKDF2-HMAC-SHA256 en Dart puro.
///
/// La app es offline-first y no puede depender de paquetes externos para
/// autenticar: este módulo evita guardar contraseñas en claro en SQLite.
///
/// Las constantes de ronda se derivan en tiempo de ejecución (raíces cúbicas de
/// los primeros 64 primos) en lugar de copiarse a mano, lo que reduce el riesgo
/// de errores de transcripción y permite verificar el algoritmo con los
/// vectores oficiales en las pruebas.
class Sha256 {
  Sha256._();

  static const int _mask = 0xFFFFFFFF;
  static List<int>? _roundConstants;
  static List<int>? _initialState;

  /// Resumen SHA-256 de [message] (32 bytes).
  static Uint8List digest(List<int> message) {
    final List<int> h = List<int>.of(_h());
    final List<int> k = _k();

    final int bitLength = message.length * 8;
    final List<int> padded = List<int>.of(message)..add(0x80);
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    for (int i = 7; i >= 0; i--) {
      padded.add((bitLength >> (i * 8)) & 0xFF);
    }

    final List<int> w = List<int>.filled(64, 0);
    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        final int offset = chunk + i * 4;
        w[i] = (padded[offset] << 24) |
            (padded[offset + 1] << 16) |
            (padded[offset + 2] << 8) |
            padded[offset + 3];
      }
      for (int i = 16; i < 64; i++) {
        final int s0 =
            _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final int s1 =
            _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask;
      }

      int a = h[0];
      int b = h[1];
      int c = h[2];
      int d = h[3];
      int e = h[4];
      int f = h[5];
      int g = h[6];
      int hh = h[7];

      for (int i = 0; i < 64; i++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ ((~e & _mask) & g);
        final int t1 = (hh + s1 + ch + k[i] + w[i]) & _mask;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int t2 = (s0 + maj) & _mask;

        hh = g;
        g = f;
        f = e;
        e = (d + t1) & _mask;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & _mask;
      }

      h[0] = (h[0] + a) & _mask;
      h[1] = (h[1] + b) & _mask;
      h[2] = (h[2] + c) & _mask;
      h[3] = (h[3] + d) & _mask;
      h[4] = (h[4] + e) & _mask;
      h[5] = (h[5] + f) & _mask;
      h[6] = (h[6] + g) & _mask;
      h[7] = (h[7] + hh) & _mask;
    }

    final Uint8List out = Uint8List(32);
    for (int i = 0; i < 8; i++) {
      out[i * 4] = (h[i] >> 24) & 0xFF;
      out[i * 4 + 1] = (h[i] >> 16) & 0xFF;
      out[i * 4 + 2] = (h[i] >> 8) & 0xFF;
      out[i * 4 + 3] = h[i] & 0xFF;
    }
    return out;
  }

  /// HMAC-SHA256 con bloque de 64 bytes.
  static Uint8List hmac(List<int> key, List<int> message) {
    List<int> normalized = key;
    if (normalized.length > 64) normalized = digest(normalized);
    final List<int> inner = List<int>.filled(64, 0);
    final List<int> outer = List<int>.filled(64, 0);
    for (int i = 0; i < 64; i++) {
      final int byte = i < normalized.length ? normalized[i] : 0;
      inner[i] = byte ^ 0x36;
      outer[i] = byte ^ 0x5C;
    }
    return digest(<int>[
      ...outer,
      ...digest(<int>[...inner, ...message])
    ]);
  }

  /// PBKDF2-HMAC-SHA256 con longitud de clave de 32 bytes (un bloque).
  static Uint8List pbkdf2({
    required String password,
    required String salt,
    int iterations = 1200,
  }) {
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'Debe ser >= 1');
    }
    final List<int> passwordBytes = utf8.encode(password);
    final List<int> saltBytes = utf8.encode(salt);
    Uint8List u = hmac(passwordBytes, <int>[...saltBytes, 0, 0, 0, 1]);
    final Uint8List result = Uint8List.fromList(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac(passwordBytes, u);
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static int _rotr(int value, int shift) =>
      ((value >> shift) | (value << (32 - shift))) & _mask;

  static List<int> _h() {
    return _initialState ??= <int>[
      for (int i = 1; i <= 8; i++)
        (_isqrt(BigInt.from(_prime(i)) << 64) & BigInt.from(_mask)).toInt(),
    ];
  }

  static List<int> _k() {
    return _roundConstants ??= <int>[
      for (int i = 1; i <= 64; i++)
        (_icbrt(BigInt.from(_prime(i)) << 96) & BigInt.from(_mask)).toInt(),
    ];
  }

  /// N-ésimo primo (1 = 2).
  static int _prime(int index) {
    int candidate = 1;
    int found = 0;
    while (found < index) {
      candidate++;
      if (_isPrimeNumber(candidate)) found++;
    }
    return candidate;
  }

  static bool _isPrimeNumber(int value) {
    if (value < 2) return false;
    for (int divisor = 2; divisor * divisor <= value; divisor++) {
      if (value % divisor == 0) return false;
    }
    return true;
  }

  /// Raíz cuadrada entera por método de Newton.
  static BigInt _isqrt(BigInt value) {
    BigInt x = BigInt.one << ((value.bitLength ~/ 2) + 2);
    while (true) {
      final BigInt next = (x + value ~/ x) >> 1;
      if (next >= x) break;
      x = next;
    }
    return x;
  }

  /// Raíz cúbica entera por método de Newton.
  static BigInt _icbrt(BigInt value) {
    BigInt x = BigInt.one << ((value.bitLength ~/ 3) + 2);
    while (true) {
      final BigInt next = (x * BigInt.two + value ~/ (x * x)) ~/ BigInt.from(3);
      if (next >= x) break;
      x = next;
    }
    return x;
  }
}

/// Utilidades hexadecimales compartidas por el hash y el generador de sal.
class Hex {
  Hex._();

  static const String _digits = '0123456789abcdef';

  static String encode(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.write(_digits[(byte >> 4) & 0x0F]);
      buffer.write(_digits[byte & 0x0F]);
    }
    return buffer.toString();
  }

  static Uint8List decode(String text) {
    final String clean = text.trim();
    if (clean.length.isOdd) {
      throw ArgumentError.value(text, 'text', 'Longitud hexadecimal impar');
    }
    final Uint8List out = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// Derivación y verificación de contraseñas locales.
///
/// En producción la autenticación con contraseña debe hacerse contra el
/// backend (Argon2/bcrypt del lado servidor). Aquí se usa PBKDF2-SHA256 con sal
/// por usuario y 1200 iteraciones: suficiente para no guardar la contraseña en
/// claro en la base local del teléfono.
class PasswordHasher {
  PasswordHasher._();

  static const int iterations = 1200;
  static const int saltBytes = 16;

  static String generateSalt([Random? random]) {
    final Random generator = random ?? Random.secure();
    final Uint8List salt = Uint8List(saltBytes);
    for (int i = 0; i < saltBytes; i++) {
      salt[i] = generator.nextInt(256);
    }
    return Hex.encode(salt);
  }

  static String derive(String password, String salt) {
    return Hex.encode(
      Sha256.pbkdf2(
        password: password,
        salt: salt,
        iterations: iterations,
      ),
    );
  }

  static bool verify({
    required String password,
    required String salt,
    required String hash,
  }) {
    final String candidate = derive(password, salt);
    return constantTimeEquals(candidate, hash);
  }

  /// Comparación en tiempo constante para no filtrar el hash por temporización.
  static bool constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    int diff = 0;
    for (int i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }
}
