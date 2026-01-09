import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
  }

  Future<void> _checkApiConnection() async {
    final status = await ApiService().checkApiStatus();
    if (mounted) {
      setState(() {
        _isConnected = status;
      });
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final success = await AuthService.instance.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      await NotificationService.instance.requestPermissionAndRegisterToken();
      if (mounted) {
         Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
         );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas o error de conexión.')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Animated Logo
                   Hero(
                     tag: 'app_logo',
                     child: Container(
                       height: 120,
                       width: 120,
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         boxShadow: [
                           BoxShadow(color: const Color(0xFF10447E).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                         ]
                       ),
                       child: Image.asset(
                         'assets/logo.png',
                         fit: BoxFit.contain,
                         errorBuilder: (context, error, stackTrace) {
                            return const CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 60,
                              child: Icon(Icons.business, size: 60, color: Color(0xFF10447E)),
                            );
                         },
                       ),
                     ),
                   ),
                  const SizedBox(height: 30),
                  
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bienvenido',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10447E),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gestión de Ordenes',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          _buildStatusChip(),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Correo Electrónico',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10447E), width: 2)),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF10447E)),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                               filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10447E), width: 2)),
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10447E)),
                            ),
                          ),
                          const SizedBox(height: 40),
                          _isLoading
                              ? const CircularProgressIndicator(color: Color(0xFF10447E))
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10447E), 
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 8,
                                      shadowColor: const Color(0xFF10447E).withOpacity(0.5),
                                    ),
                                    child: const Text('INGRESAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    if (_isConnected == null) {
      return const Chip(
        avatar: SizedBox(
          height: 15,
          width: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Verificando conexión...'),
      );
    }
    if (_isConnected == true) {
      return const Chip(
        avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
        label: Text('Conectado al servidor'),
        backgroundColor: Color.fromARGB(255, 225, 245, 226),
      );
    } else {
      return const Chip(
        avatar: Icon(Icons.error, color: Colors.red, size: 18),
        label: Text('Error de conexión'),
        backgroundColor: Color.fromARGB(255, 255, 230, 228),
      );
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return GlassCard(
      borderRadius: 24.0,
      child: child,
    );
  }
}
