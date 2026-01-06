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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: 100, // Ajusta la altura según sea necesario
                          errorBuilder: (context, error, stackTrace) {
                             return const Icon(Icons.business, size: 80, color: Colors.white);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Bienvenido',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Correo Electrónico',
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.blue),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            labelStyle: const TextStyle(color: Colors.black54),
                             filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF), // iOS Blue
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 5,
                                    shadowColor: Colors.blue.withOpacity(0.4),
                                  ),
                                  child: const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
