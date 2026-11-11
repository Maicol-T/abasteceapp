import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';

/// Lector de códigos de barras con `mobile_scanner`.
///
/// Devuelve el código leído mediante `Navigator.pop<String>`.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.exampleBarcode});

  final String? exampleBarcode;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final TextEditingController _manualController = TextEditingController();

  bool _handled = false;
  bool _manualMode = false;
  bool _torchOn = false;

  bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final Barcode barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value.trim());
        return;
      }
    }
  }

  void _submitManual(String value) {
    final String code = value.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final bool showCamera = _cameraSupported && !_manualMode;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Escanear código',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          if (showCamera)
            IconButton(
              tooltip: 'Linterna',
              onPressed: () async {
                await _controller.toggleTorch();
                if (!mounted) return;
                setState(() => _torchOn = !_torchOn);
              },
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: Colors.white,
              ),
            ),
          IconButton(
            tooltip: showCamera ? 'Escribir código' : 'Usar cámara',
            onPressed: () => setState(() => _manualMode = !_manualMode),
            icon: Icon(
              showCamera
                  ? Icons.keyboard_rounded
                  : Icons.qr_code_scanner_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: showCamera ? _buildCamera(context) : _buildManual(context),
    );
  }

  Widget _buildCamera(BuildContext context) {
    return Stack(
      children: <Widget>[
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Center(
          child: Container(
            width: 260,
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white70, width: 2),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(height: 6),
                Text(
                  'Apunta al código de barras del producto',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Al leerlo abrimos la venta o el alta del producto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManual(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: <Widget>[
        const Icon(
          Icons.qr_code_2_rounded,
          color: Colors.white,
          size: 64,
        ),
        const SizedBox(height: 16),
        const Text(
          'Escribe el código de barras',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'La cámara se activa automáticamente en el teléfono. En este equipo '
          'puedes digitar el código del producto.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _manualController,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onSubmitted: _submitManual,
          decoration: InputDecoration(
            hintText: '7702001000011',
            hintStyle: const TextStyle(color: Colors.white38),
            labelText: 'Código de barras',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            prefixIcon: const Icon(
              Icons.qr_code_2_rounded,
              color: Colors.white70,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primaryLight,
                width: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _submitManual(_manualController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Text('Usar este código'),
        ),
        if (widget.exampleBarcode != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _submitManual(widget.exampleBarcode!),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
            ),
            child: Text('Usar código de ejemplo · ${widget.exampleBarcode}'),
          ),
        ],
      ],
    );
  }
}
