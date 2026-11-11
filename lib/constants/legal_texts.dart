/// Marco legal colombiano de protección de datos personales aplicado a
/// AbasteceApp.
///
/// El texto se mantiene en el código (y no en la base) para que la versión
/// aceptada quede atada a la versión del binario. Cada vez que cambie el texto
/// debe incrementarse [policyVersion]: el registro de consentimiento guarda esa
/// versión y la app puede volver a pedir la autorización.
library;

class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalDocs {
  LegalDocs._();

  /// Versión vigente de los Términos y de la Política de Tratamiento.
  static const String policyVersion = '2.0.0';

  static const String termsTitle = 'Términos y Condiciones';
  static const String policyTitle =
      'Política de Tratamiento de Datos Personales';

  static const String consentIntro =
      'Autorizo de manera previa, expresa e informada a AbasteceApp S.A.S. para '
      'tratar mis datos personales conforme a la Ley 1581 de 2012, el Decreto '
      '1377 de 2013 y la presente política.';

  static const String consentPurpose =
      'Finalidad: validar mi identidad y la de mi negocio, gestionar pedidos, '
      'retiros y despachos, facturar, prevenir fraude y contactarme por '
      'WhatsApp, SMS o correo sobre el estado de mis compras.';

  static const String consentRights =
      'Como titular puedo conocer, actualizar, rectificar y suprimir mis datos, '
      'revocar la autorización y presentar quejas ante la Superintendencia de '
      'Industria y Comercio (SIC).';

  static const List<LegalSection> terms = <LegalSection>[
    LegalSection(
      title: '1. Qué es AbasteceApp',
      body: 'AbasteceApp es una plataforma que conecta bodegas mayoristas con '
          'comerciantes minoristas de Buenaventura para comprar, retirar o '
          'recibir mercancía. La app funciona sin conexión: los pedidos se '
          'guardan en el teléfono y se sincronizan cuando vuelve la señal.',
    ),
    LegalSection(
      title: '2. Cuenta y veracidad de la información',
      body:
          'El usuario se compromete a registrar datos veraces y a mantenerlos '
          'actualizados. La cédula, el RUT y la Cámara de Comercio se validan de '
          'forma diferida; un dato falso puede llevar a la suspensión de la '
          'cuenta y al reporte a las autoridades competentes.',
    ),
    LegalSection(
      title: '3. Roles y verificación',
      body: 'Los proveedores son personas jurídicas que acreditan NIT, '
          'representante legal, RUT y Cámara de Comercio. Los tenderos pueden '
          'operar en nivel 1 (informal, sin RUT, con cédula, foto del local y '
          'servicio público) o en nivel 2 (formal, con RUT y Cámara de '
          'Comercio). El nivel 1 tiene un límite de compra contra entrega.',
    ),
    LegalSection(
      title: '4. Precios, fletes y pagos',
      body: 'Los precios mayoristas y los fletes los define cada bodega. En el '
          'retiro en bodega no se cobra flete; en el despacho, la flota del '
          'mayorista cobra el flete indicado antes de confirmar el pedido. Los '
          'pagos contra entrega se limitan según el nivel de verificación.',
    ),
    LegalSection(
      title: '5. Entregas, QR y PIN',
      body:
          'En el retiro en bodega el tendero o su mensajero presentan el QR y '
          'el PIN de 6 dígitos generados por la app. Quien tenga ambos códigos '
          'se presume autorizado para retirar: el tendero debe custodiarlos. El '
          'PIN se regenera si se agota el número de intentos.',
    ),
    LegalSection(
      title: '6. Uso aceptable',
      body:
          'No se permite suplantar identidades, manipular documentos, revender '
          'la cuenta ni usar la plataforma para actividades ilícitas. El uso '
          'indebido del QR o del PIN puede generar bloqueo preventivo.',
    ),
    LegalSection(
      title: '7. Cambios',
      body: 'AbasteceApp puede actualizar estos términos. Si el cambio es '
          'sustancial se pedirá una nueva autorización de tratamiento de datos '
          'y quedará registrada con la nueva versión de la política.',
    ),
  ];

  static const List<LegalSection> dataPolicy = <LegalSection>[
    LegalSection(
      title: '1. Responsable del tratamiento',
      body:
          'AbasteceApp S.A.S., con domicilio en Buenaventura (Valle del Cauca), '
          'es el responsable del tratamiento. Canal de atención: '
          'datos@abasteceapp.co · +57 320 000 0000.',
    ),
    LegalSection(
      title: '2. Marco normativo',
      body: 'Esta política se emite en cumplimiento de la Ley 1581 de 2012 '
          '(Habeas Data), el Decreto 1377 de 2013, el Decreto Único 1074 de '
          '2015 y las directrices de la Superintendencia de Industria y '
          'Comercio.',
    ),
    LegalSection(
      title: '3. Datos que recolectamos',
      body: 'Identificación (nombre, cédula o NIT, RUT, Cámara de Comercio), '
          'contacto (celular, correo), ubicación del negocio (dirección, barrio), '
          'documentos de soporte del local, historial de pedidos y registro de '
          'la autorización (versión de la política, fecha y equipo desde el que '
          'se aceptó).',
    ),
    LegalSection(
      title: '4. Finalidades',
      body:
          '(i) autenticar al usuario y validar su rol; (ii) gestionar pedidos, '
          'retiros, despachos y fletes; (iii) facturar y cobrar; (iv) prevenir '
          'fraude y suplantación; (v) enviar códigos de verificación por SMS o '
          'WhatsApp; (vi) atender PQRS y requerimientos de autoridades.',
    ),
    LegalSection(
      title: '5. Autorización',
      body:
          'La autorización es previa, expresa e informada y se obtiene con una '
          'casilla que el usuario marca de forma voluntaria: nunca viene '
          'premarcada. Cada aceptación queda registrada en la tabla '
          'data_consent_logs como evidencia (artículo 9 de la Ley 1581).',
    ),
    LegalSection(
      title: '6. Derechos del titular',
      body: 'Conocer, actualizar, rectificar y suprimir los datos; solicitar '
          'prueba de la autorización; revocarla; oponerse a tratamientos '
          'facultativos y presentar quejas ante la SIC. Las solicitudes se '
          'responden en los términos de los artículos 14 y 15 de la Ley 1581 '
          '(10 y 15 días hábiles).',
    ),
    LegalSection(
      title: '7. Seguridad y conservación',
      body: 'Los datos se almacenan en el dispositivo del usuario y en los '
          'servidores de AbasteceApp cuando hay conexión. Se aplican controles '
          'de acceso, y la información se conserva mientras exista la relación '
          'comercial y durante los plazos legales aplicables.',
    ),
    LegalSection(
      title: '8. Datos sensibles y menores de edad',
      body:
          'AbasteceApp no solicita datos sensibles ni trata datos de menores de '
          'edad. Si un documento los incluyera, se eliminará en la revisión.',
    ),
    LegalSection(
      title: '9. Transferencias y encargados',
      body:
          'Para enviar OTP y notificaciones se usan proveedores de mensajería '
          'que actúan como encargados del tratamiento con obligaciones de '
          'confidencialidad. No se venden datos personales a terceros.',
    ),
    LegalSection(
      title: '10. Vigencia',
      body: 'Esta política rige desde su publicación. El usuario siempre puede '
          'consultar la versión aceptada en la pantalla de cuenta y revocar la '
          'autorización escribiendo a datos@abasteceapp.co.',
    ),
  ];

  /// Texto plano para correos, soportes y pruebas.
  static String get termsPlainText => terms
      .map((LegalSection section) => '${section.title}\n${section.body}')
      .join('\n\n');

  static String get dataPolicyPlainText => dataPolicy
      .map((LegalSection section) => '${section.title}\n${section.body}')
      .join('\n\n');

  static String get consentPlainText =>
      '$consentIntro\n\n$consentPurpose\n\n$consentRights';
}
