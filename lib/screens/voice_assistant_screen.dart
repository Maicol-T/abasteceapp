import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/debt_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/voice_provider.dart';
import '../services/assistant_service.dart';
import '../services/voice_command_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';

/// Pestaña 4: asistente de voz / accesibilidad para el tendero.
class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => VoiceAssistantScreenState();
}

class VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  VoiceCommand? _lastCommand;
  AssistantReply? _reply;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Punto de entrada usado también por el botón flotante de la app.
  Future<void> startListening() async {
    final VoiceProvider voice = context.read<VoiceProvider>();
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }
    if (voice.simulationMode) {
      _notify(
        'Modo simulado: toca un comando de ejemplo o activa el micrófono.',
      );
      return;
    }
    final bool started = await voice.startListening(
      onFinalResult: _interpret,
    );
    if (!mounted) return;
    if (!started) {
      _notify(voice.error ?? 'No se pudo activar el micrófono.');
    }
  }

  Future<void> _toggleMode(bool useMicrophone) async {
    final VoiceProvider voice = context.read<VoiceProvider>();
    final bool ok = await voice.setSimulationMode(!useMicrophone);
    if (!mounted) return;
    if (!ok) {
      _notify(voice.error ?? 'El micrófono no está disponible en este equipo.');
    }
  }

  Future<void> _interpret(String phrase) async {
    final VoiceProvider voice = context.read<VoiceProvider>();
    final VoiceCommand command = voice.interpret(phrase);
    setState(() {
      _processing = true;
      _lastCommand = command;
    });

    AssistantReply reply;
    try {
      reply = await AssistantService(
        inventory: context.read<InventoryProvider>(),
        marketplace: context.read<MarketplaceProvider>(),
        debts: context.read<DebtProvider>(),
      ).handle(command);
    } catch (error) {
      reply = AssistantReply(
        message: 'Ocurrió un error procesando el comando: $error',
        intent: command.intent,
        success: false,
      );
    }

    if (!mounted) return;
    setState(() {
      _reply = reply;
      _processing = false;
    });
    await context.read<SyncProvider>().refreshPending();
  }

  void _runExample(String phrase) {
    if (_processing) return;
    context.read<VoiceProvider>().setTranscript(phrase);
    _interpret(phrase);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final VoiceProvider voice = context.watch<VoiceProvider>();
    final bool listening = voice.isListening;

    String status;
    if (_processing) {
      status = 'Procesando tu comando…';
    } else if (listening) {
      status = 'Te escucho… habla con calma';
    } else if (voice.simulationMode) {
      status = 'Toca un comando de ejemplo o activa el micrófono';
    } else {
      status = 'Toca el micrófono y habla';
    }

    return Column(
      children: <Widget>[
        GradientHeader(
          title: 'Asistente de voz',
          subtitle: 'Habla como le hablarías a tu ayudante. '
              'Funciona incluso sin internet.',
          child: _ModeCard(
            simulation: voice.simulationMode,
            onChanged: _toggleMode,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: <Widget>[
              _buildMicrophone(listening: listening),
              const SizedBox(height: 14),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              if (_processing) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceMuted,
                ),
              ],
              if (voice.transcript.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _TranscriptCard(
                  transcript: voice.transcript,
                  onClear: voice.clear,
                ),
              ],
              if (voice.error != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    voice.error!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF8A5A00),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (_reply != null) ...<Widget>[
                const SizedBox(height: 16),
                _ReplyCard(reply: _reply!, command: _lastCommand),
              ],
              const SizedBox(height: 22),
              const Text(
                'Prueba sin hablar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: voice.examples
                    .map(
                      (String example) => ActionChip(
                        label: Text(example),
                        onPressed:
                            _processing ? null : () => _runExample(example),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                        avatar: const Icon(
                          Icons.play_arrow_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 22),
              const _AccessibilityNote(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMicrophone({required bool listening}) {
    return Center(
      child: GestureDetector(
        onTap: startListening,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, Widget? child) {
            final double scale = listening ? 1 + (_pulse.value * 0.05) : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 138,
            height: 138,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF0B7A5B), Color(0xFF1565A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary
                      .withValues(alpha: listening ? 0.35 : 0.18),
                  blurRadius: listening ? 30 : 18,
                  spreadRadius: listening ? 8 : 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.simulation, required this.onChanged});

  final bool simulation;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            simulation ? Icons.auto_awesome_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  simulation ? 'Comandos simulados' : 'Micrófono del teléfono',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  simulation
                      ? 'Toca un ejemplo para probar'
                      : 'Reconocimiento de voz en español',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: !simulation,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
            activeTrackColor: Colors.white.withValues(alpha: 0.35),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
          ),
        ],
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript, required this.onClear});

  final String transcript;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.format_quote_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transcript,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.ink,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Limpiar',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply, required this.command});

  final AssistantReply reply;
  final VoiceCommand? command;

  @override
  Widget build(BuildContext context) {
    final Color accent = reply.success ? AppColors.success : AppColors.danger;
    final Map<String, String> details =
        command?.understood ?? const <String, String>{};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                reply.success
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reply.success ? 'Listo' : 'No pude completarlo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.message,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.ink,
              height: 1.45,
            ),
          ),
          if (details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: details.entries
                  .map(
                    (MapEntry<String, String> entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessibilityNote extends StatelessWidget {
  const _AccessibilityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.record_voice_over_outlined,
            size: 17,
            color: AppColors.primary,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pensado para tenderos con poca familiaridad tecnológica: '
              'puedes vender, consultar precios y cobrar fiados hablando. '
              'Tus datos quedan en el teléfono hasta que sincronices.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
