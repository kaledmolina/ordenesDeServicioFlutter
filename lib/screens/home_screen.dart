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

  // ... dispose and other methods ...

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