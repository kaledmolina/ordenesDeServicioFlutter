import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import 'order_detail_screen.dart';
import '../widgets/order_countdown.dart';

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
              Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300)
                  .animate().scale(duration: 500.ms).then().shake(duration: 500.ms),
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
    return OrderDetailScreen(
      orderNumber: _activeOrder!.numeroOrden,
      onOrderUpdated: _findActiveOrder,
    );
  }

  Widget _buildSuggestionCard(Orden order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10447E).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Header (Status Color Strip + Info)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1), // Suggestion is always "Alert/Attention"
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Row(
                  children: [
                    Container(
                      width: 4, height: 24,
                      decoration: BoxDecoration(
                        color: Colors.orange, 
                        borderRadius: BorderRadius.circular(2)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Orden N° ${order.numeroOrden}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                   child: const Text('SUGERIDA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // 2. Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 // Client & Countdown
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(order.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                           if (order.cedula != null)
                             Padding(
                               padding: const EdgeInsets.only(top: 2),
                               child: Text('C.C. ${order.cedula}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                             ),
                           const SizedBox(height: 4),
                           Row(
                             children: [
                               const Icon(Icons.location_on, size: 14, color: Colors.grey),
                               const SizedBox(width: 4),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      Text(order.direccion ?? 'Sin Dirección', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (order.barrio != null)
                                        Text(order.barrio!, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ],
                       ),
                     ),
                     // Note: We need to import OrderCountdown or just show date if not available
                     OrderCountdown(creationDate: order.fechaHora, status: order.status),
                   ],
                 ),
                 
                 const Divider(height: 24),

                 // Details Grid
                 Row(
                   children: [
                     Expanded(child: _buildMiniDetail(Icons.calendar_today, order.fechaHora.toString().split(' ')[0])),
                     Expanded(child: _buildMiniDetail(Icons.assignment, order.tipoOrdenLabel ?? 'General')),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     if (order.codigoContrato != null)
                        Expanded(child: _buildMiniDetail(Icons.receipt_long, 'Cod: ${order.codigoContrato}')),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     Expanded(
                       child: InkWell(
                         onTap: () { if (order.telefono != null) _launchCaller(order.telefono!); },
                         child: _buildMiniDetail(Icons.phone, order.telefono ?? 'N/A', color: Colors.blue, isCopyable: order.telefono != null, rawValue: order.telefono),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     Expanded(
                       child: InkWell(
                         onTap: () { if (order.telefonoFacturacion != null && order.telefonoFacturacion!.isNotEmpty) _launchCaller(order.telefonoFacturacion!); },
                         child: _buildMiniDetail(Icons.receipt, order.telefonoFacturacion?.isNotEmpty == true ? 'Fact: ${order.telefonoFacturacion!}' : 'Factura: N/A', color: Colors.blueAccent, isCopyable: order.telefonoFacturacion?.isNotEmpty == true, rawValue: order.telefonoFacturacion),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                      Expanded(
                        child: InkWell(
                          onTap: () { if (order.otroTelefono != null && order.otroTelefono!.isNotEmpty) _launchCaller(order.otroTelefono!); },
                          child: _buildMiniDetail(Icons.phone_android, order.otroTelefono?.isNotEmpty == true ? 'Otro: ${order.otroTelefono!}' : 'Otro: N/A', color: Colors.blueGrey, isCopyable: order.otroTelefono?.isNotEmpty == true, rawValue: order.otroTelefono),
                        ),
                      ),
                   ],
                 ),
                 
                 // Observaciones
                 if (order.observaciones != null && order.observaciones!.isNotEmpty) ...[
                   const SizedBox(height: 12),
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: Colors.grey[50],
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.grey.shade200),
                     ),
                     child: Text(
                       order.observaciones!,
                       style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                 ],
              ],
            ),
          ),

          // 3. Actions Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
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
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                 ),
                 child: const Text('VER DETALLES'),
               ),
           ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDetail(IconData icon, String text, {Color color = const Color(0xFF6B7280), bool isCopyable = false, String? rawValue}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text, 
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isCopyable) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: rawValue ?? text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copiado: ${rawValue ?? text}')));
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Icon(Icons.copy, size: 14, color: color),
            ),
          )
        ]
      ],
    );
  }
}
