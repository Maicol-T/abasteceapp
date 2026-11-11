import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carga simulada de un documento de verificación.
///
/// La app no sube archivos reales: genera una ruta local de ejemplo y deja el
/// comprobante en el perfil. Cuando exista backend, `onUpload` abrirá el
/// selector de archivos y subirá el documento.
class DocumentUploadTile extends StatelessWidget {
  const DocumentUploadTile({
    super.key,
    required this.label,
    required this.description,
    required this.filePath,
    required this.onUpload,
    required this.onRemove,
    this.required = true,
  });

  final String label;
  final String description;
  final String? filePath;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final bool required;

  /// Ruta de ejemplo usada por la simulación de carga.
  static String simulatePath(String prefix) {
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    return 'docs/${prefix}_$stamp.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final bool uploaded = (filePath ?? '').trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uploaded
            ? AppColors.success.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: uploaded
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: uploaded
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              size: 19,
              color: uploaded ? AppColors.success : AppColors.muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (required)
                      const Text(
                        ' *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  uploaded ? filePath! : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: AppColors.muted,
                  ),
                ),
                if (uploaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Documento adjunto (simulación local)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          uploaded
              ? IconButton(
                  tooltip: 'Quitar documento',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                )
              : TextButton(
                  onPressed: onUpload,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Adjuntar'),
                ),
        ],
      ),
    );
  }
}
