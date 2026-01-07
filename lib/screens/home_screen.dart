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
import 'ranking_screen.dart';

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

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchOrders();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  void _applyFilter(String status) {
    setState(() {
      _currentStatusFilter = status;
    });
    Navigator.pop(context); // Close drawer
    _fetchOrders(isRefresh: true);
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
      final orders = await _orderRepo.getOrders(page: 1, status: _currentStatusFilter, search: _searchQuery);
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
    // Tema iOS Light Blue Moderno
    const backgroundColor = Color(0xFFF3F4F6); // Cool Gray 100
    const cardColor = Colors.white;
    const textColor = Color(0xFF111827); // Gray 900
    const secondaryTextColor = Color(0xFF6B7280); // Gray 500

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Orden De Servicios', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent, 
        foregroundColor: textColor,
        iconTheme: const IconThemeData(color: textColor),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    setState(() {
                      _searchQuery = value;
                    });
                    _fetchOrders(isRefresh: true);
                  });
                },
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: 'Buscar orden, cliente...',
                  hintStyle: TextStyle(color: Colors.black38),
                  prefixIcon: Icon(Icons.search, color: Colors.blueGrey),
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
                  : _orders.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => _fetchOrders(isRefresh: true),
                          color: Colors.blue,
                          backgroundColor: Colors.white,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _orders.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              return _buildOrderCard(order, cardColor, textColor, secondaryTextColor)
                                  .animate(delay: (50 * index).clamp(0, 500).ms)
                                  .fadeIn(duration: 400.ms, curve: Curves.easeOutQuad)
                                  .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
                            },
                          ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay órdenes para mostrar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta cambiar los filtros o busca algo diferente.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _fetchOrders(isRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Recargar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF007AFF),
              side: const BorderSide(color: Color(0xFF007AFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 50), // Spacing
        ],
      ),
    );
  }

  Widget _buildOrderCard(Orden order, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20), // iOS style cleaner radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
    // 1. Asignada -> Aceptar
    if (status == 'asignada') {
      return Column(
        children: [
          SizedBox(
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
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
                ).then((_) => _fetchOrders(isRefresh: true));
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Ver Orden'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
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
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF007AFF), // iOS Blue
            ),
            accountName: Text(
              _currentUser?.name ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              _currentUser?.email ?? 'Cargando...',
              style: const TextStyle(color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _currentUser?.name.isNotEmpty == true ? _currentUser!.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 24, color: Color(0xFF007AFF)),
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Filtros de Estado', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                _buildFilterTile('Todas', 'todas'),
                _buildFilterTile('Asignada', 'asignada'),
                _buildFilterTile('En Proceso', 'en_proceso'),
                _buildFilterTile('En Sitio', 'en_sitio'),
                _buildFilterTile('Ejecutada', 'ejecutada'),
                


                const Divider(),

                ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.amber),
                  title: const Text('Top Ranking', style: TextStyle(color: Colors.black87)),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RankingScreen()),
                    );
                  },
                ),
                
                const Divider(),
                
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTile(String title, String value) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(color: Colors.black87)),
      value: value,
      groupValue: _currentStatusFilter,
      onChanged: (val) {
        if (val != null) _applyFilter(val);
      },
      activeColor: const Color(0xFF007AFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}