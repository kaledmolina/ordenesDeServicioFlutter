import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/database_service.dart';

class OfflinePendingScreen extends StatefulWidget {
  const OfflinePendingScreen({super.key});

  @override
  State<OfflinePendingScreen> createState() => _OfflinePendingScreenState();
}

class _OfflinePendingScreenState extends State<OfflinePendingScreen> {
  List<Map<String, dynamic>> _pendingOps = [];
  List<Map<String, dynamic>> _pendingPhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final ops = await DatabaseService.instance.getPendingOperations();
      final photos = await DatabaseService.instance.getPendingPhotos();
      if (mounted) {
        setState(() {
          _pendingOps = ops;
          _pendingPhotos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading offline data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Pendiente por Sincronizar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF10447E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading 
        ? ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => _buildSkeletonCard(),
          )
        : (_pendingOps.isEmpty && _pendingPhotos.isEmpty)
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   if (_pendingOps.isNotEmpty) ...[
                     const Padding(
                       padding: EdgeInsets.only(bottom: 12),
                       child: Text('Acciones de Órdenes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10447E))),
                     ),
                     ..._pendingOps.map((op) => _buildOperationCard(op)).toList(),
                     const SizedBox(height: 24),
                   ],
                   if (_pendingPhotos.isNotEmpty) ...[
                     const Padding(
                       padding: EdgeInsets.only(bottom: 12),
                       child: Text('Evidencias Fotográficas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10447E))),
                     ),
                     ..._pendingPhotos.map((photo) => _buildPhotoCard(photo)).toList(),
                   ]
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
           Icon(Icons.cloud_done, size: 80, color: Colors.green.withOpacity(0.5)),
           const SizedBox(height: 16),
           const Text('Todo está sincronizado', style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           const Text('No hay datos pendientes por subir al servidor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
           const SizedBox(height: 24),
           ElevatedButton.icon(
             onPressed: _loadData, 
             icon: const Icon(Icons.refresh), 
             label: const Text('Comprobar de nuevo'),
             style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10447E),
                foregroundColor: Colors.white,
             )
           )
         ],
       ),
     );
  }

  Widget _buildOperationCard(Map<String, dynamic> op) {
    final type = op['operation_type'] as String;
    final orderNumber = op['order_number'] as String;
    final error = op['last_error'] as String?;
    
    // Map internal types to readable text
    String labelText = type;
    IconData icon = Icons.sync;
    Color color = Colors.blue;

    switch (type) {
      case 'accept':
        labelText = 'Aceptar Orden';
        icon = Icons.assignment_turned_in;
        color = Colors.orange;
        break;
      case 'close':
        labelText = 'Finalizar Orden';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'reportOnSite':
        labelText = 'Reportar en Sitio';
        icon = Icons.location_on;
        color = Colors.indigo;
        break;
      case 'reject':
        labelText = 'Rechazar Orden';
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'reassign':
      case 'reschedule':
        labelText = 'Reasignar/Reprogramar';
        icon = Icons.next_plan;
        color = Colors.amber;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text('Orden #$orderNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Acción: $labelText'),
            if (error != null && error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Error: $error', style: const TextStyle(color: Colors.red, fontSize: 12)),
              )
          ],
        ),
        trailing: const Icon(Icons.cloud_upload_outlined, color: Colors.grey),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final path = photo['image_path'] as String;
    final orderNumber = photo['order_number'] as String;
    final tipo = photo['tipo'] as String?;
    final error = photo['last_error'] as String?;
    final file = File(path);
    final exists = file.existsSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: exists 
            ? Image.file(file, width: 60, height: 60, fit: BoxFit.cover)
            : Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
        ),
        title: Text('Orden #$orderNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tipo ?? 'Foto General', style: const TextStyle(fontSize: 13)),
            if (error != null && error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Error: $error', style: const TextStyle(color: Colors.red, fontSize: 12)),
              )
          ],
        ),
        trailing: const Icon(Icons.image, color: Colors.grey),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white60);
  }
}
