import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/connection_status_indicator.dart';

import 'debug_database_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  List<Orden> _orders = [];
  bool _isLoading = false;
  String _currentStatusFilter = 'todas';
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool isRefresh = false}) async {
    if (_isLoading && !isRefresh) return;
    setState(() => _isLoading = true);

    try {
      // Note: Pagination logic simplified for Table view to load first page or all. 
      // For a dashboard table, usually we might want more data, 
      // but let's stick to standard fetch to avoid breaking repo.
      final orders = await _orderRepo.getOrders(page: 1, status: _currentStatusFilter);
      if (mounted) {
        setState(() {
          _orders = orders;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOrder(Orden order) async {
    try {
      await _orderRepo.acceptOrder(order.numeroOrden);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden aceptada'), backgroundColor: Colors.green),
        );
        _fetchOrders(isRefresh: true);
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

  Future<void> _reportOnSite(Orden order) async {
    try {
      await _orderRepo.reportOnSite(order.numeroOrden);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reportado en sitio'), backgroundColor: Colors.green),
        );
        _fetchOrders(isRefresh: true);
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

  void _finishOrder(Orden order) {
      // Para finalizar se requieren firmas y datos, redirigimos al detalle
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
      ).then((_) => _fetchOrders(isRefresh: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa los datos y firmas para finalizar.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Manteniendo el tema oscuro premium
    const backgroundColor = Color(0xFF000000); 
    const cardColor = Color(0xFF111827);
    const textColor = Colors.white;
    const secondaryTextColor = Colors.white70;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Orden De Servicios', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ConnectionStatusIndicator(),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar orden, cliente...',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // LIST VIEW CONTAINER
            Expanded(
              child: _isLoading && _orders.isEmpty 
                  ? const Center(child: CircularProgressIndicator()) 
                  : ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(order, cardColor, textColor, secondaryTextColor);
                      },
                    ),
            ),
             // Footer info
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Text('${_orders.length} resultados', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Orden order, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nro Orden y Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.numeroOrden}',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 12),
          
          // Info Cliente
          _buildInfoRow(Icons.person, order.nombreCliente, textColor),
          const SizedBox(height: 8),
          
          // Direccion
          if (order.direccion != null)
             _buildInfoRow(Icons.location_on, order.direccion!, secondaryTextColor),
          
          // Fecha
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today, order.fechaHora.toString().split(' ')[0], secondaryTextColor),

          const SizedBox(height: 16),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 16),

          // Actions
          _buildCardActions(order),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 14))),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'asignada':
        color = const Color(0xFFF59E0B); // Amber
        break;
      case 'ejecutada':
        color = const Color(0xFF10B981); // Emerald
        break;
      case 'en_proceso':
        color = Colors.blue;
        break;
      case 'en_sitio':
        color = Colors.indigo;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status, 
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)
      ),
    );
  }

  Widget _buildCardActions(Orden order) {
    String status = order.status.toLowerCase();

    // 1. Asignada -> Aceptar
    if (status == 'asignada') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _acceptOrder(order),
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text('Aceptar Orden', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    // 2. En Proceso -> Reportar En Sitio
    if (status == 'en_proceso') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _reportOnSite(order),
          icon: const Icon(Icons.location_on, color: Colors.white),
          label: const Text('Llegué a Sitio', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    // 3. En Sitio -> Finalizar
    if (status == 'en_sitio') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _finishOrder(order),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          label: const Text('Finalizar Atención', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    // Default -> Ver detalles (Outline Button)
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
            Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
          ).then((_) => _fetchOrders(isRefresh: true));
        },
        icon: const Icon(Icons.visibility),
        label: const Text('Ver Detalles'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey,
          side: const BorderSide(color: Colors.grey),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
     // Drawer simple oscuro
    return Drawer(
      backgroundColor: const Color(0xFF111827),
      child: ListView(
        children: [
          const DrawerHeader(
             decoration: BoxDecoration(color: Colors.black),
             child: Center(child: Text('Menú', style: TextStyle(color: Colors.white, fontSize: 24))),
          ),
          ListTile(
            leading: const Icon(Icons.list, color: Colors.white),
            title: const Text('Órdenes', style: TextStyle(color: Colors.white)),
            onTap: () {
               Navigator.pop(context);
               _fetchOrders(isRefresh: true);
            },
          ),
           ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
                  await AuthService.instance.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
            },
          ),
        ],
      ),
    );
  }
}