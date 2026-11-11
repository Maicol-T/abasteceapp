import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

/// Pantalla que se muestra cuando la ruta no corresponde al rol autenticado.
///
/// No expone información del otro rol: solo explica el bloqueo y devuelve al
/// usuario a su propio inicio.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({
    super.key,
    required this.route,
    required this.role,
    required this.allowedRoles,
  });

  final String route;
  final UserRole? role;
  final Set<UserRole> allowedRoles;

  String get _allowedLabel => allowedRoles
      .map((UserRole item) => item.label)
      .join(' o ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta no disponible')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Esta pantalla no pertenece a tu rol',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tu sesión es ${role?.label ?? 'sin rol'} y esta sección es '
                'exclusiva para $_allowedLabel. Cada rol ve solo las '
                'herramientas de su operación: el comerciante compra y el '
                'proveedor vende y entrega.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.route_rounded,
                      size: 16,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ruta solicitada: $route',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: AppTheme.primaryButton(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Volver a mi inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
