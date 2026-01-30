import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInspectionStatus();
  }

  Future<void> _checkInspectionStatus() async {
    // Add a minimum delay for the splash animation to be seen
    await Future.delayed(const Duration(milliseconds: 2000));

    await NotificationService.instance.requestPermissionAndRegisterToken();

    final token = await AuthService.instance.getToken();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => token != null ? const HomeScreen() : const LoginScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                  ]
                ),
                child: Image.asset(
                  'assets/logo.png',
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                     return const Icon(Icons.business, size: 80, color: Color(0xFF10447E));
                  },
                ),
              )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .shimmer(duration: 1500.ms, delay: 1000.ms, color: Colors.white.withOpacity(0.5)),
              
              const SizedBox(height: 24),
              
              Text(
                'Ordenes de Servicio',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10447E),
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 300.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 8),
              
              Text(
                'Gestión Eficiente',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 600.ms),

              const SizedBox(height: 48),

              const SizedBox(
                width: 40, 
                height: 40, 
                child: CircularProgressIndicator(color: Color(0xFF10447E), strokeWidth: 3)
              ).animate().fadeIn(delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }
}
