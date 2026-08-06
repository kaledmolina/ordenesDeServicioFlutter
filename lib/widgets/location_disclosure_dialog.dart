import 'package:flutter/material.dart';

class LocationDisclosureDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const LocationDisclosureDialog({
    super.key,
    required this.onAccept,
    required this.onDeny,
  });

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LocationDisclosureDialog(
          onAccept: () => Navigator.of(context).pop(true),
          onDeny: () => Navigator.of(context).pop(false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF10447E);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 48,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Uso de Ubicación en Segundo Plano',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),

            // Google Play Policy Compliant Content
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: RichText(
                textAlign: TextAlign.start,
                text: const TextSpan(
                  style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.45),
                  children: [
                    TextSpan(
                      text: 'IntalSupport ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    TextSpan(
                      text: 'recopila y accede a sus datos de ubicación para permitir el seguimiento de rutas de los técnicos de soporte, la asignación de órdenes de servicio en tiempo real y la verificación de llegada al cliente, ',
                    ),
                    TextSpan(
                      text: 'incluso cuando la aplicación está cerrada o no está en uso.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Estos datos se utilizan únicamente para la gestión de operaciones técnicas y no se comparten con terceros ni se venden para fines publicitarios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDeny,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'No permitir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
