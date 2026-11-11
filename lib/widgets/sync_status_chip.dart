import 'package:flutter/material.dart';

/// Chip de estado de red / cola de sincronización sobre la cabecera oscura.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.online,
    this.pending = 0,
    this.onTap,
  });

  final bool online;
  final int pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String label = online ? 'En línea' : 'Sin internet';
    final String? pendingLabel = pending > 0 ? '$pending pend.' : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pendingLabel != null) ...<Widget>[
                Text(
                  ' · $pendingLabel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
