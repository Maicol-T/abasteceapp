import 'package:flutter/foundation.dart';

import '../services/voice_command_parser.dart';
import '../services/voice_service.dart';

/// Estado del asistente de voz: micrófono, transcripción y modo simulado.
class VoiceProvider extends ChangeNotifier {
  VoiceProvider({
    required VoiceService voiceService,
    VoiceCommandParser? parser,
  })  : _voiceService = voiceService,
        _parser = parser ?? const VoiceCommandParser();

  final VoiceService _voiceService;
  final VoiceCommandParser _parser;

  bool _isListening = false;
  bool _isInitializing = false;
  bool _simulationMode = true;
  bool _isAvailable = false;
  String _transcript = '';
  String? _error;

  bool get isListening => _isListening;
  bool get isInitializing => _isInitializing;
  bool get simulationMode => _simulationMode;
  bool get isAvailable => _isAvailable;
  String get transcript => _transcript;
  String? get error => _error;
  List<String> get examples => VoiceCommandParser.simulatedCommands;

  VoiceCommand interpret(String text) => _parser.parse(text);

  /// Activa o desactiva el micrófono real.
  Future<bool> setSimulationMode(bool value) async {
    _simulationMode = value;
    _error = null;
    notifyListeners();
    if (value) return true;
    return ensureMicrophone();
  }

  /// Pide permisos e inicializa el reconocimiento nativo.
  Future<bool> ensureMicrophone() async {
    if (_isInitializing) return _isAvailable;
    _isInitializing = true;
    notifyListeners();
    _isAvailable = await _voiceService.initialize();
    _isInitializing = false;
    if (!_isAvailable) {
      _error = 'Este equipo no tiene reconocimiento de voz. '
          'Usa los comandos simulados mientras tanto.';
    }
    notifyListeners();
    return _isAvailable;
  }

  /// Inicia la escucha; el texto final se entrega a [onFinalResult].
  Future<bool> startListening({
    required ValueChanged<String> onFinalResult,
  }) async {
    if (_isListening) return true;
    _error = null;
    _transcript = '';
    final bool available = await ensureMicrophone();
    if (!available) return false;

    _isListening = true;
    notifyListeners();

    final bool started = await _voiceService.listen(
      onPartial: (String text) {
        _transcript = text;
        notifyListeners();
      },
      onDone: (String text) {
        _isListening = false;
        _transcript = text;
        notifyListeners();
        if (text.trim().isNotEmpty) {
          onFinalResult(text);
        }
      },
    );

    if (!started) {
      _isListening = false;
      _error = _voiceService.lastError ??
          'No se pudo activar el micrófono. Revisa los permisos de la app.';
      notifyListeners();
    }
    return started;
  }

  Future<void> stopListening() async {
    await _voiceService.stop();
    _isListening = false;
    notifyListeners();
  }

  void setTranscript(String text) {
    _transcript = text;
    notifyListeners();
  }

  void clear() {
    _transcript = '';
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
