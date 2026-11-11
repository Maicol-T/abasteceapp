import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Iconografía y color por categoría de producto. Evita depender de imágenes
/// remotas: la app debe verse bien sin conexión.
class ProductVisuals {
  ProductVisuals._();

  static IconData iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'granos':
        return Icons.rice_bowl_outlined;
      case 'aceites':
        return Icons.water_drop_outlined;
      case 'bebidas':
        return Icons.local_drink_outlined;
      case 'aseo':
        return Icons.cleaning_services_outlined;
      case 'enlatados':
        return Icons.inventory_2_outlined;
      case 'lácteos':
      case 'lacteos':
        return Icons.egg_alt_outlined;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'panadería':
      case 'panaderia':
        return Icons.bakery_dining_outlined;
      default:
        return Icons.shopping_basket_outlined;
    }
  }

  static Color colorFor(String category) {
    switch (category.toLowerCase()) {
      case 'granos':
        return const Color(0xFFB07D2B);
      case 'aceites':
        return const Color(0xFFD89B00);
      case 'bebidas':
        return const Color(0xFF1565A8);
      case 'aseo':
        return const Color(0xFF00838F);
      case 'enlatados':
        return const Color(0xFF6A5ACD);
      case 'lácteos':
      case 'lacteos':
        return const Color(0xFF3F7D3A);
      case 'snacks':
        return const Color(0xFFE0662B);
      case 'panadería':
      case 'panaderia':
        return const Color(0xFF9C6B3F);
      default:
        return AppColors.inkSoft;
    }
  }

  static Color tintFor(String category) =>
      colorFor(category).withValues(alpha: 0.12);
}
