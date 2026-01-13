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
import 'pending_orders_screen.dart';
import 'profile_screen.dart'; // Import ProfileScreen
import 'active_order_view.dart';
import '../widgets/barrio_search_modal.dart';

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
  List<String> _barrios = [];
  String? _selectedBarrio;

  // Tabs
  final List<Widget> _tabs = [
    // Placeholder for Home Tab (Built dynamically)
    const SizedBox(), 
    const ActiveOrderView(),
    const PendingOrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchBarrios();
    _fetchOrders();
  }

  Future<void> _fetchBarrios() async {
    try {
      final barrios = await _orderRepo.getBarrios();
      if (mounted) setState(() => _barrios = barrios);
    } catch (e) {
      debugPrint('Error fetching barrios: $e');
    }
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  // Filter Logic (Chip based now)
  void _applyFilter(String status) {
    if (_currentStatusFilter == status) return;
    setState(() {
      _currentStatusFilter = status;
    });
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
      final orders = await _orderRepo.getOrders(page: 1, status: _currentStatusFilter, search: _searchQuery, barrio: _selectedBarrio);
      
      // Custom Sorting Logic
      final now = DateTime.now();
      final activeStatuses = ['asignada', 'en_proceso', 'en_sitio', 'pendiente'];
      
      final activeOrders = <Orden>[];
      final inactiveOrders = <Orden>[];

      for (var order in orders) {
        if (activeStatuses.contains(order.status.toLowerCase())) {
          activeOrders.add(order);
        } else {
          inactiveOrders.add(order);
        }
      }

      // Sort Active Orders
      activeOrders.sort((a, b) {
        // 1. Criticality Check ( > 48 hours old)
        final aDuration = now.difference(a.fechaHora).inHours;
        final bDuration = now.difference(b.fechaHora).inHours;
        final aIsCritical = aDuration >= 48;
        final bIsCritical = bDuration >= 48;

        if (aIsCritical && !bIsCritical) return -1; // a comes first
        if (!aIsCritical && bIsCritical) return 1;  // b comes first

        // 2. Expiring soon (if fechaVencimiento exists) - Optional refinement
        // For now, secondary sort by creation date (Oldest first)
        return a.fechaHora.compareTo(b.fechaHora);
      });

      // Sort Inactive Orders (Newest first)
      inactiveOrders.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      if (mounted) {
        setState(() {
          _orders = [...activeOrders, ...inactiveOrders];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS ---

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
  }

  Future<void> _launchCaller(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
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
                _fetchOrders(isRefresh: true);
                Navigator.pop(context);
              }
            );
          }
        );
      },
    );
  }

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
              label: 'Mis Ordenes',
            ),
             NavigationDestination(
              icon: Icon(Icons.work_history_outlined),
              selectedIcon: Icon(Icons.work_history, color: Color(0xFF10447E)),
              label: 'En Curso',
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
              // Barrio Filter
              // Barrio Filter (Searchable)
              GestureDetector(
                onTap: _showBarrioSearchDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.transparent),
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
                    _buildFilterChip('Ejecutadas', 'ejecutada', color: Colors.green),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cerradas', 'cerrada', color: Colors.grey),
                    const SizedBox(width: 8),
                    _buildFilterChip('Anuladas', 'anulada', color: Colors.red),
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
                    const SizedBox(width: 8),
                    Text('Orden N° ${order.numeroOrden}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                     if (order.telefono != null)
                       Expanded(
                         child: InkWell(
                           onTap: () => _launchCaller(order.telefono!),
                           child: _buildMiniDetail(Icons.phone, order.telefono!, color: Colors.blue),
                         ),
                       ),
                   ],
                 ),
                 
                 // Novedades NOC
                 if (order.novedadesNoc != null && order.novedadesNoc!.isNotEmpty) ...[
                   const SizedBox(height: 12),
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: Colors.red[50],
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.red.shade200),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red[800]),
                             const SizedBox(width: 4),
                             Text('NOVEDADES NOC', style: TextStyle(color: Colors.red[800], fontSize: 11, fontWeight: FontWeight.bold)),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text(
                           order.novedadesNoc!,
                           style: TextStyle(color: Colors.red[900], fontSize: 13, height: 1.2),
                         ),
                       ],
                     ),
                   ),
                 ],

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
