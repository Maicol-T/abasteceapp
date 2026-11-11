import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'legal_terms_sheet.dart';

/// Casilla obligatoria de aceptación de Términos y Habeas Data.
///
/// Nunca viene premarcada: la autorización de la Ley 1581 de 2012 debe ser
/// previa, expresa e informada, y el registro de evidencia solo se crea cuando
/// el titular la marca de forma voluntaria.
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
      decoration: BoxDecoration(
        color: hasError
            ? AppColors.danger.withValues(alpha: 0.05)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppColors.danger.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 40,
                height: 40,
                child: Checkbox(
                  value: value,
                  onChanged: (bool? checked) => onChanged(checked ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Acepto los Términos y Condiciones y la Política de '
                    'Tratamiento de Datos Personales, y autorizo el '
                    'tratamiento de mis datos para las finalidades allí '
                    'descritas.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: 4,
              children: <Widget>[
                TextButton(
                  onPressed: () => showLegalSheet(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Ver Términos'),
                ),
                TextButton(
                  onPressed: () => showLegalSheet(context, initialPolicy: true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Ver Política de datos'),
                ),
              ],
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
