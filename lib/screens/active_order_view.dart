import 'package:flutter/material.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import 'order_detail_screen.dart';

class ActiveOrderView extends StatefulWidget {
  const ActiveOrderView({super.key});

  @override
  _ActiveOrderViewState createState() => _ActiveOrderViewState();
}

class _ActiveOrderViewState extends State<ActiveOrderView> {
  final OrderRepository _orderRepo = OrderRepository();
  bool _isLoading = true;
  Orden? _activeOrder;
  String? _error;

  @override
  void initState() {
    super.initState();
    _findActiveOrder();
  }

  Future<void> _findActiveOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check for orders in 'en_proceso' or 'en_sitio'
      final inProcess = await _orderRepo.getOrders(status: 'en_proceso');
      final onSite = await _orderRepo.getOrders(status: 'en_sitio');

      if (inProcess.isNotEmpty) {
        _activeOrder = inProcess.first;
      } else if (onSite.isNotEmpty) {
        _activeOrder = onSite.first;
      } else {
        _activeOrder = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10447E)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            TextButton(onPressed: _findActiveOrder, child: const Text('Reintentar'))
          ],
        ),
      );
    }

    if (_activeOrder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No tienes ninguna orden en curso.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toma una orden de la lista de pendientes\no inicia una asignada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
             const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _findActiveOrder,
                child: const Text('Actualizar')
            )
          ],
        ),
      );
    }

    // Reuse OrderDetailScreen but embedded or just redirect?
    // User asked to "see the order", embedding detail screen is best for a tab experience.
    return OrderDetailScreen(orderNumber: _activeOrder!.numeroOrden);
  }
}
