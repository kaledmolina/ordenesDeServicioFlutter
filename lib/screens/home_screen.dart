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
  final ScrollController _scrollController = ScrollController();
  
  List<Orden> _orders = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String _currentStatusFilter = 'todas';
  String _appBarTitle = 'Todas las Órdenes';

  @override
  void initState() {
    super.initState();
    _fetchOrders(isRefresh: true);
    _scrollController.addListener(_onScroll);
    // SyncService usage removed for online-only mode
  }

  // _loadOrdersFromCache removed

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders({bool isRefresh = false}) async {
    if (_isLoading && !isRefresh) return;
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }

    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    try {
      final orders = await _orderRepo.getOrders(page: _currentPage, status: _currentStatusFilter);
      
      if (mounted) {
        setState(() {
          if (isRefresh) {
            _orders = orders;
          } else {
            _orders.addAll(orders);
          }
          _currentPage++;
          _hasMore = orders.length >= 10;
        });
      }
    } catch (e) {
      if (mounted && isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar órdenes: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () => _fetchOrders(isRefresh: true),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String status, String title) {
    Navigator.of(context).pop();
    if (_currentStatusFilter == status) return;
    
    setState(() {
      _currentStatusFilter = status;
      _appBarTitle = title;
    });
    _fetchOrders(isRefresh: true);
  }

  (Color, IconData) _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case Orden.ESTADO_PENDIENTE: return (Colors.grey, Icons.hourglass_empty);
      case Orden.ESTADO_ASIGNADA: return (Colors.green, Icons.assignment_ind);
      case Orden.ESTADO_EN_SITIO: return (Colors.blue, Icons.location_on);
      case Orden.ESTADO_EN_PROCESO: return (Colors.orange.shade800, Icons.construction_outlined);
      case Orden.ESTADO_EJECUTADA: return (Colors.teal, Icons.check_circle);
      case Orden.ESTADO_CERRADA: return (Colors.blueGrey, Icons.lock);
      case Orden.ESTADO_ANULADA: return (Colors.red.shade700, Icons.cancel_outlined);
      default: return (Colors.grey, Icons.help_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black87,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: ConnectionStatusIndicator(),
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              _currentStatusFilter == 'todas'
                  ? 'No tienes órdenes asignadas.'
                  : 'No hay órdenes en estado "$_currentStatusFilter"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refrescar'),
              onPressed: () => _fetchOrders(isRefresh: true),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchOrders(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final order = _orders[index];
          final statusInfo = _getStatusInfo(order.status);
          
          return _buildOrderCard(order, statusInfo);
        },
      ),
    );
  }

  Widget _buildOrderCard(Orden order, (Color, IconData) statusInfo) {
    return _buildGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Icon(statusInfo.$2, color: statusInfo.$1, size: 30),
        title: Text('Orden #${order.numeroOrden}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Cliente: ${order.nombreCliente}'),
        trailing: Chip(
          label: Text(order.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          backgroundColor: statusInfo.$1.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden),
            ),
          );
          if (result == 'refresh' && mounted) {
            _fetchOrders(isRefresh: true);
          }
        },
      ),
    ).animate().fade(duration: 500.ms).slideY(begin: 0.5);
  }

  Widget _buildGlassCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Drawer(
          backgroundColor: Colors.lightBlue.shade50.withOpacity(0.9),
          child: Column(
            children: [
              FutureBuilder<User?>(
                future: AuthService.instance.getCurrentUser(),
                builder: (context, snapshot) {
                  final userName = snapshot.data?.name ?? 'Cargando...';
                  final userEmail = snapshot.data?.email ?? '';
                  return UserAccountsDrawerHeader(
                    accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    accountEmail: Text(userEmail, style: const TextStyle(color: Colors.black54)),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '', style: const TextStyle(fontSize: 24)),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade200.withOpacity(0.5),
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.list),
                      title: const Text('Todas las Órdenes'),
                      onTap: () => _applyFilter('todas', 'Todas las Órdenes'),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text('FILTRAR POR ESTADO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    _buildFilterTile(Orden.ESTADO_PENDIENTE, 'Pendientes'),
                    _buildFilterTile(Orden.ESTADO_ASIGNADA, 'Asignadas'),
                    _buildFilterTile(Orden.ESTADO_EN_SITIO, 'En Sitio'),
                    _buildFilterTile(Orden.ESTADO_EN_PROCESO, 'En Proceso'),
                    _buildFilterTile(Orden.ESTADO_EJECUTADA, 'Ejecutadas'),
                    _buildFilterTile(Orden.ESTADO_CERRADA, 'Cerradas'),
                    _buildFilterTile(Orden.ESTADO_ANULADA, 'Anuladas'),
                    const Divider(),
                    // Sync Status removed
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar Sesión'),
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
      ),
    );
  }
  
  Widget _buildFilterTile(String status, String title) {
    final statusInfo = _getStatusInfo(status);
    return ListTile(
      leading: Icon(statusInfo.$2, color: statusInfo.$1),
      title: Text(title),
      onTap: () => _applyFilter(status, 'Órdenes $title'),
    );
  }