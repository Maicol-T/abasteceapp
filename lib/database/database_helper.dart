import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../constants/legal_texts.dart';
import '../data/seed_data.dart';
import '../models/admin_sync.dart';
import '../models/cart_line.dart';
import '../models/consent_log.dart';
import '../models/debt.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/otp_challenge.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/store_profile.dart';
import '../models/supplier.dart';
import '../models/supplier_profile.dart';
import '../models/sync_status.dart';
import '../models/user.dart';
import '../utils/pickup_codes.dart';
import '../utils/pin_generator.dart';
import '../utils/sha256.dart';
import '../utils/validators.dart';

/// Error de negocio con mensaje listo para mostrar al tendero.
class BusinessException implements Exception {
  const BusinessException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Error específico de existencias insuficientes.
class StockException extends BusinessException {
  const StockException(super.message);
}

/// Error de autenticación (credenciales, OTP vencido, cuenta bloqueada).
class AuthException extends BusinessException {
  const AuthException(super.message);
}

/// Administrador único de la base de datos local SQLite.
///
/// Estrategia offline-first: toda operación de negocio se escribe primero aquí
/// con `sync_status = 'pending'` y luego un proceso de sincronización la marca
/// como enviada. La app nunca depende de la red para vender, fiar o pedir.
///
/// Esquema v3: además del catálogo y las ventas agrega identidad (`users`),
/// evidencia de Habeas Data (`data_consent_logs`), perfiles verificables
/// (`suppliers` extendida y `stores`), retos OTP, la sesión persistida y la
/// **cola de sincronización por registro** en cada tabla de negocio
/// (`sync_status`, `synced_at`, `sync_error`, `sync_attempts`, `updated_at`).
class DatabaseHelper {
  DatabaseHelper._internal();

  /// Instancia compartida por toda la aplicación.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String databaseName = 'abasteceapp.db';

  /// v1: catálogo, pedidos, ventas y fiados.
  /// v2: autenticación, consentimiento, roles y logística de retiro/despacho.
  /// v3: cola de sincronización por registro (`sync_status`).
  /// v4: identidad estable del dispositivo para la API central.
  static const int schemaVersion = 4;

  Database? _database;
  Future<Database>? _opening;

  /// Base de datos abierta y con el esquema listo (se abre una sola vez).
  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null) return existing;
    _opening ??= _open();
    return _opening!;
  }

  Future<Database> _open() async {
    final String path = p.join(await getDatabasesPath(), databaseName);
    final Database db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createSchema(db);
        await _seed(db);
        await _seedDemoAccount(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }
        if (oldVersion < 3) {
          await _migrateToV3(db);
        }
        if (oldVersion < 4) {
          await _migrateToV4(db);
        }
      },
    );
    _database = db;
    return db;
  }

  /// Cierra la conexión (útil en pruebas y al cerrar sesión).
  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    _opening = null;
    await db?.close();
  }

  // ---------------------------------------------------------------------------
  // Esquema
  // ---------------------------------------------------------------------------

  Future<void> _createSchema(DatabaseExecutor db) async {
    // --- Identidad ---
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT UNIQUE,
        email TEXT UNIQUE,
        auth_provider TEXT NOT NULL DEFAULT 'correo',
        role TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        display_name TEXT,
        password_hash TEXT,
        password_salt TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_login_at TEXT
      )
    ''');

    // --- Evidencia de Habeas Data (Ley 1581 de 2012, art. 9) ---
    await db.execute('''
      CREATE TABLE data_consent_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        role TEXT,
        accepted_terms INTEGER NOT NULL DEFAULT 1,
        policy_version TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        device_ip TEXT NOT NULL DEFAULT '',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // --- Tendero / comerciante minorista con verificación en 2 niveles ---
    await db.execute('''
      CREATE TABLE stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        owner_name TEXT NOT NULL,
        id_document TEXT NOT NULL,
        business_name TEXT NOT NULL,
        address TEXT NOT NULL,
        zone TEXT NOT NULL,
        verification_level INTEGER NOT NULL DEFAULT 1,
        rut_number TEXT,
        status TEXT NOT NULL DEFAULT 'pending_verification',
        photo_path TEXT,
        utility_bill_path TEXT,
        chamber_path TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // --- Directorio mayorista + datos legales del proveedor ---
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        neighborhood TEXT NOT NULL DEFAULT '',
        rating REAL NOT NULL DEFAULT 0,
        delivery_fee REAL NOT NULL DEFAULT 0,
        minimum_order REAL NOT NULL DEFAULT 0,
        eta_minutes INTEGER NOT NULL DEFAULT 0,
        phone TEXT,
        user_id INTEGER,
        business_name TEXT NOT NULL DEFAULT '',
        nit TEXT NOT NULL DEFAULT '',
        legal_rep_name TEXT NOT NULL DEFAULT '',
        legal_rep_id TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        status_verified TEXT NOT NULL DEFAULT 'pending_approval',
        legal_rep_id_path TEXT,
        rut_path TEXT,
        chamber_path TEXT,
        created_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        wholesale_price REAL NOT NULL DEFAULT 0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        barcode TEXT,
        category TEXT NOT NULL DEFAULT 'General',
        supplier_id INTEGER NOT NULL DEFAULT 1,
        store_name TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT 'unidad',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      )
    ''');

    // --- Pedidos mayoristas con logística de retiro o despacho ---
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider_id INTEGER NOT NULL,
        provider_name TEXT NOT NULL DEFAULT '',
        total_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pendiente',
        is_synced INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        delivery_pin TEXT,
        created_at TEXT NOT NULL,
        store_id INTEGER,
        logistics_mode TEXT NOT NULL DEFAULT 'despacho',
        payment_method TEXT NOT NULL DEFAULT 'efectivo',
        pickup_code TEXT,
        qr_payload TEXT,
        dispatch_fee REAL NOT NULL DEFAULT 0,
        pickup_address TEXT,
        packages INTEGER NOT NULL DEFAULT 1,
        eta_minutes INTEGER NOT NULL DEFAULT 0,
        fleet_name TEXT,
        fleet_plate TEXT,
        delivered_at TEXT,
        pickup_attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'efectivo',
        is_synced INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_name TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pendiente',
        description TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        sync_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      )
    ''');

    // --- Verificación por SMS/WhatsApp (simulada en local) ---
    await db.execute('''
      CREATE TABLE otp_challenges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        code TEXT NOT NULL,
        purpose TEXT NOT NULL DEFAULT 'login',
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        consumed INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // --- Sesión persistida: el usuario sigue logueado al reabrir la app ---
    await db.execute('''
      CREATE TABLE local_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // --- Identidad estable del dispositivo ante la API central ---
    await db.execute('''
      CREATE TABLE sync_device (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        device_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
        'CREATE INDEX idx_products_supplier ON products (supplier_id)');
    await db.execute(
        'CREATE INDEX idx_products_stock ON products (stock_quantity)');
    await db.execute(
      'CREATE UNIQUE INDEX idx_products_barcode ON products (barcode) '
      'WHERE barcode IS NOT NULL',
    );
    await db.execute('CREATE INDEX idx_orders_synced ON orders (is_synced)');
    await db.execute('CREATE INDEX idx_orders_created ON orders (created_at)');
    await db.execute('CREATE INDEX idx_sales_synced ON sales (is_synced)');
    await db.execute('CREATE INDEX idx_sales_created ON sales (created_at)');
    await db.execute('CREATE INDEX idx_debts_status ON debts (status)');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_consent_user '
      'ON data_consent_logs (user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_consent_timestamp '
      'ON data_consent_logs (timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_store ON orders (store_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_mode ON orders (logistics_mode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_challenges (phone)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_user ON suppliers (user_id)',
    );
    await _createSyncIndexes(db);
  }

  /// Índices de la cola de sincronización: una tabla de negocio, un índice.
  ///
  /// La consulta de pendientes filtra por `sync_status <> 'synced'`; sin este
  /// índice cada envío recorrería la tabla completa.
  Future<void> _createSyncIndexes(DatabaseExecutor db) async {
    for (final SyncEntity entity in SyncEntity.values) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${entity.table}_sync '
        'ON ${entity.table} (sync_status)',
      );
    }
  }

  /// Migración v1 → v2 sin perder los datos del tendero.
  ///
  /// SQLite no permite agregar restricciones ni claves foráneas a columnas
  /// existentes: se agregan las columnas necesarias con valores por defecto y
  /// las tablas nuevas se crean completas.
  Future<void> _migrateToV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT UNIQUE,
        email TEXT UNIQUE,
        auth_provider TEXT NOT NULL DEFAULT 'correo',
        role TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        display_name TEXT,
        password_hash TEXT,
        password_salt TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_login_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS data_consent_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        role TEXT,
        accepted_terms INTEGER NOT NULL DEFAULT 1,
        policy_version TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        device_ip TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        owner_name TEXT NOT NULL,
        id_document TEXT NOT NULL,
        business_name TEXT NOT NULL,
        address TEXT NOT NULL,
        zone TEXT NOT NULL,
        verification_level INTEGER NOT NULL DEFAULT 1,
        rut_number TEXT,
        status TEXT NOT NULL DEFAULT 'pending_verification',
        photo_path TEXT,
        utility_bill_path TEXT,
        chamber_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS otp_challenges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        code TEXT NOT NULL,
        purpose TEXT NOT NULL DEFAULT 'login',
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        consumed INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // suppliers: datos legales del proveedor.
    await _ensureColumn(db, 'suppliers', 'user_id', 'INTEGER');
    await _ensureColumn(
        db, 'suppliers', 'business_name', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'suppliers', 'nit', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(
        db, 'suppliers', 'legal_rep_name', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(
        db, 'suppliers', 'legal_rep_id', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'suppliers', 'email', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(
      db,
      'suppliers',
      'status_verified',
      "TEXT NOT NULL DEFAULT 'pending_approval'",
    );
    await _ensureColumn(db, 'suppliers', 'legal_rep_id_path', 'TEXT');
    await _ensureColumn(db, 'suppliers', 'rut_path', 'TEXT');
    await _ensureColumn(db, 'suppliers', 'chamber_path', 'TEXT');
    await _ensureColumn(db, 'suppliers', 'created_at', 'TEXT');

    // orders: logística de retiro en bodega / despacho del mayorista.
    await _ensureColumn(db, 'orders', 'store_id', 'INTEGER');
    await _ensureColumn(
      db,
      'orders',
      'logistics_mode',
      "TEXT NOT NULL DEFAULT 'despacho'",
    );
    await _ensureColumn(
      db,
      'orders',
      'payment_method',
      "TEXT NOT NULL DEFAULT 'efectivo'",
    );
    await _ensureColumn(db, 'orders', 'pickup_code', 'TEXT');
    await _ensureColumn(db, 'orders', 'qr_payload', 'TEXT');
    await _ensureColumn(
        db, 'orders', 'dispatch_fee', 'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'orders', 'pickup_address', 'TEXT');
    await _ensureColumn(db, 'orders', 'packages', 'INTEGER NOT NULL DEFAULT 1');
    await _ensureColumn(
        db, 'orders', 'eta_minutes', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'orders', 'fleet_name', 'TEXT');
    await _ensureColumn(db, 'orders', 'fleet_plate', 'TEXT');
    await _ensureColumn(db, 'orders', 'delivered_at', 'TEXT');
    await _ensureColumn(
      db,
      'orders',
      'pickup_attempts',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _createIndexes(db);
    await _seedDemoAccount(db);
  }

  /// Agrega una columna solo si no existe (migraciones idempotentes).
  Future<void> _ensureColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final List<Map<String, Object?>> info =
        await db.rawQuery('PRAGMA table_info($table)');
    final bool exists = info.any(
      (Map<String, Object?> row) => row['name'] == column,
    );
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Migración v2 → v3: cola de sincronización por registro.
  ///
  /// Cada tabla de negocio recibe `sync_status` (TEXT, por defecto `pending`),
  /// `synced_at`, `sync_error`, `sync_attempts` y `updated_at`. Es idempotente:
  /// las columnas se agregan solo si faltan, y los registros que ya estaban
  /// marcados con `is_synced = 1` pasan a `sync_status = 'synced'` para que no
  /// se reenvíen al servidor.
  Future<void> _migrateToV3(Database db) async {
    for (final SyncEntity entity in SyncEntity.values) {
      await _ensureColumn(
        db,
        entity.table,
        'sync_status',
        "TEXT NOT NULL DEFAULT '${SyncStatus.pending.dbValue}'",
      );
      await _ensureColumn(db, entity.table, 'synced_at', 'TEXT');
      await _ensureColumn(db, entity.table, 'sync_error', 'TEXT');
      await _ensureColumn(
        db,
        entity.table,
        'sync_attempts',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn(db, entity.table, 'updated_at', 'TEXT');
    }

    // Los pedidos y ventas ya enviados en v2 no vuelven a la cola.
    for (final SyncEntity entity in <SyncEntity>[
      SyncEntity.order,
      SyncEntity.sale,
    ]) {
      await db.execute(
        "UPDATE ${entity.table} SET "
        "sync_status = '${SyncStatus.synced.dbValue}', "
        'synced_at = COALESCE(synced_at, created_at) '
        "WHERE is_synced = 1 AND sync_status = '${SyncStatus.pending.dbValue}'",
      );
      await db.execute(
        'UPDATE ${entity.table} '
        'SET updated_at = COALESCE(updated_at, created_at)',
      );
    }

    await _createSyncIndexes(db);
  }

  /// Migración v3 → v4: identidad estable del dispositivo.
  ///
  /// El panel necesita distinguir un teléfono de otro sin depender de datos
  /// personales: se guarda un identificador aleatorio creado una sola vez.
  Future<void> _migrateToV4(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_device (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        device_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seed(DatabaseExecutor db) async {
    final Batch batch = db.batch();
    for (final Supplier supplier in seedSuppliers) {
      batch.insert('suppliers', supplier.toMap());
    }
    for (final Product product in seedProducts) {
      batch.insert('products', product.toMap()..remove('id'));
    }
    for (final Debt debt in seedDebts()) {
      batch.insert('debts', debt.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  /// Siembra las cuentas de demostración (tendero formal y proveedor).
  ///
  /// Es idempotente: se ejecuta al crear la base y al migrar desde v1.
  Future<void> _seedDemoAccount(DatabaseExecutor db) async {
    final DateTime now = DateTime.now();

    // --- Tendero de nivel 2 ---
    int? storeUserId = await _userIdByEmail(db, DemoAccount.storeEmail);
    if (storeUserId == null) {
      final String salt = PasswordHasher.generateSalt();
      storeUserId = await db.insert('users', <String, Object?>{
        'phone': Validators.normalizePhone(DemoAccount.storePhone),
        'email': DemoAccount.storeEmail,
        'auth_provider': AuthProviderType.google.dbValue,
        'role': UserRole.store.dbValue,
        'is_active': 1,
        'display_name': DemoAccount.storeOwner,
        'password_hash': PasswordHasher.derive(DemoAccount.password, salt),
        'password_salt': salt,
        'onboarding_completed': 1,
        'created_at': now.subtract(const Duration(days: 120)).toIso8601String(),
        'last_login_at': null,
      });
      await db.insert('data_consent_logs', <String, Object?>{
        'user_id': storeUserId,
        'role': UserRole.store.dbValue,
        'accepted_terms': 1,
        'policy_version': LegalDocs.policyVersion,
        'timestamp': now.subtract(const Duration(days: 120)).toIso8601String(),
        'device_ip': '127.0.0.1',
      });
    }

    final List<Map<String, Object?>> existingStore = await db.query(
      'stores',
      where: 'user_id = ?',
      whereArgs: <Object?>[storeUserId],
      limit: 1,
    );
    if (existingStore.isEmpty) {
      await db.insert('stores', <String, Object?>{
        'user_id': storeUserId,
        'owner_name': DemoAccount.storeOwner,
        'id_document': DemoAccount.storeIdDocument,
        'business_name': DemoAccount.storeName,
        'address': DemoAccount.storeAddress,
        'zone': DemoAccount.storeZone,
        'verification_level': StoreVerificationLevel.formal.dbValue,
        'rut_number': DemoAccount.storeRut,
        'status': StoreVerificationStatus.verified.dbValue,
        'photo_path': 'demo/fachada_tienda.jpg',
        'utility_bill_path': 'demo/servicio_publico.pdf',
        'chamber_path': 'demo/camara_comercio.pdf',
        'created_at': now.subtract(const Duration(days: 110)).toIso8601String(),
      });
    }

    // --- Proveedor jurídico de la Bodega La Libertad ---
    int? supplierUserId = await _userIdByEmail(db, DemoAccount.supplierEmail);
    if (supplierUserId == null) {
      final String salt = PasswordHasher.generateSalt();
      supplierUserId = await db.insert('users', <String, Object?>{
        'phone': Validators.normalizePhone(DemoAccount.supplierPhone),
        'email': DemoAccount.supplierEmail,
        'auth_provider': AuthProviderType.email.dbValue,
        'role': UserRole.supplier.dbValue,
        'is_active': 1,
        'display_name': DemoAccount.supplierLegalRep,
        'password_hash': PasswordHasher.derive(DemoAccount.password, salt),
        'password_salt': salt,
        'onboarding_completed': 1,
        'created_at': now.subtract(const Duration(days: 90)).toIso8601String(),
      });
      await db.insert('data_consent_logs', <String, Object?>{
        'user_id': supplierUserId,
        'role': UserRole.supplier.dbValue,
        'accepted_terms': 1,
        'policy_version': LegalDocs.policyVersion,
        'timestamp': now.subtract(const Duration(days: 90)).toIso8601String(),
        'device_ip': '127.0.0.1',
      });
    }

    final List<Map<String, Object?>> bodega = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: <Object?>[1],
      limit: 1,
    );
    if (bodega.isNotEmpty && bodega.first['user_id'] == null) {
      await db.update(
        'suppliers',
        <String, Object?>{
          'user_id': supplierUserId,
          'business_name': DemoAccount.supplierBusiness,
          'nit': DemoAccount.supplierNit,
          'legal_rep_name': DemoAccount.supplierLegalRep,
          'legal_rep_id': DemoAccount.supplierLegalRepId,
          'email': DemoAccount.supplierEmail,
          'status_verified': SupplierVerificationStatus.pendingApproval.dbValue,
          'legal_rep_id_path': 'demo/cedula_rep_legal.pdf',
          'rut_path': 'demo/rut_bodega.pdf',
          'chamber_path': 'demo/camara_comercio_bodega.pdf',
          'created_at':
              now.subtract(const Duration(days: 80)).toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[1],
      );
    }
  }

  Future<int?> _userIdByEmail(DatabaseExecutor db, String email) async {
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      columns: <String>['id'],
      where: 'email = ?',
      whereArgs: <Object?>[email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  /// Borra los datos de la tienda y vuelve a cargar el catálogo de ejemplo.
  ///
  /// No elimina cuentas, consentimientos ni perfiles de verificación: esos son
  /// datos del titular y no del catálogo de demostración.
  Future<void> resetDemoData() async {
    final Database db = await database;
    await db.transaction<void>((Transaction txn) async {
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('sales');
      await txn.delete('debts');
      await txn.delete('products');
      await txn.delete('suppliers');
      await _seed(txn);
      await _seedDemoAccount(txn);
    });
  }

  // ---------------------------------------------------------------------------
  // Identidad: usuarios y sesión
  // ---------------------------------------------------------------------------

  Future<AppUser> insertUser(AppUser user) async {
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(user.toMap())
      ..remove('id');
    final int id = await db.insert('users', values);
    return user.copyWith(id: id);
  }

  Future<void> updateUser(AppUser user) async {
    final int? id = user.id;
    if (id == null) {
      throw const AuthException('La cuenta no tiene identificador.');
    }
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(user.toMap())
      ..remove('id');
    await db.update(
      'users',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<AppUser?> getUserById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> findUserByPhone(String phone) async {
    final String normalized = Validators.normalizePhone(phone);
    if (normalized.isEmpty) return null;
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'phone = ?',
      whereArgs: <Object?>[normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> findUserByEmail(String email) async {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: <Object?>[normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<int> usersCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS total FROM users');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> touchUserLogin(int userId, DateTime at) async {
    final Database db = await database;
    await db.update(
      'users',
      <String, Object?>{'last_login_at': at.toIso8601String()},
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
  }

  /// Guarda la sesión activa (una sola fila, `id = 1`).
  Future<void> saveSession(int userId, {DateTime? startedAt}) async {
    final Database db = await database;
    await db.insert(
      'local_session',
      <String, Object?>{
        'id': 1,
        'user_id': userId,
        'started_at': (startedAt ?? DateTime.now()).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> readSessionUserId() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'local_session',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['user_id'] as int?;
  }

  Future<void> clearSession() async {
    final Database db = await database;
    await db.delete('local_session');
  }

  // ---------------------------------------------------------------------------
  // OTP (simulación local del envío por SMS/WhatsApp)
  // ---------------------------------------------------------------------------

  Future<OtpChallenge> createOtpChallenge({
    required String phone,
    String purpose = 'login',
    String? code,
  }) async {
    final String normalized = Validators.normalizePhone(phone);
    if (normalized.isEmpty) {
      throw const AuthException('Escribe un número de celular válido.');
    }
    final Database db = await database;
    final DateTime now = DateTime.now();
    final OtpChallenge challenge = OtpChallenge(
      phone: normalized,
      code: code ?? PinGenerator.generate(),
      purpose: purpose,
      createdAt: now,
      expiresAt: now.add(
        const Duration(minutes: AppConstants.otpValidityMinutes),
      ),
    );
    final int id =
        await db.insert('otp_challenges', challenge.toMap()..remove('id'));
    return OtpChallenge(
      id: id,
      phone: challenge.phone,
      code: challenge.code,
      purpose: challenge.purpose,
      createdAt: challenge.createdAt,
      expiresAt: challenge.expiresAt,
    );
  }

  /// Último reto vigente para el celular (aún no consumido y sin vencer).
  Future<OtpChallenge?> latestOtpChallenge(String phone) async {
    final String normalized = Validators.normalizePhone(phone);
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'otp_challenges',
      where: 'phone = ? AND consumed = 0 AND expires_at > ?',
      whereArgs: <Object?>[
        normalized,
        DateTime.now().toIso8601String(),
      ],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OtpChallenge.fromMap(rows.first);
  }

  Future<void> incrementOtpAttempts(int challengeId) async {
    final Database db = await database;
    await db.rawUpdate(
      'UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?',
      <Object?>[challengeId],
    );
  }

  Future<void> consumeOtpChallenge(int challengeId) async {
    final Database db = await database;
    await db.update(
      'otp_challenges',
      <String, Object?>{'consumed': 1},
      where: 'id = ?',
      whereArgs: <Object?>[challengeId],
    );
  }

  Future<void> purgeExpiredOtps() async {
    final Database db = await database;
    await db.delete(
      'otp_challenges',
      where: 'expires_at < ?',
      whereArgs: <Object?>[DateTime.now().toIso8601String()],
    );
  }

  // ---------------------------------------------------------------------------
  // Consentimiento informado (Habeas Data)
  // ---------------------------------------------------------------------------

  Future<DataConsentLog> insertConsentLog(DataConsentLog log) async {
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(log.toMap())
      ..remove('id')
      ..addAll(pendingSyncColumns(at: log.timestamp));
    final int id = await db.insert('data_consent_logs', values);
    return DataConsentLog(
      id: id,
      userId: log.userId,
      role: log.role,
      acceptedTerms: log.acceptedTerms,
      policyVersion: log.policyVersion,
      timestamp: log.timestamp,
      deviceIp: log.deviceIp,
    );
  }

  Future<List<DataConsentLog>> consentLogsForUser(int userId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'data_consent_logs',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'timestamp DESC',
    );
    return rows
        .map((Map<String, Object?> row) => DataConsentLog.fromMap(row))
        .toList(growable: false);
  }

  Future<DataConsentLog?> latestConsentLog(int userId) async {
    final List<DataConsentLog> logs = await consentLogsForUser(userId);
    return logs.isEmpty ? null : logs.first;
  }

  // ---------------------------------------------------------------------------
  // Proveedores: datos legales y verificación diferida
  // ---------------------------------------------------------------------------

  /// Crea o actualiza el perfil jurídico del proveedor.
  ///
  /// La primera vez inserta la bodega en el directorio mayorista (misma fila,
  /// `status_verified = 'pending_approval'`); después solo actualiza sus datos
  /// legales.
  Future<SupplierProfile> saveSupplierProfile(
    SupplierProfile profile, {
    String? catalogName,
    String? neighborhood,
  }) async {
    final Database db = await database;
    final Map<String, Object?> legal = Map<String, Object?>.of(profile.toMap())
      ..remove('id');

    if (profile.id == null) {
      final String name = (catalogName ?? profile.businessName).trim();
      final int id = await db.insert('suppliers', <String, Object?>{
        'name': name.isEmpty ? 'Bodega sin nombre' : name,
        'neighborhood': (neighborhood ?? '').trim(),
        'rating': 0.0,
        'delivery_fee': 0.0,
        'minimum_order': 0.0,
        'eta_minutes': 0,
        'phone': profile.phone,
        ...legal,
        ...pendingSyncColumns(),
      });
      return profile.copyWith(id: id);
    }

    await db.update(
      'suppliers',
      <String, Object?>{...legal, ...pendingSyncColumns()},
      where: 'id = ?',
      whereArgs: <Object?>[profile.id],
    );
    return profile;
  }

  Future<SupplierProfile?> supplierProfileForUser(int userId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'suppliers',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SupplierProfile.fromMap(rows.first);
  }

  Future<List<SupplierProfile>> pendingSupplierProfiles() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'suppliers',
      where: 'status_verified = ? AND user_id IS NOT NULL',
      whereArgs: <Object?>[SupplierVerificationStatus.pendingApproval.dbValue],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((Map<String, Object?> row) => SupplierProfile.fromMap(row))
        .toList(growable: false);
  }

  Future<void> setSupplierVerification(
    int supplierId,
    SupplierVerificationStatus status,
  ) async {
    final Database db = await database;
    await db.update(
      'suppliers',
      <String, Object?>{
        'status_verified': status.dbValue,
        ...pendingSyncColumns(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[supplierId],
    );
  }

  // ---------------------------------------------------------------------------
  // Tenderos: perfil y verificación en 2 niveles
  // ---------------------------------------------------------------------------

  Future<StoreProfile> saveStoreProfile(StoreProfile profile) async {
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(profile.toMap())
      ..remove('id')
      ..addAll(pendingSyncColumns());
    final StoreProfile? existing = await storeProfileForUser(profile.userId);
    if (existing?.id != null) {
      await db.update(
        'stores',
        values,
        where: 'id = ?',
        whereArgs: <Object?>[existing!.id],
      );
      return profile.copyWith(id: existing.id);
    }
    final int id = await db.insert('stores', values);
    return profile.copyWith(id: id);
  }

  Future<StoreProfile?> storeProfileForUser(int userId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'stores',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoreProfile.fromMap(rows.first);
  }

  /// Sube al tendero a nivel 2 (formal) con RUT y Cámara de Comercio.
  Future<StoreProfile?> upgradeStoreToFormal({
    required int storeId,
    required String rutNumber,
    required String chamberPath,
  }) async {
    final Database db = await database;
    await db.update(
      'stores',
      <String, Object?>{
        'verification_level': StoreVerificationLevel.formal.dbValue,
        'rut_number': rutNumber.trim(),
        'chamber_path': chamberPath.trim(),
        'status': StoreVerificationStatus.pending.dbValue,
        ...pendingSyncColumns(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[storeId],
    );
    final List<Map<String, Object?>> rows = await db.query(
      'stores',
      where: 'id = ?',
      whereArgs: <Object?>[storeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoreProfile.fromMap(rows.first);
  }

  Future<void> setStoreStatus(
    int storeId,
    StoreVerificationStatus status,
  ) async {
    final Database db = await database;
    await db.update(
      'stores',
      <String, Object?>{
        'status': status.dbValue,
        ...pendingSyncColumns(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[storeId],
    );
  }

  Future<List<StoreProfile>> pendingStores() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'stores',
      where: 'status = ?',
      whereArgs: <Object?>[StoreVerificationStatus.pending.dbValue],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((Map<String, Object?> row) => StoreProfile.fromMap(row))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Catálogo mayorista (bodegas)
  // ---------------------------------------------------------------------------

  Future<List<Supplier>> getSuppliers() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'suppliers',
      orderBy: 'rating DESC',
    );
    return rows
        .map((Map<String, Object?> row) => Supplier.fromMap(row))
        .toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Productos / inventario
  // ---------------------------------------------------------------------------

  Future<List<Product>> getProducts({int? supplierId}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'products',
      where: supplierId == null ? null : 'supplier_id = ?',
      whereArgs: supplierId == null ? null : <Object?>[supplierId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((Map<String, Object?> row) => Product.fromMap(row))
        .toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final String term = query.trim();
    if (term.isEmpty) return getProducts();
    final Database db = await database;
    final String like = '%$term%';
    final List<Map<String, Object?>> rows = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ? OR category LIKE ?',
      whereArgs: <Object?>[like, like, like],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((Map<String, Object?> row) => Product.fromMap(row))
        .toList();
  }

  Future<Product?> getProductById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final String code = barcode.trim();
    if (code.isEmpty) return null;
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: <Object?>[code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  /// Productos con existencias iguales o por debajo del umbral.
  Future<List<Product>> getLowStockProducts({
    int threshold = AppConstants.lowStockThreshold,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'products',
      where: 'stock_quantity <= ?',
      whereArgs: <Object?>[threshold],
      orderBy: 'stock_quantity ASC',
    );
    return rows
        .map((Map<String, Object?> row) => Product.fromMap(row))
        .toList();
  }

  Future<Product> insertProduct(Product product) async {
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(product.toMap())
      ..remove('id')
      ..addAll(pendingSyncColumns());
    final int id = await db.insert('products', values);
    return product.copyWith(id: id);
  }

  Future<void> updateProduct(Product product) async {
    final int? id = product.id;
    if (id == null) {
      throw const BusinessException('El producto no tiene identificador.');
    }
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(product.toMap())
      ..remove('id')
      ..addAll(pendingSyncColumns());
    await db.update(
      'products',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final Database db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Ajusta el stock sumando [delta] (puede ser negativo) sin bajar de cero.
  Future<int> adjustStock(int productId, int delta) async {
    final Database db = await database;
    return db.transaction<int>((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        'products',
        columns: <String>['stock_quantity'],
        where: 'id = ?',
        whereArgs: <Object?>[productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const BusinessException('El producto ya no existe.');
      }
      final int current = rows.first['stock_quantity'] as int? ?? 0;
      final int updated = current + delta < 0 ? 0 : current + delta;
      await txn.update(
        'products',
        <String, Object?>{
          'stock_quantity': updated,
          ...pendingSyncColumns(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[productId],
      );
      return updated;
    });
  }

  // ---------------------------------------------------------------------------
  // Cola de sincronización (`sync_status` por registro)
  // ---------------------------------------------------------------------------

  /// Columnas que acompañan a toda escritura local pendiente de envío.
  ///
  /// Se mezclan con el `toMap()` del modelo para que la fila nazca en la cola:
  /// `sync_status = 'pending'`, sin error y con la fecha de la edición.
  static Map<String, Object?> pendingSyncColumns({DateTime? at}) {
    final DateTime now = at ?? DateTime.now();
    return <String, Object?>{
      'sync_status': SyncStatus.pending.dbValue,
      'sync_error': null,
      'updated_at': now.toIso8601String(),
    };
  }

  /// Devuelve un registro a la cola después de una edición local.
  Future<int> markPendingSync(SyncEntity entity, int id) async {
    final Database db = await database;
    return db.update(
      entity.table,
      <String, Object?>{
        ...pendingSyncColumns(),
        if (entity.mirrorsLegacyFlag) 'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Registros de [entity] que todavía no confirmó el servidor.
  Future<int> pendingSyncCount(SyncEntity entity) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${entity.table} '
      'WHERE ${SyncStatus.pendingSql}',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Total de la cola local (todas las tablas de negocio).
  Future<int> pendingSyncTotal() async {
    int total = 0;
    for (final SyncEntity entity in SyncEntity.values) {
      total += await pendingSyncCount(entity);
    }
    return total;
  }

  /// Pendientes por tabla: insumo de los paneles de sincronización.
  Future<Map<SyncEntity, int>> pendingSyncSummary() async {
    final Map<SyncEntity, int> summary = <SyncEntity, int>{};
    for (final SyncEntity entity in SyncEntity.values) {
      summary[entity] = await pendingSyncCount(entity);
    }
    return summary;
  }

  /// Registros pendientes, del más antiguo al más nuevo.
  ///
  /// Es la cola que consume `SyncService`: mezcla pedidos, ventas, productos,
  /// fiados, tiendas, proveedores y consentimientos en una sola lista.
  Future<List<SyncQueueItem>> pendingSyncQueue({int limit = 200}) async {
    final Database db = await database;
    final List<SyncQueueItem> items = <SyncQueueItem>[];
    for (final SyncEntity entity in SyncEntity.values) {
      final List<Map<String, Object?>> rows = await db.query(
        entity.table,
        columns: <String>[
          'id',
          'sync_status',
          'sync_attempts',
          'sync_error',
          'updated_at',
          'synced_at',
        ],
        where: SyncStatus.pendingSql,
        orderBy: 'id ASC',
        limit: limit,
      );
      items.addAll(
        rows.map(
          (Map<String, Object?> row) => SyncQueueItem.fromRow(entity, row),
        ),
      );
    }
    items.sort((SyncQueueItem a, SyncQueueItem b) {
      final DateTime left =
          a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime right =
          b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return left.compareTo(right);
    });
    return items.take(limit).toList(growable: false);
  }

  /// Aplica el resultado del envío a los registros indicados.
  ///
  /// * [SyncStatus.synced] guarda `synced_at` y limpia el error.
  /// * [SyncStatus.failed] conserva el mensaje y suma un intento.
  Future<int> applySyncResult({
    required SyncEntity entity,
    required List<int> ids,
    required SyncStatus status,
    String? error,
  }) async {
    if (ids.isEmpty) return 0;
    final Database db = await database;
    final String placeholders = List<String>.filled(ids.length, '?').join(', ');
    final bool synced = status == SyncStatus.synced;
    final Map<String, Object?> values = <String, Object?>{
      'sync_status': status.dbValue,
      if (synced) 'synced_at': DateTime.now().toIso8601String(),
      if (synced) 'sync_error': null,
      if (!synced) 'sync_error': error,
      if (entity.mirrorsLegacyFlag) 'is_synced': synced ? 1 : 0,
    };

    final int updated = await db.update(
      entity.table,
      values,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    if (!synced) {
      await db.rawUpdate(
        'UPDATE ${entity.table} '
        'SET sync_attempts = sync_attempts + 1 '
        'WHERE id IN ($placeholders)',
        ids,
      );
    }
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Contrato con la API central (panel administrativo)
  // ---------------------------------------------------------------------------

  /// Identificador estable de este teléfono ante la API central.
  ///
  /// Es aleatorio y se crea una sola vez: no contiene datos del usuario.
  Future<String> deviceId() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'sync_device',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['device_id'] as String;

    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer('dev-');
    for (int i = 0; i < 8; i += 1) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    final String id = buffer.toString();
    await db.insert(
      'sync_device',
      <String, Object?>{
        'id': 1,
        'device_id': id,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// Convierte la cola local en payloads listos para `POST /sync/push`.
  ///
  /// Se omite la metadata interna de sincronización; el servidor solo necesita
  /// el negocio y la fecha de la última edición.
  Future<List<SyncPayloadItem>> buildSyncPayloads(
    List<SyncQueueItem> queue,
  ) async {
    if (queue.isEmpty) return const <SyncPayloadItem>[];
    final Database db = await database;
    final Map<SyncEntity, List<int>> grouped = <SyncEntity, List<int>>{};
    for (final SyncQueueItem item in queue) {
      grouped.putIfAbsent(item.entity, () => <int>[]).add(item.id);
    }

    final List<SyncPayloadItem> payloads = <SyncPayloadItem>[];
    for (final MapEntry<SyncEntity, List<int>> entry in grouped.entries) {
      final List<int> ids = entry.value;
      final String placeholders =
          List<String>.filled(ids.length, '?').join(', ');
      final List<Map<String, Object?>> rows = await db.query(
        entry.key.table,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      for (final Map<String, Object?> row in rows) {
        final Map<String, Object?> payload = Map<String, Object?>.of(row)
          ..remove('sync_status')
          ..remove('synced_at')
          ..remove('sync_error')
          ..remove('sync_attempts')
          ..remove('updated_at');
        payloads.add(
          SyncPayloadItem(
            table: entry.key.table,
            localId: row['id'] as int? ?? 0,
            updatedAt: row['updated_at'] as String?,
            payload: payload,
          ),
        );
      }
    }
    return payloads;
  }

  /// Snapshot mínimo de identidad para la gestión de usuarios del panel.
  Future<List<Map<String, Object?>>> usersForSync() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query('users');
    return rows
        .map(
          (Map<String, Object?> row) => <String, Object?>{
            'localId': row['id'],
            'role': row['role'],
            'displayName': row['display_name'],
            'phone': row['phone'],
            'email': row['email'],
            'isActive': (row['is_active'] as int? ?? 1) == 1,
            'onboardingCompleted': (row['onboarding_completed'] as int? ?? 0) == 1,
            'createdAt': row['created_at'],
          },
        )
        .toList(growable: false);
  }

  /// Aplica la aprobación o el rechazo que decidió el panel.
  ///
  /// El registro queda `synced`: la decisión vino del servidor y no debe
  /// devolverse en la próxima cola.
  Future<int> applySupplierVerificationFromServer({
    required int supplierId,
    required String status,
  }) async {
    final Database db = await database;
    final String normalized = status == 'approved' ? 'approved' : 'rejected';
    return db.update(
      'suppliers',
      <String, Object?>{
        'status_verified': normalized,
        'sync_status': SyncStatus.synced.dbValue,
        'synced_at': DateTime.now().toIso8601String(),
        'sync_error': null,
      },
      where: 'id = ?',
      whereArgs: <Object?>[supplierId],
    );
  }

  /// Aplica la activación o desactivación de una cuenta desde el panel.
  Future<int> applyUserActiveFromServer({
    required int userId,
    required bool active,
  }) async {
    final Database db = await database;
    return db.update(
      'users',
      <String, Object?>{'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
  }

  // ---------------------------------------------------------------------------
  // Pedidos mayoristas y logística
  // ---------------------------------------------------------------------------

  /// Crea un pedido offline con su código de retiro o su despacho.
  ///
  /// En modo retiro se generan automáticamente el código corto, el PIN de 6
  /// dígitos y el payload del QR cuando no vienen dados.
  Future<Order> createOrder({
    required Supplier supplier,
    required List<CartLine> lines,
    required String deliveryPin,
    OrderStatus status = OrderStatus.confirmed,
    DateTime? createdAt,
    FulfillmentMode fulfillment = FulfillmentMode.dispatch,
    PaymentMethod payment = PaymentMethod.cash,
    String? pickupCode,
    String? qrPayload,
    double dispatchFee = 0,
    String? pickupAddress,
    int packages = 1,
    int etaMinutes = 0,
    String? fleetName,
    String? fleetPlate,
    int? storeId,
  }) async {
    if (lines.isEmpty) {
      throw const BusinessException('El pedido no tiene productos.');
    }
    final Database db = await database;
    final DateTime now = createdAt ?? DateTime.now();
    final double total = lines.fold<double>(
      0,
      (double sum, CartLine line) => sum + line.total,
    );

    final String? code = fulfillment.isPickup
        ? (pickupCode ?? PickupCodes.generateCode())
        : null;
    final String? payload = fulfillment.isPickup
        ? (qrPayload ?? PickupCodes.buildPayload(code: code!, pin: deliveryPin))
        : null;

    final int orderId = await db.transaction<int>((Transaction txn) async {
      final int id = await txn.insert('orders', <String, Object?>{
        'provider_id': supplier.id,
        'provider_name': supplier.name,
        'total_amount': total,
        'status': status.dbValue,
        'is_synced': 0,
        'sync_status': SyncStatus.pending.dbValue,
        'sync_error': null,
        'updated_at': now.toIso8601String(),
        'delivery_pin': deliveryPin,
        'created_at': now.toIso8601String(),
        'store_id': storeId,
        'logistics_mode': fulfillment.dbValue,
        'payment_method': payment.dbValue,
        'pickup_code': code,
        'qr_payload': payload,
        'dispatch_fee': dispatchFee,
        'pickup_address': pickupAddress ?? supplier.pickupAddress,
        'packages': packages,
        'eta_minutes': etaMinutes,
        'fleet_name': fleetName,
        'fleet_plate': fleetPlate,
        'delivered_at': null,
        'pickup_attempts': 0,
      });
      final Batch batch = txn.batch();
      for (final CartLine line in lines) {
        batch.insert('order_items', OrderLine.fromCartLine(line).toMap(id));
      }
      await batch.commit(noResult: true);
      return id;
    });

    return Order(
      id: orderId,
      providerId: supplier.id,
      providerName: supplier.name,
      totalAmount: total,
      status: status,
      deliveryPin: deliveryPin,
      createdAt: now,
      lines: lines
          .map((CartLine line) => OrderLine.fromCartLine(line))
          .toList(growable: false),
      fulfillment: fulfillment,
      payment: payment,
      pickupCode: code,
      qrPayload: payload,
      dispatchFee: dispatchFee,
      pickupAddress: pickupAddress ?? supplier.pickupAddress,
      packages: packages,
      etaMinutes: etaMinutes,
      fleetName: fleetName,
      fleetPlate: fleetPlate,
      storeId: storeId,
    );
  }

  Future<Order?> getOrderById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final List<Map<String, Object?>> itemRows = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: <Object?>[id],
      orderBy: 'id ASC',
    );
    return Order.fromMap(
      rows.first,
      lines: itemRows
          .map((Map<String, Object?> item) => OrderLine.fromMap(item))
          .toList(growable: false),
    );
  }

  Future<List<Order>> getOrders({int limit = 50}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'orders',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    final List<Order> orders = <Order>[];
    for (final Map<String, Object?> row in rows) {
      final int? orderId = row['id'] as int?;
      List<OrderLine> lines = const <OrderLine>[];
      if (orderId != null) {
        final List<Map<String, Object?>> itemRows = await db.query(
          'order_items',
          where: 'order_id = ?',
          whereArgs: <Object?>[orderId],
          orderBy: 'id ASC',
        );
        lines = itemRows
            .map((Map<String, Object?> item) => OrderLine.fromMap(item))
            .toList(growable: false);
      }
      orders.add(Order.fromMap(row, lines: lines));
    }
    return orders;
  }

  /// Pedidos de un tipo de logística (retiro o despacho).
  Future<List<Order>> getOrdersByFulfillment(
    FulfillmentMode mode, {
    int limit = 50,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'orders',
      where: 'logistics_mode = ?',
      whereArgs: <Object?>[mode.dbValue],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map((Map<String, Object?> row) => Order.fromMap(row))
        .toList(growable: false);
  }

  /// Pedidos que aún no se han enviado al servidor.
  Future<List<Order>> getPendingOrders() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'orders',
      where: SyncStatus.pendingSql,
      orderBy: 'created_at ASC',
    );
    return rows
        .map((Map<String, Object?> row) => Order.fromMap(row))
        .toList(growable: false);
  }

  Future<int> pendingOrdersCount() async =>
      pendingSyncCount(SyncEntity.order);

  Future<int> markOrdersSynced(List<int> ids) async {
    return applySyncResult(
      entity: SyncEntity.order,
      ids: ids,
      status: SyncStatus.synced,
    );
  }

  Future<int> updateOrderStatus(
    int orderId,
    OrderStatus status, {
    bool markUnsynced = true,
  }) async {
    final Database db = await database;
    return db.update(
      'orders',
      <String, Object?>{
        'status': status.dbValue,
        if (markUnsynced) ...<String, Object?>{
          'is_synced': 0,
          ...pendingSyncColumns(),
        },
      },
      where: 'id = ?',
      whereArgs: <Object?>[orderId],
    );
  }

  /// Actualiza el estado logístico del pedido (retiro o despacho).
  Future<int> updateShipmentStatus({
    required int orderId,
    required OrderStatus status,
    bool markUnsynced = true,
    DateTime? deliveredAt,
    int? pickupAttempts,
  }) async {
    final Database db = await database;
    return db.update(
      'orders',
      <String, Object?>{
        'status': status.dbValue,
        if (markUnsynced) ...<String, Object?>{
          'is_synced': 0,
          ...pendingSyncColumns(),
        },
        if (deliveredAt != null) 'delivered_at': deliveredAt.toIso8601String(),
        if (pickupAttempts != null) 'pickup_attempts': pickupAttempts,
      },
      where: 'id = ?',
      whereArgs: <Object?>[orderId],
    );
  }

  /// Incrementa el contador de intentos fallidos del código de retiro.
  Future<int> registerPickupAttempt(int orderId) async {
    final Database db = await database;
    await db.rawUpdate(
      "UPDATE orders SET pickup_attempts = pickup_attempts + 1, "
      "is_synced = 0, sync_status = '${SyncStatus.pending.dbValue}', "
      'sync_error = NULL, updated_at = ? '
      'WHERE id = ?',
      <Object?>[DateTime.now().toIso8601String(), orderId],
    );
    final List<Map<String, Object?>> rows = await db.query(
      'orders',
      columns: <String>['pickup_attempts'],
      where: 'id = ?',
      whereArgs: <Object?>[orderId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['pickup_attempts'] as int? ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Ventas locales (siempre sin conexión)
  // ---------------------------------------------------------------------------

  /// Registra una venta descontando stock en una sola transacción.
  ///
  /// Si [payment] es [PaymentMethod.credit] se crea automáticamente el fiado.
  Future<Sale> registerSale({
    required Product product,
    int quantity = 1,
    PaymentMethod payment = PaymentMethod.cash,
    String? clientName,
    DateTime? createdAt,
  }) async {
    final int? productId = product.id;
    if (productId == null) {
      throw const BusinessException('Guarda el producto antes de venderlo.');
    }
    if (quantity <= 0) {
      throw const StockException('La cantidad debe ser mayor a cero.');
    }
    final String client = (clientName ?? '').trim();
    if (payment == PaymentMethod.credit && client.isEmpty) {
      throw const BusinessException(
          'Para fiar necesitas el nombre del cliente.');
    }

    final Database db = await database;
    final DateTime now = createdAt ?? DateTime.now();

    return db.transaction<Sale>((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        'products',
        columns: <String>['stock_quantity', 'wholesale_price'],
        where: 'id = ?',
        whereArgs: <Object?>[productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const BusinessException(
            'El producto ya no existe en el inventario.');
      }
      final int stock = rows.first['stock_quantity'] as int? ?? 0;
      if (quantity > stock) {
        throw StockException(
          'Solo te quedan $stock ${product.unit}(s) de ${product.name}.',
        );
      }
      final double unitPrice =
          (rows.first['wholesale_price'] as num?)?.toDouble() ??
              product.wholesalePrice;
      final double total = unitPrice * quantity;

      await txn.update(
        'products',
        <String, Object?>{
          'stock_quantity': stock - quantity,
          ...pendingSyncColumns(at: now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[productId],
      );

      final int saleId = await txn.insert('sales', <String, Object?>{
        'product_id': productId,
        'product_name': product.name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total': total,
        'payment_method': payment.dbValue,
        'is_synced': 0,
        'sync_status': SyncStatus.pending.dbValue,
        'sync_error': null,
        'updated_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });

      if (payment == PaymentMethod.credit) {
        await txn.insert('debts', <String, Object?>{
          'client_name': client,
          'amount': total,
          'date': now.toIso8601String(),
          'status': DebtStatus.pending.dbValue,
          'description': 'Venta fiada: $quantity × ${product.name}',
        });
      }

      return Sale(
        id: saleId,
        productId: productId,
        productName: product.name,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
        paymentMethod: payment,
        createdAt: now,
      );
    });
  }

  Future<List<Sale>> getSales({int limit = 100}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map((Map<String, Object?> row) => Sale.fromMap(row))
        .toList(growable: false);
  }

  Future<List<Sale>> getPendingSales() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'sales',
      where: SyncStatus.pendingSql,
      orderBy: 'created_at ASC',
    );
    return rows
        .map((Map<String, Object?> row) => Sale.fromMap(row))
        .toList(growable: false);
  }

  Future<int> pendingSalesCount() async => pendingSyncCount(SyncEntity.sale);

  Future<int> markSalesSynced(List<int> ids) async {
    return applySyncResult(
      entity: SyncEntity.sale,
      ids: ids,
      status: SyncStatus.synced,
    );
  }

  /// Total vendido desde una fecha (por defecto, desde la medianoche de hoy).
  Future<double> salesTotalSince(DateTime since) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total FROM sales WHERE created_at >= ?',
      <Object?>[since.toIso8601String()],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> salesCountSince(DateTime since) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sales WHERE created_at >= ?',
      <Object?>[since.toIso8601String()],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Fiados / cartera
  // ---------------------------------------------------------------------------

  Future<List<Debt>> getDebts({DebtStatus? status}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'debts',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status.dbValue],
      orderBy: 'date DESC',
    );
    return rows
        .map((Map<String, Object?> row) => Debt.fromMap(row))
        .toList(growable: false);
  }

  Future<Debt> insertDebt(Debt debt) async {
    final Database db = await database;
    final Map<String, Object?> values = Map<String, Object?>.of(debt.toMap())
      ..remove('id')
      ..addAll(pendingSyncColumns(at: debt.date));
    final int id = await db.insert('debts', values);
    return debt.copyWith(id: id);
  }

  Future<int> updateDebtStatus(int debtId, DebtStatus status) async {
    final Database db = await database;
    return db.update(
      'debts',
      <String, Object?>{
        'status': status.dbValue,
        ...pendingSyncColumns(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[debtId],
    );
  }

  Future<int> deleteDebt(int debtId) async {
    final Database db = await database;
    return db.delete('debts', where: 'id = ?', whereArgs: <Object?>[debtId]);
  }

  Future<double> pendingDebtTotal() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM debts WHERE status = ?',
      <Object?>[DebtStatus.pending.dbValue],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }
}
