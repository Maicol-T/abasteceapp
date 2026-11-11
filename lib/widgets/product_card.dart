import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/product_visuals.dart';

/// Tarjeta de producto del marketplace mayorista.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int quantityInCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _ProductAvatar(product: product),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.storefront_outlined,
                        size: 12,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        money(product.wholesalePrice),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        ' / ${product.unit}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        product.stockQuantity <= 0
                            ? 'Agotado'
                            : 'Stock ${product.stockQuantity}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: product.stockQuantity <= 0
                              ? AppColors.danger
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (quantityInCart == 0)
              IconButton.filled(
                onPressed: product.stockQuantity <= 0 ? null : onAdd,
                tooltip: 'Agregar al pedido',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  minimumSize: const Size(40, 40),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
              )
            else
              _QuantityStepper(
                quantity: quantityInCart,
                onAdd: onAdd,
                onRemove: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class ProductAvatar extends StatelessWidget {
  const ProductAvatar({super.key, required this.product, this.size = 46});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _ProductAvatar(product: product, size: size);
  }
}

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.product, this.size = 46});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = ProductVisuals.colorFor(product.category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Icon(
        ProductVisuals.iconFor(product.category),
        size: size * 0.48,
        color: color,
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MiniStepButton(icon: Icons.add_rounded, onTap: onAdd),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          _MiniStepButton(icon: Icons.remove_rounded, onTap: onRemove),
        ],
      ),
    );
  }
}

class _MiniStepButton extends StatelessWidget {
  const _MiniStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 36,
        height: 28,
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
