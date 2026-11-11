/// Datos de marca y reglas de negocio compartidas por toda la aplicación.
class AppInfo {
  AppInfo._();

  static const String name = 'AbasteceApp';
  static const String tagline = 'Tu tienda abastecida, con o sin internet';
  static const String city = 'Buenaventura, Valle del Cauca';
  static const String version = '1.2.0';
  static const String currencyCode = 'COP';

  /// Responsable del tratamiento de datos personales (Ley 1581 de 2012).
  static const String dataController = 'AbasteceApp S.A.S.';
  static const String dataProtectionEmail = 'datos@abasteceapp.co';
}

class AppConstants {
  AppConstants._();

  /// Umbral usado para alertar "por agotarse" en el inventario.
  static const int lowStockThreshold = 8;

  /// Barrios usados por la logística de última milla.
  static const List<String> neighborhoods = <String>[
    'El Centro',
    'Bellavista',
    'La Independencia',
    'El Cristal',
    'Comuna 12',
    'Zona Franca',
    'Mayolo',
    'Doce de Octubre',
  ];

  /// Categorías sugeridas al crear un producto nuevo.
  static const List<String> categories = <String>[
    'Granos',
    'Aceites',
    'Bebidas',
    'Aseo',
    'Enlatados',
    'Lácteos',
    'Snacks',
    'Panadería',
    'General',
  ];

  /// Unidades de venta típicas de una tienda de barrio.
  static const List<String> units = <String>[
    'unidad',
    'libra',
    'bulto',
    'caja',
    'docena',
    'paquete',
    'litro',
  ];

  /// Tarifa de referencia por zona para el despacho del mayorista (COP).
  ///
  /// Ya no se cobra a un transportador independiente: la bodega despacha con
  /// su propia flota y traslada el flete al pedido.
  static const Map<String, double> zoneFees = <String, double>{
    'El Centro': 3500,
    'Bellavista': 4500,
    'La Independencia': 4000,
    'El Cristal': 5000,
    'Comuna 12': 5500,
    'Zona Franca': 6000,
    'Mayolo': 5000,
    'Doce de Octubre': 4500,
  };

  static const double packageFee = 700;
  static const String defaultAddress = 'Calle 1 # 2-34, El Centro';
  static const String supportPhone = '+57 320 000 0000';

  // --- Logística de retiro en bodega ---
  static const String pickupWindow = 'Lunes a sábado · 7:00 a. m. a 4:00 p. m.';
  static const int pickupPinLength = 6;
  static const int pickupCodeLength = 4;
  static const int maxPickupAttempts = 5;

  // --- Flotas propias de los mayoristas (nada de conductores independientes) ---
  static const List<String> fleetNames = <String>[
    'Flota La Libertad',
    'Camión Bahía Verde',
    'Furgón El Pacífico',
    'Ruta Río Dagua',
  ];

  static const List<String> fleetPlates = <String>[
    'WXY 123',
    'JKL 908',
    'MNO 456',
    'PQR 771',
  ];

  // --- Autenticación rápida ---
  static const int otpLength = 6;
  static const int otpValidityMinutes = 5;
  static const int otpMaxAttempts = 3;

  // --- Límites de pago contra entrega (Ley 1581 no aplica aquí; es política
  // comercial de riesgo por nivel de verificación) ---
  static const double informalCashOnDeliveryLimit = 150000;
  static const double formalCashOnDeliveryLimit = 1200000;

  // --- API central (panel administrativo) ---
  /// URL de la API que comparte el panel web.
  ///
  /// Vacío = modo local simulado. En el teléfono se configura al compilar:
  /// `flutter build apk --dart-define=API_BASE_URL=http://192.168.1.10:8080`
  /// (o `http://10.0.2.2:8080` desde el emulador de Android).
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Tamaño del lote de sincronización por envío.
  static const int syncBatchSize = 300;
}
