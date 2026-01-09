import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/order_countdown.dart';
import 'pending_orders_screen.dart';
import 'profile_screen.dart'; // Import ProfileScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Tab Index
  final OrderRepository _orderRepo = OrderRepository();
  List<Orden> _orders = [];
  bool _isLoading = false;
  String _currentStatusFilter = 'todas';
  String _searchQuery = '';
  Timer? _debounce;
  User? _currentUser;

  // Tabs
  final List<Widget> _tabs = [
    // Placeholder for Home Tab (Built dynamically)
    const SizedBox(), 
    const PendingOrdersScreen(),
    const ProfileScreen(),
  ];

// ... (existing helper methods)

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      // App Bar only for Home Tab (Index 0)
      appBar: _currentIndex == 0 ? _buildHomeAppBar() : null,
      
      // Dynamic Body
      body: _currentIndex == 0 
          ? _buildHomeBody() // Custom body for Home
          : _tabs[_currentIndex], // Ranking or Profile

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: NavigationBar(
          height: 70,
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF10447E).withOpacity(0.1),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFF10447E)),
              label: 'Ordenes',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_add),
              selectedIcon: Icon(Icons.assignment_add, color: Color(0xFF10447E)),
              label: 'Pendientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFF10447E)),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildHomeAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hola, Técnico', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.normal)),
          Text(_currentUser?.name ?? 'Bienvenido', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10447E))),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: ConnectionStatusIndicator(),
        ),
      ],
    );
  }

  Widget _buildHomeBody() {
    return Column(
      children: [
        // 1. Search & Filter Section
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
             boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
          ),
          child: Column(
            children: [
               // Search Input
               TextField(
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    setState(() => _searchQuery = value);
                    _fetchOrders(isRefresh: true);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar cliente, dirección...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF10447E)),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 12),
              // Filter Chips Carousel
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todas', 'todas'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Asignadas', 'asignada', color: Colors.orange),
                    const SizedBox(width: 8),
                    _buildFilterChip('En Proceso', 'en_proceso', color: Colors.blue),
                    const SizedBox(width: 8),
                    _buildFilterChip('En Sitio', 'en_sitio', color: Colors.indigo),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Order List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () => _fetchOrders(isRefresh: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _buildModernOrderCard(order)
                              .animate(delay: (50 * index).clamp(0, 300).ms)
                              .fadeIn().slideX();
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String status, {Color color = const Color(0xFF10447E)}) {
    final isSelected = _currentStatusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyFilter(status),
      checkmarkColor: Colors.white,
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
           const SizedBox(height: 16),
           Text('Sin órdenes', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
           TextButton(onPressed: () => _fetchOrders(isRefresh: true), child: const Text('Actualizar'))
         ],
       ),
     );
  }

  // --- MODERN CARD DESIGN ---

  Widget _buildModernOrderCard(Orden order) {
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
              color: _getStatusColor(order.status).withOpacity(0.05),
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
                        color: _getStatusColor(order.status), 
                        borderRadius: BorderRadius.circular(2)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('#${order.numeroOrden}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                  ],
                ),
                Row(
                  children: [
                    _buildClassificationBadge(order.clasificacion),
                    _buildStatusBadge(order.status),
                  ],
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
                           const SizedBox(height: 4),
                           Row(
                             children: [
                               const Icon(Icons.location_on, size: 14, color: Colors.grey),
                               const SizedBox(width: 4),
                               Expanded(child: Text(order.direccion ?? 'Sin Dirección', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                             ],
                           ),
                         ],
                       ),
                     ),
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
                 const SizedBox(height: 12),
                 if (order.telefono != null)
                   InkWell(
                     onTap: () => _launchCaller(order.telefono!),
                     child: _buildMiniDetail(Icons.phone, order.telefono!, color: Colors.blue),
                   ),
              ],
            ),
          ),

          // 3. Actions Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildCardActions(order),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDetail(IconData icon, String text, {Color color = const Color(0xFF6B7280)}) {
    return Row(
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
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'asignada': return Colors.orange;
      case 'en_proceso': return Colors.blue;
      case 'en_sitio': return Colors.indigo;
      case 'ejecutada': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildClassificationBadge(String? clasificacion) {
    if (clasificacion == null || (clasificacion != 'rapidas' && clasificacion != 'cuadrilla')) return const SizedBox();
    
    Color color = clasificacion == 'rapidas' ? Colors.green : Colors.orange;
    String label = clasificacion == 'rapidas' ? 'RÁPIDA' : 'CUADRILLA';

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCardActions(Orden order) {
    String status = order.status.toLowerCase();

    // Reusing logic but with modern buttons
    if (status == 'asignada') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order.numeroOrden)),
            ).then((_) => _fetchOrders(isRefresh: true));
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF10447E),
            side: const BorderSide(color: Color(0xFF10447E)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
          child: const Text('VER DETALLES'),
        ),
      );
    }
    
    if (status == 'en_proceso') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _reportOnSite(order),
          icon: const Icon(Icons.location_on, size: 18),
          label: const Text('ESTOY EN SITIO'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10447E),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
        ),
      );
    }

    if (status == 'en_sitio') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _finishOrder(order),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('FINALIZAR ATENCIÓN'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
             foregroundColor: Colors.white,
            elevation: 2,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
        ),
      );
    }

    return Container(); // No actions for other states in list
  }
}