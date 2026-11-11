import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'database/database_helper.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/logistics_provider.dart';
import 'providers/marketplace_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/voice_provider.dart';
import 'router/app_router.dart';
import 'screens/auth_gate.dart';
import 'services/admin_sync_client.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/voice_service.dart';
import 'theme/app_theme.dart';

/// Raíz de la aplicación: inyecta base de datos, servicios y estado global.
class AbasteceApp extends StatelessWidget {
  const AbasteceApp({
    super.key,
    required this.database,
    required this.connectivityService,
    required this.voiceService,
  });

  final DatabaseHelper database;
  final ConnectivityService connectivityService;
  final VoiceService voiceService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseHelper>.value(value: database),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<VoiceService>.value(value: voiceService),
        Provider<SyncService>(
          create: (BuildContext context) => SyncService(
            database: database,
            connectivity: connectivityService,
            // Sin API configurada la app sincroniza en modo simulado.
            client: AppConstants.apiBaseUrl.isEmpty
                ? null
                : AdminSyncClient(baseUrl: AppConstants.apiBaseUrl),
          ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (BuildContext context) => AuthProvider(
            repository: AuthService(database: database),
          ),
        ),
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (BuildContext context) =>
              ConnectivityProvider(connectivityService),
        ),
        ChangeNotifierProvider<InventoryProvider>(
          create: (BuildContext context) => InventoryProvider(database)..load(),
        ),
        ChangeNotifierProvider<DebtProvider>(
          create: (BuildContext context) => DebtProvider(database)..load(),
        ),
        ChangeNotifierProvider<MarketplaceProvider>(
          create: (BuildContext context) =>
              MarketplaceProvider(database)..load(),
        ),
        ChangeNotifierProvider<LogisticsProvider>(
          create: (BuildContext context) => LogisticsProvider(database),
        ),
        ChangeNotifierProvider<SyncProvider>(
          create: (BuildContext context) => SyncProvider(
            service: context.read<SyncService>(),
            database: database,
            // Escucha la red para enviar la cola en segundo plano.
            connectivity: connectivityService,
          ),
        ),
        ChangeNotifierProvider<VoiceProvider>(
          create: (BuildContext context) =>
              VoiceProvider(voiceService: voiceService),
        ),
      ],
      child: MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('es', 'CO'),
        // Delegados oficiales: sin ellos MaterialLocalizations no existe para
        // es_CO y los TextField (buscador, formularios) rompen la interfaz.
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[
          Locale('es', 'CO'),
          Locale('es'),
          Locale('en', 'US'),
        ],
        home: const AuthGate(),
        // Enrutamiento por rol: cada ruta nombrada declara qué roles la ven.
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const AuthGate(),
        ),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: 1.3,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
