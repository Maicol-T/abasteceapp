import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../screens/access_denied_screen.dart';
import '../theme/app_theme.dart';

/// Vigila que una ruta solo se abra con la sesión y el rol correctos.
///
/// Se monta alrededor de cada pantalla nombrada. Si la sesión se perdió
/// (cierre de sesión con una pantalla abierta) vuelve al inicio; si el rol no
/// coincide muestra [AccessDeniedScreen] en lugar del contenido.
class RoleGuard extends StatefulWidget {
  const RoleGuard({
    super.key,
    required this.route,
    required this.allowedRoles,
    required this.child,
  });

  /// Nombre de la ruta protegida (para el mensaje de bloqueo).
  final String route;

  /// Roles con permiso. Vacío = cualquier sesión completa.
  final Set<UserRole> allowedRoles;

  final Widget child;

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _redirectScheduled = false;

  void _returnToRoot() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.signedOut) {
      _returnToRoot();
      return const _GuardPlaceholder(message: 'Volviendo al inicio…');
    }

    if (auth.status != AuthStatus.signedIn) {
      return const _GuardPlaceholder(message: 'Verificando tu sesión…');
    }

    final UserRole? role = auth.user?.role;
    if (role == null) {
      return const _GuardPlaceholder(message: 'Completando tu registro…');
    }

    final bool allowed =
        widget.allowedRoles.isEmpty || widget.allowedRoles.contains(role);
    if (!allowed) {
      return AccessDeniedScreen(
        route: widget.route,
        role: role,
        allowedRoles: widget.allowedRoles,
      );
    }

    return widget.child;
  }
}

class _GuardPlaceholder extends StatelessWidget {
  const _GuardPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
