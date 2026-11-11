import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Métrica compacta para las cabeceras (valor + etiqueta).
class HeaderMetric extends StatelessWidget {
  const HeaderMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onDark = true,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color valueColor = onDark ? Colors.white : AppColors.ink;
    final Color labelColor =
        onDark ? Colors.white.withValues(alpha: 0.72) : AppColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            onDark ? Colors.white.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              onDark ? Colors.white.withValues(alpha: 0.16) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: labelColor),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
