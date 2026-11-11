/// Utilidades de formato para pesos colombianos y fechas.
///
/// Se implementan sin dependencias externas para mantener el APK liviano y
/// garantizar el mismo resultado en cualquier dispositivo.
library;

const List<String> _months = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// Formatea un valor monetario: `1234.5` -> `$1.235`.
String money(num value, {bool withSymbol = true, int decimals = 0}) {
  final bool negative = value < 0;
  final String fixed = value.abs().toStringAsFixed(decimals);
  final List<String> parts = fixed.split('.');
  final String whole = parts.first;
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < whole.length; i++) {
    final int remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  final String decimalsPart = parts.length > 1 ? ',${parts[1]}' : '';
  final String symbol = withSymbol ? r'$' : '';
  return '${negative ? '-' : ''}$symbol$buffer$decimalsPart';
}

/// Interpreta montos escritos por el tendero: `2.450`, `2450`, `2.450,50`.
double? parseMoneyInput(String input) {
  final String cleaned =
      input.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// `12/07/2026`
String dateShort(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

/// `12 jul 2026`
String dateMedium(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// `12/07 · 03:45 p. m.`
String dateTimeLabel(DateTime date) {
  final int hour24 = date.hour;
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final String meridiem = hour24 < 12 ? 'a. m.' : 'p. m.';
  return '${_two(date.day)}/${_two(date.month)} · ${_two(hour12)}:${_two(date.minute)} $meridiem';
}

/// `hace 5 min`, `hace 2 h`, `ayer`, `hace 3 días`.
String relativeTime(DateTime date) {
  final Duration diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  if (diff.inDays < 30) return 'hace ${diff.inDays} días';
  return dateShort(date);
}

/// Iniciales para avatares: `Doña Marta` -> `DM`.
String initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// `8 productos` / `1 producto`.
String plural(int count, String singular, String pluralWord) =>
    '$count ${count == 1 ? singular : pluralWord}';

/// Agrupa un PIN de 6 dígitos: `482913` -> `482 913`.
String pinDisplay(String pin) {
  if (pin.length <= 3) return pin;
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < pin.length; i++) {
    if (i > 0 && i % 3 == 0) buffer.write(' ');
    buffer.write(pin[i]);
  }
  return buffer.toString();
}

/// Normaliza texto para búsquedas (sin tildes, minúsculas).
String normalizeText(String input) {
  const Map<String, String> replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final String lower = input.toLowerCase();
  final StringBuffer buffer = StringBuffer();
  for (final int rune in lower.runes) {
    final String char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}
