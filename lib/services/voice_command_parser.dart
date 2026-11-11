import '../utils/formatters.dart';

/// Intenciones comerciales que entiende el asistente.
enum VoiceIntent {
  sell,
  price,
  stock,
  order,
  debt,
  salesReport,
  lowStock,
  help,
  unknown,
}

/// Comando interpretado a partir de una frase del tendero.
class VoiceCommand {
  const VoiceCommand({
    required this.intent,
    required this.rawText,
    this.productQuery,
    this.quantity,
    this.amount,
    this.clientName,
    this.confidence = 0.65,
  });

  final VoiceIntent intent;
  final String rawText;
  final String? productQuery;
  final int? quantity;
  final double? amount;
  final String? clientName;
  final double confidence;

  String get intentLabel {
    switch (intent) {
      case VoiceIntent.sell:
        return 'Registrar venta';
      case VoiceIntent.price:
        return 'Consultar precio';
      case VoiceIntent.stock:
        return 'Consultar inventario';
      case VoiceIntent.order:
        return 'Armar pedido mayorista';
      case VoiceIntent.debt:
        return 'Cobrar fiado';
      case VoiceIntent.salesReport:
        return 'Resumen de ventas';
      case VoiceIntent.lowStock:
        return 'Alertas de stock';
      case VoiceIntent.help:
        return 'Ayuda';
      case VoiceIntent.unknown:
        return 'No entendido';
    }
  }

  /// Pares etiqueta/valor que la interfaz muestra como "esto entendí".
  Map<String, String> get understood {
    final Map<String, String> details = <String, String>{
      'Intención': intentLabel,
    };
    if (productQuery != null && productQuery!.isNotEmpty) {
      details['Producto'] = productQuery!;
    }
    if (quantity != null) {
      details['Cantidad'] = '$quantity';
    }
    if (amount != null) {
      details['Monto'] = money(amount!);
    }
    if (clientName != null && clientName!.isNotEmpty) {
      details['Cliente'] = clientName!;
    }
    return details;
  }
}

/// Parser de comandos de voz en español colombiano.
///
/// Es lógica pura (sin Flutter ni plugins) para poder probarla con pruebas
/// unitarias y para que el asistente funcione igual sin micrófono.
class VoiceCommandParser {
  const VoiceCommandParser();

  /// Frases de ejemplo que la interfaz ofrece para probar sin hablar.
  static const List<String> simulatedCommands = <String>[
    'Véndeme 3 panelas',
    '¿A cómo está la libra de arroz?',
    '¿Cuánto me queda de aceite?',
    'Pide 2 cajas de leche',
    'Abona el fiado de doña Marta',
    '¿Qué se está agotando?',
    '¿Cuánto he vendido hoy?',
  ];

  static const List<String> _helpPhrases = <String>[
    'ayuda',
    'comandos',
    'que puedo decir',
    'instrucciones',
    'como funciona',
  ];
  static const List<String> _lowStockPhrases = <String>[
    'agotando',
    'agotado',
    'agotados',
    'agotarse',
    'acabando',
    'bajo stock',
    'falta',
    'faltan',
    'por acabarse',
    'inventario bajo',
  ];
  static const List<String> _pricePhrases = <String>[
    'precio',
    'precios',
    'cuanto cuesta',
    'cuanto vale',
    'cuanto valen',
    'cuanto esta',
    'a como',
    'cotiza',
    'cotizame',
    'cotizacion',
    'vale',
  ];
  static const List<String> _debtPhrases = <String>[
    'fiado',
    'fiados',
    'fiada',
    'deuda',
    'deudas',
    'abona',
    'abonar',
    'abono',
    'aboname',
    'paga',
    'pagar',
    'pago',
    'presta',
    'prestamo',
    'me debe',
    'debe',
    'deben',
  ];
  static const List<String> _sellPhrases = <String>[
    'vende',
    'vendeme',
    'vendi',
    'vender',
    'vendes',
    'venta',
    'ventas',
    'cobra',
    'cobrar',
    'cobrame',
    'registra',
    'registrar',
    'factura',
    'facturar',
    'saca',
    'despacha',
    'despachar',
  ];
  static const List<String> _salesReportPhrases = <String>[
    'cuanto vendi',
    'cuanto he vendido',
    'cuanto llevo',
    'ventas de hoy',
    'resumen de ventas',
    'cierre de caja',
    'cierre',
  ];
  static const List<String> _orderPhrases = <String>[
    'pide',
    'pedir',
    'pideme',
    'pedido',
    'pedidos',
    'compra',
    'comprar',
    'compras',
    'abastece',
    'abastecer',
    'abasteceme',
    'ordena',
    'ordenar',
    'solicita',
    'solicitar',
    'encarga',
    'encargar',
  ];
  static const List<String> _stockPhrases = <String>[
    'stock',
    'inventario',
    'cuanto me queda',
    'cuanto queda',
    'cuantos quedan',
    'cuantas quedan',
    'cuanto tengo',
    'disponible',
    'disponibles',
    'hay',
    'tengo',
  ];

  static const Set<String> _fillers = <String>{
    'a',
    'abastece',
    'abasteceme',
    'abastecer',
    'abona',
    'aboname',
    'abonar',
    'abono',
    'acabar',
    'acabando',
    'agotado',
    'agotados',
    'agotando',
    'agotarse',
    'ahora',
    'al',
    'algo',
    'aqui',
    'ayuda',
    'bajo',
    'bodega',
    'bolsa',
    'bolsas',
    'buenas',
    'buenos',
    'bulto',
    'bultos',
    'caja',
    'cajas',
    'cierre',
    'cliente',
    'clienta',
    'cobra',
    'cobrame',
    'cobrar',
    'comercial',
    'como',
    'compra',
    'comprar',
    'compras',
    'con',
    'cotiza',
    'cotizacion',
    'cotizame',
    'cuando',
    'cuanta',
    'cuantas',
    'cuanto',
    'cuantos',
    'cuesta',
    'cuestan',
    'de',
    'debe',
    'deben',
    'del',
    'despacha',
    'despachar',
    'deuda',
    'deudas',
    'dias',
    'disponible',
    'disponibles',
    'distribuidora',
    'docena',
    'docenas',
    'don',
    'dona',
    'el',
    'ella',
    'en',
    'encarga',
    'encargar',
    'es',
    'esa',
    'ese',
    'esta',
    'estas',
    'este',
    'estos',
    'factura',
    'facturar',
    'falta',
    'faltan',
    'favor',
    'fiada',
    'fiado',
    'fiados',
    'gramo',
    'gramos',
    'ha',
    'han',
    'has',
    'hay',
    'he',
    'hola',
    'hoy',
    'instrucciones',
    'inventario',
    'kilo',
    'kilos',
    'la',
    'las',
    'le',
    'les',
    'libra',
    'libras',
    'litro',
    'litros',
    'lo',
    'los',
    'llevo',
    'me',
    'media',
    'medio',
    'mil',
    'mi',
    'mis',
    'mucho',
    'muy',
    'nada',
    'necesito',
    'noches',
    'nos',
    'o',
    'ordena',
    'ordenar',
    'para',
    'paquete',
    'paquetes',
    'paga',
    'pagar',
    'pago',
    'pedir',
    'pedido',
    'pedidos',
    'pero',
    'peso',
    'pesos',
    'pide',
    'pideme',
    'podrias',
    'por',
    'porfa',
    'porfavor',
    'precio',
    'precios',
    'presta',
    'prestamo',
    'puedes',
    'que',
    'queda',
    'quedan',
    'quedo',
    'quiero',
    'quisiera',
    'registra',
    'registrar',
    'resumen',
    'saca',
    'se',
    'senor',
    'senora',
    'senorita',
    'sin',
    'solicita',
    'solicitar',
    'stock',
    'su',
    'sus',
    'tardes',
    'te',
    'tengo',
    'tienes',
    'tu',
    'tus',
    'un',
    'una',
    'unas',
    'unidad',
    'unidades',
    'uno',
    'unos',
    'vale',
    'valen',
    'vende',
    'vendeme',
    'vender',
    'vendes',
    'vendi',
    'vendido',
    'venta',
    'ventas',
    'y',
    'ya',
  };

  static const Map<String, int> _wordNumbers = <String, int>{
    'un': 1,
    'una': 1,
    'uno': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veinticinco': 25,
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
  };

  VoiceCommand parse(String input) {
    final String raw = input.trim();
    if (raw.isEmpty) {
      return const VoiceCommand(intent: VoiceIntent.unknown, rawText: '');
    }

    final String text = _normalize(raw);
    final List<String> tokens = text
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);

    final VoiceIntent intent = _detectIntent(text, tokens);
    final bool isDebt = intent == VoiceIntent.debt;
    final bool countsQuantity =
        intent == VoiceIntent.sell || intent == VoiceIntent.order;
    final String? query = _extractQuery(tokens);

    return VoiceCommand(
      intent: intent,
      rawText: raw,
      productQuery: query,
      quantity: countsQuantity ? _extractQuantity(tokens) : null,
      amount: isDebt ? _extractAmount(text) : null,
      clientName: isDebt ? query : null,
      confidence: intent == VoiceIntent.unknown ? 0.2 : 0.85,
    );
  }

  static String _normalize(String input) {
    return normalizeText(input)
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  VoiceIntent _detectIntent(String text, List<String> tokens) {
    bool has(List<String> phrases) {
      for (final String phrase in phrases) {
        if (phrase.contains(' ')) {
          if (text.contains(phrase)) return true;
        } else if (tokens.contains(phrase)) {
          return true;
        }
      }
      return false;
    }

    if (has(_helpPhrases)) return VoiceIntent.help;
    if (has(_lowStockPhrases)) return VoiceIntent.lowStock;
    if (has(_salesReportPhrases)) return VoiceIntent.salesReport;
    if (has(_pricePhrases)) return VoiceIntent.price;
    if (has(_debtPhrases)) return VoiceIntent.debt;
    if (has(_sellPhrases)) return VoiceIntent.sell;
    if (has(_orderPhrases)) return VoiceIntent.order;
    if (has(_stockPhrases)) return VoiceIntent.stock;
    return VoiceIntent.unknown;
  }

  int? _extractQuantity(List<String> tokens) {
    for (final String token in tokens) {
      final int? number = int.tryParse(token);
      if (number != null && number > 0) return number;
    }
    for (final String token in tokens) {
      final int? number = _wordNumbers[token];
      if (number != null) return number;
    }
    return null;
  }

  double? _extractAmount(String text) {
    final RegExpMatch? match =
        RegExp(r'(\d+(?:[.,]\d+)?)\s*(mil|pesos|peso)?').firstMatch(text);
    if (match == null) return null;
    final String digits =
        (match.group(1) ?? '').replaceAll('.', '').replaceAll(',', '.');
    final double? value = double.tryParse(digits);
    if (value == null || value <= 0) return null;
    return match.group(2) == 'mil' ? value * 1000 : value;
  }

  String? _extractQuery(List<String> tokens) {
    final List<String> kept = <String>[];
    for (final String token in tokens) {
      if (_fillers.contains(token)) continue;
      if (_wordNumbers.containsKey(token)) continue;
      if (RegExp(r'^\d+$').hasMatch(token)) continue;
      kept.add(token);
    }
    final String query = kept.join(' ').trim();
    return query.isEmpty ? null : query;
  }
}
