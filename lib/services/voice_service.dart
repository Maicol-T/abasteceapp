import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Envoltura del reconocimiento de voz nativo (`speech_to_text`).
///
/// El asistente funciona en español de Colombia; si el equipo no tiene
/// reconocimiento disponible, la interfaz cae automáticamente al modo de
/// comandos simulados.
class VoiceService {
  VoiceService({stt.SpeechToText? speech, this.localeId = 'es_CO'})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;

  /// Idioma del reconocedor (es_CO = español Colombia).
  final String localeId;

  bool _initialized = false;
  String _lastText = '';
  String? _lastError;
  ValueChanged<String>? _onDone;

  bool get isAvailable => _initialized && _speech.isAvailable;
  bool get isListening => _speech.isListening;
  String? get lastError => _lastError;

  /// Inicializa el plugin y solicita permisos de micrófono (una sola vez).
  Future<bool> initialize() async {
    if (_initialized) return isAvailable;
    try {
      _initialized = await _speech.initialize(
        onError: (error) {
          _lastError = error.errorMsg;
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            final ValueChanged<String>? callback = _onDone;
            _onDone = null;
            callback?.call(_lastText);
          }
        },
      );
    } catch (error) {
      _lastError = error.toString();
      _initialized = false;
    }
    return isAvailable;
  }

  /// Arranca una escucha. Devuelve `false` si el micrófono no está disponible.
  Future<bool> listen({
    required ValueChanged<String> onPartial,
    ValueChanged<String>? onDone,
  }) async {
    _lastError = null;
    final bool available = await initialize();
    if (!available) return false;

    _lastText = '';
    _onDone = onDone;
    try {
      await _speech.listen(
        onResult: (result) {
          _lastText = result.recognizedWords;
          onPartial(_lastText);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (error) {
      _lastError = error.toString();
      _onDone = null;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Sin micrófono activo: no hay nada que detener.
    }
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // Ignorado a propósito.
    }
  }

  void dispose() {
    _onDone = null;
    unawaited(cancel());
  }
}
