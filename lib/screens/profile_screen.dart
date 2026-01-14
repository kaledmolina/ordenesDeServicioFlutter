import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../services/upload_service.dart';
import '../models/photo_status_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Default Avatar Letter
    final String initial = (_currentUser?.name.isNotEmpty == true) 
        ? _currentUser!.name[0].toUpperCase() 
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar Section
            Container(
              padding: const EdgeInsets.all(4), // Border
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                   BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5)
                  )
                ]
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF10447E),
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 50, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            
            const SizedBox(height: 20),
            
            // Name & Email
            Text(
              _currentUser?.name ?? 'Usuario',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ).animate().fadeIn().slideY(begin: 0.5, end: 0),
            
            Text(
              _currentUser?.email ?? 'correo@ejemplo.com',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.5, end: 0),
            
            const SizedBox(height: 30),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildProfileItem(Icons.badge, 'ID Técnico', '${_currentUser?.id ?? "-"}'),
                  const Divider(),
                  _buildProfileItem(Icons.work, 'Rol', 'Técnico de Campo'),
                  const Divider(),
                  _buildProfileItem(Icons.verified_user, 'Estado', 'Activo'),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 20),
            
            // Upload Status Card
            const _UploadStatusCard(),

            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                   await AuthService.instance.logout();
                   if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                   }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                  shadowColor: Colors.redAccent.withOpacity(0.4),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10447E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF10447E)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadStatusCard extends StatelessWidget {
  const _UploadStatusCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: UploadService.instance.pendingCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        if (count == 0) {
           return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Todo sincronizado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
           );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$count fotos pendientes de subir...', 
                      style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => UploadService.instance.syncPendingUploads(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[900],
                    side: BorderSide(color: Colors.orange[900]!),
                  ),
                  child: const Text('Forzar Sincronización'),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
