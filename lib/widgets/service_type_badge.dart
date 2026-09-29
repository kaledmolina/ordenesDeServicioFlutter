import 'package:flutter/material.dart';
import '../models/orden_model.dart';

class ServiceTypeBadge extends StatelessWidget {
  final Orden order;
  final bool compact;

  const ServiceTypeBadge({
    super.key,
    required this.order,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = order.tipoServicioNormalizado;

    Color bgColor;
    Color borderColor;
    Color textColor;
    List<Widget> contentChildren = [];

    switch (tipo) {
      case 'COMBO_AUTOMONITOREO':
        bgColor = const Color(0xFFECFDF5); // Emerald 50
        borderColor = const Color(0xFF10B981); // Emerald 500
        textColor = const Color(0xFF065F46); // Emerald 800
        contentChildren = [
          Icon(Icons.tv, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 2),
          Text('+', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: compact ? 9 : 11)),
          const SizedBox(width: 2),
          Icon(Icons.wifi, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 2),
          Text('+', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: compact ? 9 : 11)),
          const SizedBox(width: 2),
          Icon(Icons.shield_outlined, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            compact ? 'TV + INT + AUTO' : 'TV + INT + AUTOMONITOREO',
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ];
        break;

      case 'INTERNET_AUTOMONITOREO':
        bgColor = const Color(0xFFF0FDFA); // Teal 50
        borderColor = const Color(0xFF14B8A6); // Teal 500
        textColor = const Color(0xFF115E59); // Teal 800
        contentChildren = [
          Icon(Icons.wifi, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 2),
          Text('+', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: compact ? 9 : 11)),
          const SizedBox(width: 2),
          Icon(Icons.shield_outlined, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            'INT + AUTOMONITOREO',
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ];
        break;

      case 'COMBO':
        bgColor = const Color(0xFFF3E8FF); // Purple 100
        borderColor = const Color(0xFFA855F7); // Purple 500
        textColor = const Color(0xFF6B21A8); // Purple 800
        contentChildren = [
          Icon(Icons.tv, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 2),
          Text('+', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: compact ? 10 : 12)),
          const SizedBox(width: 2),
          Icon(Icons.wifi, size: compact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            'TV + INTERNET',
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ];
        break;

      case 'TV':
        bgColor = const Color(0xFFFEF3C7); // Amber 100
        borderColor = const Color(0xFFF59E0B); // Amber 500
        textColor = const Color(0xFF92400E); // Amber 900
        contentChildren = [
          Icon(Icons.tv, size: compact ? 12 : 15, color: textColor),
          const SizedBox(width: 4),
          Text(
            'SOLO TELEVISIÓN',
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ];
        break;

      case 'INTERNET':
      default:
        bgColor = const Color(0xFFE0F2FE); // Sky 100
        borderColor = const Color(0xFF0284C7); // Sky 600
        textColor = const Color(0xFF075985); // Sky 800
        contentChildren = [
          Icon(Icons.wifi, size: compact ? 12 : 15, color: textColor),
          const SizedBox(width: 4),
          Text(
            'SOLO INTERNET',
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ];
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: contentChildren,
      ),
    );
  }
}
