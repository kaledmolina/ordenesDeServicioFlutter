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
    // ESTILOS TIPO DASHBOARD DARK (Filament-like)
    const backgroundColor = Color(0xFF000000); // Fondo negro total o muy oscuro
    const cardColor = Color(0xFF111827); // Gris oscuro (Gray 900)
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
      drawer: _buildDrawer(), // Reutilizamos el drawer existente o simplificado
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Breadcrumb visual
            const Text(
              'Gestión de Órdenes > Listado',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Orden De Servicios',
                  style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                // Search Bar simulada
                Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: const TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // TABLE CONTAINER
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: _isLoading && _orders.isEmpty 
                  ? const Center(child: CircularProgressIndicator()) 
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.3)),
                            dataRowColor: MaterialStateProperty.all(cardColor),
                            dividerThickness: 0.5,
                            horizontalMargin: 20,
                            columnSpacing: 30,
                            columns: const [
                              DataColumn(label: Text('N° Orden', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Técnico', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Fecha', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Estado', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Acciones', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold))),
                            ],
                            rows: _orders.map((order) {
                              return DataRow(
                                onSelectChanged: (_) {
                                   Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
                                  ).then((_) => _fetchOrders(isRefresh: true));
                                },
                                cells: [
                                  DataCell(Text(order.numeroOrden, style: const TextStyle(color: textColor))),
                                  DataCell(Text('Técnico intalnet', style: const TextStyle(color: textColor))), // Placeholder o real si viene del modelo
                                  DataCell(Text(
                                    order.fechaHora.toString().split(' ')[0], // Formato simple YYYY-MM-DD
                                    style: const TextStyle(color: textColor)
                                  )),
                                  DataCell(_buildStatusBadge(order.status)),
                                  DataCell(_buildActions(order)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            // Footer de paginación simulado
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Mostrando ${_orders.length} resultados', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor = Colors.white;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'asignada':
        color = const Color(0xFFF59E0B); // Amber/Yellow
        textColor = Colors.black;
        break;
      case 'ejecutada':
        color = const Color(0xFF10B981); // Emerald/Green
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status, 
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)
      ),
    );
  }

  Widget _buildActions(Orden order) {
    String status = order.status.toLowerCase();

    // 1. Asignada -> Aceptar
    if (status == 'asignada') {
      return InkWell(
        onTap: () => _acceptOrder(order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Colors.blue, size: 16),
              SizedBox(width: 4),
              Text('Aceptar Orden', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // 2. En Proceso -> Reportar En Sitio
    if (status == 'en_proceso') {
      return InkWell(
        onTap: () => _reportOnSite(order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: Colors.indigo, size: 16),
              SizedBox(width: 4),
              Text('Llegué a Sitio', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // 3. En Sitio -> Finalizar (Redirige a detalle)
    if (status == 'en_sitio') {
      return InkWell(
        onTap: () => _finishOrder(order),
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text('Finalizar Atención', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // Default -> Ver detalles
    return InkWell(
      onTap: () {
         Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
          ).then((_) => _fetchOrders(isRefresh: true));
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, color: Colors.grey, size: 18),
          SizedBox(width: 4),
          Text('Ver', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
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