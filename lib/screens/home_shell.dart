import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/logistics_provider.dart';
import '../providers/sync_provider.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../router/role_navigation.dart';
import '../theme/app_theme.dart';
import 'voice_assistant_screen.dart';

/// Contenedor principal de la app móvil.
///
/// La barra inferior **se construye a partir del rol**: el comerciante recibe
/// Mercado / Pedidos / Asistente / Cuenta y el proveedor Catálogo / Entregas /
/// Despachos / Ventas / Cuenta. No hay pestañas ocultas ni accesos cruzados.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.role,
    this.initialRoute,
  });

  /// Rol de la sesión: define qué pestañas existen.
  final UserRole role;

  /// Pestaña inicial (por defecto, la primera del rol).
  final String? initialRoute;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<VoiceAssistantScreenState> _assistantKey =
      GlobalKey<VoiceAssistantScreenState>();

  late List<RoleTab> _tabs;
  late List<Widget> _screens;
  late int _index;

  @override
  void initState() {
    super.initState();
    _buildTabs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LogisticsProvider>().load();
    });
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role ||
        oldWidget.initialRoute != widget.initialRoute) {
      _buildTabs();
    }
  }

  void _buildTabs() {
    _tabs = RoleNavigation.forRole(widget.role);
    _index = RoleNavigation.indexOf(widget.role, widget.initialRoute);
    _screens = _tabs
        .map(
          (RoleTab tab) => AppRouter.screenFor(
            tab.route,
            key: tab.route == AppRoutes.merchantAssistant ? _assistantKey : null,
          ),
        )
        .toList(growable: false);
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  bool get _assistantVisible =>
      _index < _tabs.length &&
      _tabs[_index].route == AppRoutes.merchantAssistant;

  int _badgeCount(RoleBadge badge) {
    switch (badge) {
      case RoleBadge.none:
        return 0;
      case RoleBadge.pendingSync:
        return context.watch<SyncProvider>().pendingTotal;
      case RoleBadge.activeLogistics:
        return context.watch<LogisticsProvider>().activeCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool accountPending = !(auth.user?.canOperate ?? true);

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _assistantVisible
          ? FloatingActionButton.extended(
              onPressed: () => _assistantKey.currentState?.startListening(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.mic_rounded, size: 22),
              label: const Text(
                'Hablar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: AppTheme.softShadow,
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: _selectTab,
            items: <BottomNavigationBarItem>[
              for (final RoleTab tab in _tabs)
                BottomNavigationBarItem(
                  icon: _BadgedIcon(
                    icon: tab.icon,
                    count: _badgeCount(tab.badge),
                    dot: tab.route == AppRoutes.supplierAccount ||
                            tab.route == AppRoutes.merchantAccount
                        ? accountPending
                        : false,
                  ),
                  activeIcon: _BadgedIcon(
                    icon: tab.activeIcon,
                    count: _badgeCount(tab.badge),
                    dot: tab.route == AppRoutes.supplierAccount ||
                            tab.route == AppRoutes.merchantAccount
                        ? accountPending
                        : false,
                  ),
                  label: tab.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icono con contador (o punto de aviso) para la barra inferior.
class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.count,
    required this.dot,
  });

  final IconData icon;
  final int count;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0 || dot,
      label: count > 0 ? Text('$count') : null,
      child: Icon(icon),
    );
  }
}
