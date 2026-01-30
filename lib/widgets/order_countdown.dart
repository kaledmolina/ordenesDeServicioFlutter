import 'dart:async';
import 'package:flutter/material.dart';
import '../models/orden_model.dart';
import '../utils/business_hours.dart';

class OrderCountdown extends StatefulWidget {
  final DateTime creationDate;
  final DateTime? deadlineDate;

  const OrderCountdown({
    Key? key,
    required this.creationDate,
    required this.status,
    this.deadlineDate,
  }) : super(key: key);

  @override
  State<OrderCountdown> createState() => _OrderCountdownState();
}

class _OrderCountdownState extends State<OrderCountdown> {
  Timer? _timer;
  late Duration _remaining;
  bool _isOverdue = false;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    if (!_isFinalStatus) {
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _calculateTime();
      });
    }
  }

  bool get _isFinalStatus {
    final s = widget.status.toLowerCase();
    return s == Orden.ESTADO_EJECUTADA || 
           s == Orden.ESTADO_CERRADA || 
           s == Orden.ESTADO_ANULADA;
  }

  void _calculateTime() {
    DateTime deadline;
    if (widget.deadlineDate != null) {
      deadline = widget.deadlineDate!;
    } else {
      // Fallback: Use Business Hours Logic if no deadline provided from backend
      deadline = BusinessHours.add(widget.creationDate, 48);
    }
    
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (mounted) {
      setState(() {
        _remaining = difference;
        _isOverdue = difference.isNegative;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinalStatus) {
      return const SizedBox.shrink(); // No countdown for finished orders
    }

    final Color badgeColor = _isOverdue 
        ? Colors.red 
        : (_remaining.inHours < 4 ? Colors.orange : Colors.green);
    
    final String text = _formatDuration(_remaining);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) {
      final abs = d.abs();
      return "Hace ${abs.inHours}h ${abs.inMinutes.remainder(60)}m";
    } else {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
  }
}
