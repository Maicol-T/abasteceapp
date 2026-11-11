import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';

/// Píldora de estado con color e icono.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.warning;
    case OrderStatus.confirmed:
      return AppColors.info;
    case OrderStatus.inTransit:
      return AppColors.secondary;
    case OrderStatus.delivered:
      return AppColors.success;
    case OrderStatus.cancelled:
      return AppColors.muted;
  }
}

IconData orderStatusIcon(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Icons.schedule_rounded;
    case OrderStatus.confirmed:
      return Icons.check_circle_outline_rounded;
    case OrderStatus.inTransit:
      return Icons.local_shipping_outlined;
    case OrderStatus.delivered:
      return Icons.done_all_rounded;
    case OrderStatus.cancelled:
      return Icons.block_rounded;
  }
}

Color debtStatusColor(DebtStatus status) {
  switch (status) {
    case DebtStatus.pending:
      return AppColors.warning;
    case DebtStatus.paid:
      return AppColors.success;
  }
}

IconData debtStatusIcon(DebtStatus status) {
  switch (status) {
    case DebtStatus.pending:
      return Icons.schedule_rounded;
    case DebtStatus.paid:
      return Icons.check_circle_outline_rounded;
  }
}

IconData paymentIcon(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return Icons.payments_outlined;
    case PaymentMethod.transfer:
      return Icons.account_balance_outlined;
    case PaymentMethod.credit:
      return Icons.receipt_long_outlined;
    case PaymentMethod.cashOnDelivery:
      return Icons.local_shipping_outlined;
  }
}
