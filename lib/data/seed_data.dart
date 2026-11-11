import '../models/debt.dart';
import '../models/product.dart';
import '../models/supplier.dart';

/// Datos de demostración: bodegas reales de Buenaventura (nombres usados con
/// fines ilustrativos), su catálogo mayorista y fiados iniciales.
const List<Supplier> seedSuppliers = <Supplier>[
  Supplier(
    id: 1,
    name: 'Bodega La Libertad',
    neighborhood: 'El Centro',
    rating: 4.8,
    deliveryFee: 3500,
    minimumOrder: 25000,
    etaMinutes: 35,
    phone: '+57 312 555 0101',
  ),
  Supplier(
    id: 2,
    name: 'Distribuidora El Pacífico',
    neighborhood: 'Bellavista',
    rating: 4.6,
    deliveryFee: 4000,
    minimumOrder: 30000,
    etaMinutes: 45,
    phone: '+57 313 555 0202',
  ),
  Supplier(
    id: 3,
    name: 'Bodega Bahía Verde',
    neighborhood: 'La Independencia',
    rating: 4.5,
    deliveryFee: 3000,
    minimumOrder: 20000,
    etaMinutes: 30,
    phone: '+57 314 555 0303',
  ),
  Supplier(
    id: 4,
    name: 'Comercial Río Dagua',
    neighborhood: 'Comuna 12',
    rating: 4.3,
    deliveryFee: 4500,
    minimumOrder: 35000,
    etaMinutes: 50,
    phone: '+57 315 555 0404',
  ),
];

/// Cuentas de demostración sembradas junto con el catálogo.
///
/// Permiten probar la persistencia de sesión y los dos roles sin pasar por el
/// registro. En producción estas filas no existen: se crean solo en la base
/// local de demostración.
class DemoAccount {
  DemoAccount._();

  // Tendero de nivel 2 (formal, con RUT y Cámara de Comercio).
  static const String storeEmail = 'comerciante.demo@gmail.com';
  static const String storePhone = '+57 300 123 4567';
  static const String storeOwner = 'María Fernanda Riascos';
  static const String storeName = 'Tienda Doña María';
  static const String storeAddress = 'Calle 12 # 8-45, Bellavista';
  static const String storeZone = 'Bellavista';
  static const String storeIdDocument = '1.130.456.789';
  static const String storeRut = '901.234.567-8';

  // Proveedor jurídico que administra la Bodega La Libertad.
  static const String supplierEmail = 'proveedor.demo@abasteceapp.co';
  static const String supplierPhone = '+57 312 555 0101';
  static const String supplierBusiness = 'Bodega La Libertad S.A.S.';
  static const String supplierNit = '900.456.123-4';
  static const String supplierLegalRep = 'Carlos Alberto Riascos';
  static const String supplierLegalRepId = '16.789.123';

  static const String password = 'Abastece2026';
}

const List<Product> seedProducts = <Product>[
  // Bodega La Libertad
  Product(
    name: 'Arroz Diana 500 g',
    wholesalePrice: 2450,
    stockQuantity: 48,
    barcode: '7702001000011',
    category: 'Granos',
    supplierId: 1,
    storeName: 'Bodega La Libertad',
    unit: 'unidad',
  ),
  Product(
    name: 'Panela Cuadrada 500 g',
    wholesalePrice: 3500,
    stockQuantity: 36,
    barcode: '7702001000028',
    category: 'Granos',
    supplierId: 1,
    storeName: 'Bodega La Libertad',
    unit: 'unidad',
  ),
  Product(
    name: 'Aceite Premier 1 L',
    wholesalePrice: 9800,
    stockQuantity: 24,
    barcode: '7702001000035',
    category: 'Aceites',
    supplierId: 1,
    storeName: 'Bodega La Libertad',
    unit: 'unidad',
  ),
  Product(
    name: 'Lentejas Diana 500 g',
    wholesalePrice: 3900,
    stockQuantity: 30,
    barcode: '7702001000042',
    category: 'Granos',
    supplierId: 1,
    storeName: 'Bodega La Libertad',
    unit: 'unidad',
  ),
  Product(
    name: 'Azúcar Manuelita 1 kg',
    wholesalePrice: 4800,
    stockQuantity: 40,
    barcode: '7702001000059',
    category: 'Granos',
    supplierId: 1,
    storeName: 'Bodega La Libertad',
    unit: 'unidad',
  ),
  // Distribuidora El Pacífico
  Product(
    name: 'Leche Colanta 1 L',
    wholesalePrice: 4300,
    stockQuantity: 60,
    barcode: '7702001000066',
    category: 'Lácteos',
    supplierId: 2,
    storeName: 'Distribuidora El Pacífico',
    unit: 'unidad',
  ),
  Product(
    name: 'Pan Blanco Bimbo',
    wholesalePrice: 5600,
    stockQuantity: 5,
    barcode: '7702001000073',
    category: 'Panadería',
    supplierId: 2,
    storeName: 'Distribuidora El Pacífico',
    unit: 'unidad',
  ),
  Product(
    name: 'Gaseosa Postobón 1.5 L',
    wholesalePrice: 4700,
    stockQuantity: 72,
    barcode: '7702001000080',
    category: 'Bebidas',
    supplierId: 2,
    storeName: 'Distribuidora El Pacífico',
    unit: 'unidad',
  ),
  Product(
    name: 'Agua Cristal 600 ml',
    wholesalePrice: 1600,
    stockQuantity: 96,
    barcode: '7702001000097',
    category: 'Bebidas',
    supplierId: 2,
    storeName: 'Distribuidora El Pacífico',
    unit: 'unidad',
  ),
  Product(
    name: 'Atún Van Camps 170 g',
    wholesalePrice: 6200,
    stockQuantity: 42,
    barcode: '7702001000103',
    category: 'Enlatados',
    supplierId: 2,
    storeName: 'Distribuidora El Pacífico',
    unit: 'unidad',
  ),
  // Bodega Bahía Verde
  Product(
    name: 'Jabón Rey 300 g',
    wholesalePrice: 2900,
    stockQuantity: 54,
    barcode: '7702001000110',
    category: 'Aseo',
    supplierId: 3,
    storeName: 'Bodega Bahía Verde',
    unit: 'unidad',
  ),
  Product(
    name: 'Detergente Fab 500 g',
    wholesalePrice: 5100,
    stockQuantity: 6,
    barcode: '7702001000127',
    category: 'Aseo',
    supplierId: 3,
    storeName: 'Bodega Bahía Verde',
    unit: 'unidad',
  ),
  Product(
    name: 'Papel Higiénico Familia x4',
    wholesalePrice: 6900,
    stockQuantity: 6,
    barcode: '7702001000134',
    category: 'Aseo',
    supplierId: 3,
    storeName: 'Bodega Bahía Verde',
    unit: 'paquete',
  ),
  Product(
    name: 'Galletas Festival',
    wholesalePrice: 1800,
    stockQuantity: 80,
    barcode: '7702001000141',
    category: 'Snacks',
    supplierId: 3,
    storeName: 'Bodega Bahía Verde',
    unit: 'unidad',
  ),
  Product(
    name: 'Café Sello Rojo 250 g',
    wholesalePrice: 7300,
    stockQuantity: 4,
    barcode: '7702001000158',
    category: 'Bebidas',
    supplierId: 3,
    storeName: 'Bodega Bahía Verde',
    unit: 'unidad',
  ),
  // Comercial Río Dagua
  Product(
    name: 'Sal Refisal 500 g',
    wholesalePrice: 1700,
    stockQuantity: 48,
    barcode: '7702001000165',
    category: 'Granos',
    supplierId: 4,
    storeName: 'Comercial Río Dagua',
    unit: 'unidad',
  ),
  Product(
    name: 'Frijol Cargamanto 500 g',
    wholesalePrice: 4200,
    stockQuantity: 34,
    barcode: '7702001000172',
    category: 'Granos',
    supplierId: 4,
    storeName: 'Comercial Río Dagua',
    unit: 'unidad',
  ),
  Product(
    name: 'Chocolatina Jet',
    wholesalePrice: 1200,
    stockQuantity: 100,
    barcode: '7702001000189',
    category: 'Snacks',
    supplierId: 4,
    storeName: 'Comercial Río Dagua',
    unit: 'unidad',
  ),
];

/// Fiados de ejemplo para que el módulo de cartera no arranque vacío.
List<Debt> seedDebts() {
  final DateTime now = DateTime.now();
  return <Debt>[
    Debt(
      clientName: 'Doña Marta Riascos',
      amount: 25000,
      date: now.subtract(const Duration(days: 18)),
      description: 'Fiado de la semana: arroz, aceite y panela',
    ),
    Debt(
      clientName: 'Don Jhon Valencia',
      amount: 18500,
      date: now.subtract(const Duration(days: 6)),
      description: 'Gaseosas para la tienda',
    ),
    Debt(
      clientName: 'Sra. Luz Marina',
      amount: 32000,
      date: now.subtract(const Duration(days: 2)),
      description: 'Mercado de la casa',
    ),
  ];
}
