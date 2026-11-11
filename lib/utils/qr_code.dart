import 'dart:convert';
import 'dart:math' as math;

/// Matriz de un código QR ya codificado.
class QrCode {
  QrCode({
    required this.version,
    required this.size,
    required this.modules,
    required this.mask,
  });

  final int version;
  final int size;

  /// `modules[fila][columna]`; `true` equivale a módulo oscuro.
  final List<List<bool>> modules;

  final int mask;

  bool isDark(int row, int column) => modules[row][column];

  /// Representación textual para pruebas y depuración.
  String toDebugString() {
    final StringBuffer buffer = StringBuffer();
    for (int row = 0; row < size; row++) {
      for (int column = 0; column < size; column++) {
        buffer.write(modules[row][column] ? '#' : '.');
      }
      if (row != size - 1) buffer.write('\n');
    }
    return buffer.toString();
  }
}

/// Codificador QR mínimo en Dart puro (versión 1, nivel de corrección L).
///
/// El proyecto es offline-first y no puede descargar `qr_flutter`; el pase de
/// retiro solo necesita una matriz pequeña para un texto de 12 caracteres, así
/// que se implementa el estándar ISO/IEC 18004 en su caso más simple:
///
/// * un único bloque Reed-Solomon (19 codewords de datos + 7 de corrección),
/// * modo byte con capacidad de 17 bytes,
/// * sin patrones de alineación (la versión 1 no los tiene).
///
/// El resultado se dibuja con `QrView` y puede leerse con cualquier lector QR
/// estándar.
class QrEncoder {
  QrEncoder._();

  static const int version = 1;
  static const int size = 21;

  /// Nivel de corrección L: 19 codewords de datos y 7 de corrección.
  static const int dataCodewords = 19;
  static const int eccCodewords = 7;
  static const int maxBytes = 17;

  /// `true` si el texto cabe en la versión 1 nivel L.
  static bool canEncode(String text) => utf8.encode(text).length <= maxBytes;

  static QrCode encode(String text) {
    final List<int> data = utf8.encode(text);
    if (data.length > maxBytes) {
      throw ArgumentError.value(
        text,
        'text',
        'El texto supera los $maxBytes bytes de un QR versión 1-L.',
      );
    }

    final List<List<bool>> modules = List<List<bool>>.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );
    final List<List<bool>> reserved = List<List<bool>>.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );

    void setFunction(int x, int y, bool dark) {
      modules[y][x] = dark;
      reserved[y][x] = true;
    }

    _drawFinderPattern(setFunction, 3, 3);
    _drawFinderPattern(setFunction, size - 4, 3);
    _drawFinderPattern(setFunction, 3, size - 4);

    for (int i = 0; i < size; i++) {
      setFunction(6, i, i % 2 == 0);
      setFunction(i, 6, i % 2 == 0);
    }

    // El módulo oscuro fijo de la versión 1 está en (fila 13, columna 8).
    setFunction(8, size - 8, true);

    for (final List<int> position in _formatCoordinates()) {
      reserved[position[1]][position[0]] = true;
    }

    final List<int> codewords = _buildCodewords(data);
    _drawCodewords(modules, reserved, codewords);

    int bestMask = 0;
    int bestPenalty = 1 << 30;
    for (int mask = 0; mask < 8; mask++) {
      _applyMask(modules, reserved, mask);
      _drawFormatBits(modules, mask);
      final int penalty = _penaltyScore(modules);
      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        bestMask = mask;
      }
      _applyMask(modules, reserved, mask);
    }

    _applyMask(modules, reserved, bestMask);
    _drawFormatBits(modules, bestMask);

    return QrCode(
      version: version,
      size: size,
      modules: modules,
      mask: bestMask,
    );
  }

  // ---------------------------------------------------------------------------
  // Patrones fijos
  // ---------------------------------------------------------------------------

  static void _drawFinderPattern(
    void Function(int x, int y, bool dark) setFunction,
    int centerX,
    int centerY,
  ) {
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -4; dx <= 4; dx++) {
        final int x = centerX + dx;
        final int y = centerY + dy;
        if (x < 0 || x >= size || y < 0 || y >= size) continue;
        final int distance = math.max(dx.abs(), dy.abs());
        // Separador (distancia 4) y anillo interno (distancia 2) en blanco.
        setFunction(x, y, distance != 2 && distance != 4);
      }
    }
  }

  /// Posiciones (x, y) de las dos copias de la información de formato.
  static List<List<int>> _formatCoordinates() {
    final List<List<int>> positions = <List<int>>[
      <int>[8, 0],
      <int>[8, 1],
      <int>[8, 2],
      <int>[8, 3],
      <int>[8, 4],
      <int>[8, 5],
      <int>[8, 7],
      <int>[8, 8],
      <int>[7, 8],
      <int>[5, 8],
      <int>[4, 8],
      <int>[3, 8],
      <int>[2, 8],
      <int>[1, 8],
      <int>[0, 8],
    ];
    for (int i = 0; i < 8; i++) {
      positions.add(<int>[size - 1 - i, 8]);
    }
    for (int i = 8; i < 15; i++) {
      positions.add(<int>[8, size - 15 + i]);
    }
    return positions;
  }

  // ---------------------------------------------------------------------------
  // Codificación de datos y Reed-Solomon
  // ---------------------------------------------------------------------------

  static List<int> _buildCodewords(List<int> data) {
    final List<bool> bits = <bool>[];

    void addBits(int value, int count) {
      for (int i = count - 1; i >= 0; i--) {
        bits.add(((value >> i) & 1) == 1);
      }
    }

    addBits(0x4, 4); // Modo byte.
    addBits(data.length, 8); // Conteo: 8 bits en versiones 1 a 9.
    for (final int byte in data) {
      addBits(byte, 8);
    }

    const int capacityBits = dataCodewords * 8;
    for (int i = 0; i < 4 && bits.length < capacityBits; i++) {
      bits.add(false);
    }
    while (bits.length % 8 != 0) {
      bits.add(false);
    }

    final List<int> codewords = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      int byte = 0;
      for (int j = 0; j < 8; j++) {
        byte = (byte << 1) | (bits[i + j] ? 1 : 0);
      }
      codewords.add(byte);
    }

    int pad = 0xEC;
    while (codewords.length < dataCodewords) {
      codewords.add(pad);
      pad = pad == 0xEC ? 0x11 : 0xEC;
    }

    final List<int> divisor = _reedSolomonDivisor(eccCodewords);
    final List<int> ecc = _reedSolomonRemainder(codewords, divisor);
    return <int>[...codewords, ...ecc];
  }

  /// Coeficientes del polinomio generador ∏(x - α^i).
  static List<int> reedSolomonDivisor(int degree) =>
      _reedSolomonDivisor(degree);

  static List<int> _reedSolomonDivisor(int degree) {
    final List<int> result = List<int>.filled(degree, 0);
    result[degree - 1] = 1;
    int root = 1;
    for (int i = 0; i < degree; i++) {
      for (int j = 0; j < degree; j++) {
        result[j] = _multiply(result[j], root);
        if (j + 1 < degree) result[j] ^= result[j + 1];
      }
      root = _multiply(root, 0x02);
    }
    return result;
  }

  static List<int> _reedSolomonRemainder(List<int> data, List<int> divisor) {
    final List<int> result = List<int>.filled(
      divisor.length,
      0,
      growable: true,
    );
    for (final int byte in data) {
      final int factor = byte ^ result.removeAt(0);
      result.add(0);
      for (int i = 0; i < divisor.length; i++) {
        result[i] ^= _multiply(divisor[i], factor);
      }
    }
    return result;
  }

  /// Multiplicación en GF(256) con polinomio primitivo 0x11D.
  static int _multiply(int x, int y) {
    int z = 0;
    for (int i = 7; i >= 0; i--) {
      z = (z << 1) ^ ((z >> 7) * 0x11D);
      z ^= ((y >> i) & 1) * x;
    }
    return z & 0xFF;
  }

  // ---------------------------------------------------------------------------
  // Colocación de módulos
  // ---------------------------------------------------------------------------

  static void _drawCodewords(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    List<int> codewords,
  ) {
    int bitIndex = 0;
    final int totalBits = codewords.length * 8;

    for (int right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5; // La columna 6 es el patrón de sincronía.
      final bool upward = ((right + 1) & 2) == 0;
      for (int vert = 0; vert < size; vert++) {
        for (int j = 0; j < 2; j++) {
          final int x = right - j;
          final int y = upward ? size - 1 - vert : vert;
          if (reserved[y][x] || bitIndex >= totalBits) continue;
          final int byte = codewords[bitIndex >> 3];
          modules[y][x] = ((byte >> (7 - (bitIndex & 7))) & 1) == 1;
          bitIndex++;
        }
      }
    }
  }

  static void _applyMask(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    int mask,
  ) {
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (reserved[y][x]) continue;
        if (_maskBit(mask, x, y)) {
          modules[y][x] = !modules[y][x];
        }
      }
    }
  }

  static bool _maskBit(int mask, int x, int y) {
    switch (mask) {
      case 0:
        return (x + y) % 2 == 0;
      case 1:
        return y % 2 == 0;
      case 2:
        return x % 3 == 0;
      case 3:
        return (x + y) % 3 == 0;
      case 4:
        return (x ~/ 3 + y ~/ 2) % 2 == 0;
      case 5:
        return x * y % 2 + x * y % 3 == 0;
      case 6:
        return (x * y % 2 + x * y % 3) % 2 == 0;
      case 7:
        return ((x + y) % 2 + x * y % 3) % 2 == 0;
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Información de formato (BCH 15,5)
  // ---------------------------------------------------------------------------

  static void _drawFormatBits(List<List<bool>> modules, int mask) {
    // Nivel L = 01 en los bits de corrección de error.
    const int errorLevelBits = 1;
    final int data = (errorLevelBits << 3) | mask;
    int remainder = data;
    for (int i = 0; i < 10; i++) {
      remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537);
    }
    final int bits = ((data << 10) | remainder) ^ 0x5412;

    final List<List<int>> positions = _formatCoordinates();
    for (int i = 0; i < 15; i++) {
      final bool dark = ((bits >> i) & 1) == 1;
      // Primera copia (alrededor del patrón localizador superior izquierdo).
      modules[positions[i][1]][positions[i][0]] = dark;
      // Segunda copia (mitad derecha e inferior).
      modules[positions[15 + i][1]][positions[15 + i][0]] = dark;
    }
  }

  // ---------------------------------------------------------------------------
  // Puntuación de la máscara (reglas 1, 2 y 4 de la norma)
  // ---------------------------------------------------------------------------

  static int _penaltyScore(List<List<bool>> modules) {
    int penalty = 0;

    for (int y = 0; y < size; y++) {
      int run = 1;
      for (int x = 1; x < size; x++) {
        if (modules[y][x] == modules[y][x - 1]) {
          run++;
        } else {
          if (run >= 5) penalty += run - 2;
          run = 1;
        }
      }
      if (run >= 5) penalty += run - 2;
    }

    for (int x = 0; x < size; x++) {
      int run = 1;
      for (int y = 1; y < size; y++) {
        if (modules[y][x] == modules[y - 1][x]) {
          run++;
        } else {
          if (run >= 5) penalty += run - 2;
          run = 1;
        }
      }
      if (run >= 5) penalty += run - 2;
    }

    for (int y = 0; y < size - 1; y++) {
      for (int x = 0; x < size - 1; x++) {
        final bool color = modules[y][x];
        if (modules[y][x + 1] == color &&
            modules[y + 1][x] == color &&
            modules[y + 1][x + 1] == color) {
          penalty += 3;
        }
      }
    }

    int dark = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (modules[y][x]) dark++;
      }
    }
    const int total = size * size;
    final int deviation = (dark * 100 ~/ total - 50).abs();
    penalty += (deviation ~/ 5) * 10;

    return penalty;
  }
}
