import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../providers/marketplace_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Formulario para crear o editar un producto del inventario.
///
/// Devuelve el producto (sin persistir) y el llamador decide si inserta o
/// actualiza en la base local.
Future<Product?> showProductFormDialog(
  BuildContext context, {
  Product? product,
  String? initialBarcode,
}) {
  return showDialog<Product>(
    context: context,
    builder: (BuildContext context) => ProductFormDialog(
      product: product,
      initialBarcode: initialBarcode,
    ),
  );
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.product, this.initialBarcode});

  final Product? product;
  final String? initialBarcode;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;

  late String _category;
  late String _unit;
  late int _supplierId;

  @override
  void initState() {
    super.initState();
    final Product? product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.wholesalePrice.toStringAsFixed(0),
    );
    _stockController = TextEditingController(
      text: '${product?.stockQuantity ?? 0}',
    );
    _barcodeController = TextEditingController(
      text: product?.barcode ?? widget.initialBarcode ?? '',
    );
    _category = product?.category ?? AppConstants.categories.first;
    _unit = product?.unit ?? AppConstants.units.first;
    _supplierId = product?.supplierId ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final double? price = parseMoneyInput(_priceController.text);
    final int? stock = int.tryParse(_stockController.text.trim());
    if (price == null || price <= 0) return;

    final List<Supplier> suppliers =
        context.read<MarketplaceProvider>().suppliers;
    Supplier? supplier;
    for (final Supplier item in suppliers) {
      if (item.id == _supplierId) {
        supplier = item;
        break;
      }
    }

    final String barcode = _barcodeController.text.trim();
    final Product result = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      wholesalePrice: price,
      stockQuantity: stock ?? 0,
      barcode: barcode.isEmpty ? null : barcode,
      category: _category,
      supplierId: _supplierId,
      storeName: supplier?.name ?? widget.product?.storeName ?? 'Mi tienda',
      unit: _unit,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.product != null;
    final List<Supplier> suppliers =
        context.watch<MarketplaceProvider>().suppliers;

    // Se asegura de que el valor actual exista entre las opciones para no
    // romper el Dropdown con productos de categorías/unidades personalizadas.
    final List<String> categories = <String>[...AppConstants.categories];
    if (!categories.contains(_category)) categories.add(_category);
    final List<String> units = <String>[...AppConstants.units];
    if (!units.contains(_unit)) units.add(_unit);

    final List<Supplier> supplierOptions = <Supplier>[...suppliers];
    if (!supplierOptions.any(
      (Supplier supplier) => supplier.id == _supplierId,
    )) {
      supplierOptions.insert(
        0,
        Supplier(
          id: _supplierId,
          name: widget.product?.storeName ?? 'Mi tienda',
          neighborhood: '',
          rating: 0,
          deliveryFee: 0,
          minimumOrder: 0,
          etaMinutes: 0,
          phone: '',
        ),
      );
    }

    return AlertDialog(
      title: Text(editing ? 'Editar producto' : 'Nuevo producto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Arroz Diana 500 g',
                ),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Escribe el nombre del producto'
                        : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Precio'),
                      validator: (String? value) {
                        final double? price = parseMoneyInput(value ?? '');
                        if (price == null || price <= 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(labelText: 'Stock'),
                      validator: (String? value) {
                        final int? stock = int.tryParse(value ?? '');
                        if (stock == null || stock < 0) return 'Stock inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: categories
                          .map(
                            (String category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unidad'),
                      items: units
                          .map(
                            (String unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) setState(() => _unit = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _supplierId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Bodega proveedora'),
                items: supplierOptions
                    .map(
                      (Supplier supplier) => DropdownMenuItem<int>(
                        value: supplier.id,
                        child: Text(
                          supplier.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (int? value) {
                  if (value != null) setState(() => _supplierId = value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Código de barras (opcional)',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(120, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            editing ? 'Guardar cambios' : 'Crear producto',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
