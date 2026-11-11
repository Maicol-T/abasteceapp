import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/qr_code.dart';

/// Dibuja la matriz de un código QR generado por [QrEncoder].
///
/// Se usa en el pase de retiro: el tendero lo muestra en la bodega y el
/// operario lo lee con la cámara. Si el payload no cupiera en la versión 1-L se
/// muestra el texto en su lugar (nunca un QR inválido).
class QrView extends StatelessWidget {
  const QrView({
    super.key,
    required this.data,
    this.size = 170,
    this.color = AppColors.ink,
  });

  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!QrEncoder.canEncode(data)) {
      return _Fallback(data: data, size: size);
    }
    final QrCode code = QrEncoder.encode(data);
    return Semantics(
      label: 'Código QR de retiro',
      value: data,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: CustomPaint(painter: _QrPainter(code: code, color: color)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.code, required this.color});

  final QrCode code;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double module = size.width / code.size;
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (int row = 0; row < code.size; row++) {
      for (int column = 0; column < code.size; column++) {
        if (!code.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            column * module,
            row * module,
            module + 0.2,
            module + 0.2,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.code != code || oldDelegate.color != color;
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.qr_code_2_rounded,
            size: 36,
            color: AppColors.muted,
          ),
          const SizedBox(height: 6),
          Text(
            data,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.3,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
