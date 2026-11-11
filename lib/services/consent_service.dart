import 'dart:io';

import '../constants/legal_texts.dart';

/// Servicio de evidencia de consentimiento.
///
/// Resuelve el identificador del equipo (`device_ip`) que se guarda en
/// `data_consent_logs` y expone la versión vigente de la política para que la
/// base y la interfaz nunca se desincronicen.
class ConsentService {
  const ConsentService();

  String get policyVersion => LegalDocs.policyVersion;

  /// IP local del dispositivo. En la base solo se guarda como evidencia
  /// aproximada: la IP pública la registra el backend al sincronizar.
  Future<String> deviceIp() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      ).timeout(const Duration(milliseconds: 500));
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          if (!address.isLoopback && address.address.isNotEmpty) {
            return address.address;
          }
        }
      }
    } catch (_) {
      // Sin red o sin permiso: se usa el loopback como marcador local.
    }
    return '127.0.0.1';
  }
}
