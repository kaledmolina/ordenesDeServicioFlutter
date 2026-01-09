import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/orden_model.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPendingOrders();
      setState(() {
        _orders = data['data'] ?? []; // Pagination returns data inside 'data'
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _claimOrder(String orderNumber) async {
    try {
      await _apiService.claimOrder(orderNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden asignada exitosamente!'), backgroundColor: Colors.green),
        );
        _fetchOrders(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
         String msg = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Órdenes Pendientes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10447E))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10447E)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $_error'),
                    ElevatedButton(onPressed: _fetchOrders, child: const Text('Reintentar'))
                  ],
                ))
              : _orders.isEmpty
                  ? const Center(child: Text('No hay órdenes pendientes para asignar', style: TextStyle( fontSize: 16, color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = Orden.fromJson(_orders[index]);
                        return _buildOrderCard(order);
                      },
                    ),
    );
  }

  Widget _buildOrderCard(Orden order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${order.numeroOrden}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _buildClassificationBadge(order.clasificacion),
              ],
            ),
          ),
          
          Padding(
             padding: const EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildInfoRow(Icons.person, order.nombreCliente),
                 const SizedBox(height: 8),
                 _buildInfoRow(Icons.location_on, order.direccion ?? 'Sin dirección'),
                 const SizedBox(height: 8),
                 _buildInfoRow(Icons.map, order.barrio ?? 'Sin barrio'),
                 const SizedBox(height: 8),
                 _buildInfoRow(Icons.assignment, order.tipoOrdenLabel),
                 const SizedBox(height: 16),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: () => _showConfirmationDialog(order),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF10447E),
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     child: const Text('SOLICITAR ASIGNACIÓN'),
                   ),
                 ),
               ],
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildClassificationBadge(String? clasificacion) {
    Color color = Colors.grey;
    String label = 'Sin Clasificación';

    if (clasificacion == 'rapidas') {
       color = Colors.green;
       label = 'RÁPIDA';
    } else if (clasificacion == 'cuadrilla') {
       color = Colors.orange;
       label = 'CUADRILLA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showConfirmationDialog(Orden order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Solicitud'),
        content: Text('¿Deseas asignarte la orden #${order.numeroOrden}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
               Navigator.of(ctx).pop();
               _claimOrder(order.numeroOrden);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
