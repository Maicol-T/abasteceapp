import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'database/database_helper.dart';
import 'services/connectivity_service.dart';
import 'services/voice_service.dart';
import 'widgets/startup_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En release Flutter dibuja un recuadro gris cuando un widget falla; aquí se
  // reemplaza por un aviso legible para que la app nunca quede "en blanco".
  ErrorWidget.builder = (FlutterErrorDetails details) => StartupErrorScreen(
        message: details.exceptionAsString(),
      );

  final DatabaseHelper database = DatabaseHelper.instance;

  // La interfaz arranca de inmediato: la base local se abre en segundo plano y
  // los proveedores muestran su estado de carga mientras tanto.
  runApp(
    AbasteceApp(
      database: database,
      connectivityService: ConnectivityService(),
      voiceService: VoiceService(),
    ),
  );

  unawaited(_warmUpDatabase(database));
}

Future<void> _warmUpDatabase(DatabaseHelper database) async {
  try {
    // Abre (y siembra) la base local antes de que el usuario la necesite.
    await database.database;
  } catch (error, stack) {
    debugPrint('AbasteceApp: no se pudo abrir la base local: $error');
    debugPrintStack(stackTrace: stack);
  }
}
