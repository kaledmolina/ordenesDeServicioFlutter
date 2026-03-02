import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/orden_model.dart';
import '../widgets/barrio_search_modal.dart';

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
  List<String> _barrios = [];
  String? _selectedBarrio;

  @override
  void initState() {
    super.initState();
    super.initState();
    _fetchBarrios();
    _fetchOrders();
  }

  Future<void> _fetchBarrios() async {
    try {
      final barrios = await _apiService.getBarrios();
      if (mounted) setState(() => _barrios = barrios);
    } catch (e) {
      debugPrint('Error fetching barrios: $e');
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPendingOrders(barrio: _selectedBarrio);
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
      body: Column(
        children: [
          // Barrio Filter
          // Barrio Filter (Searchable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: GestureDetector(
              onTap: _showBarrioSearchDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedBarrio ?? 'Todos los Barrios',
                      style: TextStyle(
                        color: _selectedBarrio == null ? Colors.grey.shade600 : Colors.black87,
                        fontSize: 16
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
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
                              return _buildOrderCard(order)
                                  .animate(delay: (50 * index).clamp(0, 300).ms)
                                  .fadeIn().slideX();
                            },
                          ),
          ),
        ],
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
                 if (order.cedula != null) ...[
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       Expanded(child: _buildInfoRow(Icons.badge, 'C.C. ${order.cedula}')),
                       const SizedBox(width: 8),
                       InkWell(
                         onTap: () {
                           Clipboard.setData(ClipboardData(text: order.cedula!));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cédula copiada al portapapeles')));
                         },
                         child: Container(
                           padding: const EdgeInsets.all(4),
                           decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                           child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                         ),
                       ),
                     ],
                   ),
                 ],
                 const SizedBox(height: 8),
                 _buildInfoRow(Icons.location_on, order.direccion ?? 'Sin dirección'),
                 const SizedBox(height: 8),
                 _buildInfoRow(Icons.map, order.barrio ?? 'Sin barrio'),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     Expanded(
                       child: InkWell(
                         onTap: () { if (order.telefono != null) _launchCaller(order.telefono!); },
                         child: _buildInfoRow(Icons.phone, order.telefono ?? 'N/A', isCopyable: order.telefono != null, rawValue: order.telefono),
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
                         child: _buildInfoRow(Icons.receipt, order.telefonoFacturacion?.isNotEmpty == true ? 'Fact: ${order.telefonoFacturacion!}' : 'Factura: N/A', isCopyable: order.telefonoFacturacion?.isNotEmpty == true, rawValue: order.telefonoFacturacion),
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
                          child: _buildInfoRow(Icons.phone_android, order.otroTelefono?.isNotEmpty == true ? 'Otro: ${order.otroTelefono!}' : 'Otro: N/A', isCopyable: order.otroTelefono?.isNotEmpty == true, rawValue: order.otroTelefono),
                        ),
                      ),
                   ],
                 ),
                  _buildInfoRow(Icons.assignment, order.tipoOrdenLabel),
                  const SizedBox(height: 8),
                  if (order.solicitudSuscriptor != null)
                    _buildInfoRow(Icons.report_problem, order.solicitudSuscriptorLabel),
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

  Widget _buildInfoRow(IconData icon, String text, {bool isCopyable = false, String? rawValue}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        if (isCopyable) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: rawValue ?? text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copiado: ${rawValue ?? text}')));
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.copy, size: 14, color: Colors.blue),
            ),
          )
        ]
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

  void _showBarrioSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return BarrioSearchModal(
              barrios: _barrios, 
              onSelected: (barrio) {
                setState(() => _selectedBarrio = barrio);
                _fetchOrders();
                Navigator.pop(context);
              }
            );
          }
        );
      },
    );
  }
}
