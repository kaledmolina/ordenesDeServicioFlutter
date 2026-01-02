import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import 'home_screen.dart';
import 'login_screen.dart';


import '../services/notification_service.dart';

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
    // Pequeña demora para que la transición no sea tan abrupta
    await Future.delayed(const Duration(milliseconds: 500));

    // Aseguramos que el token se registre al iniciar la app
    await NotificationService.instance.requestPermissionAndRegisterToken();

    final token = await AuthService.instance.getToken();
    if (mounted) {
      if (token != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
