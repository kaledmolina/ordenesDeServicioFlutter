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
  Orden? _suggestedOrder;

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
        
        // Find Suggestion: Assigned or Pending
        final assigned = await _orderRepo.getOrders(status: 'asignada');
        final pending = await _orderRepo.getOrders(status: 'pendiente');
        final allPotential = [...assigned, ...pending];

        if (allPotential.isNotEmpty) {
          final now = DateTime.now();
          // Sort by critical (>48h) then by oldest
          allPotential.sort((a, b) {
            final aDuration = now.difference(a.fechaHora).inHours;
            final bDuration = now.difference(b.fechaHora).inHours;
            final aIsCritical = aDuration >= 48;
            final bIsCritical = bDuration >= 48;

            if (aIsCritical && !bIsCritical) return -1;
            if (!aIsCritical && bIsCritical) return 1;
            return a.fechaHora.compareTo(b.fechaHora); // Oldest first
          });
          _suggestedOrder = allPotential.first;
        } else {
            _suggestedOrder = null;
        }
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No tienes ordenes en curso',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_suggestedOrder != null) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sugerencia: Orden a vencer para tomar', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))
                  ),
                  const SizedBox(height: 10),
                  _buildSuggestionCard(_suggestedOrder!)
              ] else ...[
                 const Text(
                  'No tienes órdenes pendientes por realizar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                 const SizedBox(height: 20),
                 ElevatedButton(
                    onPressed: _findActiveOrder,
                    child: const Text('Actualizar')
                )
              ]
            ],
          ),
        ),
      );
    }

    // Reuse OrderDetailScreen but embedded or just redirect?
    // User asked to "see the order", embedding detail screen is best for a tab experience.
    return OrderDetailScreen(orderNumber: _activeOrder!.numeroOrden);
  }

  Widget _buildSuggestionCard(Orden order) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
             Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
             ).then((_) => _findActiveOrder());
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('SUGERIDA', style: TextStyle(color: Colors.orange[800], fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text('Orden N° ${order.numeroOrden}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(order.nombreCliente, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(order.direccion ?? 'Sin Dirección', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                     Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                     const SizedBox(width: 4),
                     Text(
                       order.fechaHora.toString().split('.')[0], 
                       style: TextStyle(color: Colors.grey[600], fontSize: 12)
                     ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 SizedBox(
                   width: double.infinity,
                   child: OutlinedButton(
                     onPressed: () {
                         Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
                         ).then((_) => _findActiveOrder());
                     },
                     style: OutlinedButton.styleFrom(
                       foregroundColor: const Color(0xFF10447E),
                       side: const BorderSide(color: Color(0xFF10447E)),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                     ),
                     child: const Text('VER ORDEN'),
                   ),
                 )
              ],
            ),
          ),
        ),
      );
  }
}
