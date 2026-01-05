import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'manage_order_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/connection_status_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/glass_card.dart';
import 'signature_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  const OrderDetailScreen({super.key, required this.orderNumber});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  Orden? _currentOrder;
  bool _isLoading = true;
  String? _error;
  bool _hasStateChanged = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    // SyncService.instance.sync(); // Removed
  }
  
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    // Cargar desde caché primero
    try {
      final cachedOrder = await _orderRepo.getOrderDetails(widget.orderNumber);
      if (mounted) {
        setState(() {
          _currentOrder = cachedOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Si no hay caché, intentar desde servidor
      try {
        final order = await _orderRepo.getOrderDetails(widget.orderNumber);
        if (mounted) {
          setState(() {
            _currentOrder = order;
            _isLoading = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _error = err.toString();
            _isLoading = false;
          });
        }
      }
    }
  }
   Future<void> _launchCaller(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la aplicación de llamadas para el número $phoneNumber')),
        );
      }
    }
  }

  Future<void> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: Text(confirmText),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _takeOrder() async {
    if (_isLoading) return; 
    
    setState(() => _isLoading = true);
    
    try {
      final updatedOrder = await _orderRepo.acceptOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden tomada. Estado: En Proceso.'), backgroundColor: Colors.green),
        );
        _loadOrderDetails();
      }
    } catch (e) {
      if (mounted) {
        // Mostrar mensaje crudo del backend para mejorar debug
        final msg = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}, textColor: Colors.white),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _rejectOrder() async {
    setState(() => _isLoading = true);
    try {
      await _orderRepo.rejectOrder(widget.orderNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden rechazada.'), backgroundColor: Colors.orange),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reportOnSite() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final updatedOrder = await _orderRepo.reportOnSite(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reportado en sitio exitosamente.'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reportar en sitio: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeOrder() async {
    // 1. Navegar a pantalla de firmas
    final signatures = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureScreen(orderNumber: widget.orderNumber),
      ),
    );

    if (signatures == null) return; // Cancelado por usuario

    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    // Preparar datos de cierre
    final closingData = {
      'firma_tecnico': base64Encode(signatures['technician']), // Asume Uint8List
      'firma_suscriptor': base64Encode(signatures['subscriber']),
    };

    try {
      final updatedOrder = await _orderRepo.closeOrder(widget.orderNumber, closingData);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden cerrada exitosamente.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cerrar orden: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasStateChanged ? 'refresh' : null);
        return false;
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Detalles de Orden #${widget.orderNumber}'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87, // Black text for AppBar
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: ConnectionStatusIndicator(),
              ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading && _currentOrder == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }
    if (_error != null) {
      return Center(child: Text('Error al cargar detalles: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_currentOrder == null) {
      return const Center(child: Text('No se encontraron datos.', style: TextStyle(color: Colors.black54)));
    }
    
    final orden = _currentOrder!;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadOrderDetails,
          color: Colors.blue,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
            child: _buildDetailSection(orden),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator(color: Colors.blue)),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16.0),
             decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: _buildActionButtons(orden),
          ),
        ),
      ],
    );
  }

  // ... (Action buttons methods unchanged regarding colors as they use ElevatedButtons which are self-contained, except text styles if needed)

  Widget _buildActionButtons(Orden orden) {
    // ... Copying logic but ensuring it matches
    final status = orden.status.toLowerCase().trim().replaceAll(' ', '_');
    
    // Flujo 1: Asignada -> Tomar Orden -> En Proceso
    if (status == Orden.ESTADO_ASIGNADA) {
       return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Rechazar Orden',
                content: '¿Está seguro de rechazar la orden?',
                confirmText: 'Rechazar',
                onConfirm: _rejectOrder,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Tomar Orden',
                content: 'Al tomar la orden, pasará a estado "En Proceso".',
                confirmText: 'Tomar Orden',
                onConfirm: _takeOrder,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF), // iOS Blue
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 elevation: 4,
                 shadowColor: Colors.blue.withOpacity(0.4),
              ),
              child: const Text('Tomar Orden', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }
    
    // Flujo 2: En Proceso -> Reportar En Sitio -> En Sitio
    if (status == Orden.ESTADO_EN_PROCESO) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.location_on, color: Colors.white),
            label: const Text('Llegué al Sitio (Reportar)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showConfirmationDialog(
              title: 'Confirmar Llegada',
              content: '¿Confirmas que has llegado al sitio del cliente?',
              confirmText: 'Confirmar',
              onConfirm: _reportOnSite,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF), // iOS Blue
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 12),
           OutlinedButton.icon(
            icon: const Icon(Icons.edit_note),
            label: const Text('Agregar Observaciones'),
            onPressed: () async {
               final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageOrderScreen(orden: orden),
                ),
              );
              if (result == 'refresh' && mounted) _loadOrderDetails();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.blueGrey,
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }
    
    // Flujo 3: En Sitio -> Finalizar -> Ejecutada
    if (status == Orden.ESTADO_EN_SITIO) { 
       return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('Finalizar Orden', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _closeOrder, // Llama a firmas y cierre
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759), // iOS Green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
               shadowColor: Colors.green.withOpacity(0.4),
            ),
          ),
           const SizedBox(height: 12),
           OutlinedButton.icon(
            icon: const Icon(Icons.edit_note),
            label: const Text('Gestionar Detalles'),
            onPressed: () async {
               final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageOrderScreen(orden: orden),
                ),
              );
              if (result == 'refresh' && mounted) _loadOrderDetails();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
               foregroundColor: Colors.blueGrey,
               side: const BorderSide(color: Colors.black12),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Text(
        'Orden ${orden.status.toUpperCase()}',
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailSection(Orden orden) {
    // ...
    final dateFormatter = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');
    
    return Column(
      children: [
        _buildGlassCard(
          child: _buildDetailCard('Información Principal', [
            _buildDetailRow('Estado', orden.status.toUpperCase(), highlight: true),
            _buildDetailRow('Número de Orden', orden.numeroOrden),
            _buildDetailRow('Nombre Cliente', orden.nombreCliente),
            _buildDetailRow('Fecha Creación', dateFormatter.format(orden.fechaHora)),
            if (orden.fechaLlegada != null)
              _buildDetailRow('Fecha Llegada', dateFormatter.format(orden.fechaLlegada!)),
          ]),
        ),
        _buildGlassCard(
          child: _buildDetailCard('Información de Contacto', [
            _buildDetailRow('Celular', orden.celular),
            _buildDetailRow('Dirección', orden.direccion),
            _buildDetailRow('Observaciones', orden.observaciones),
          ]),
        ),
        if (orden.macRouter != null || orden.macOnt != null || orden.solucionTecnico != null)
        _buildGlassCard(
          child: _buildDetailCard('Detalles Técnicos', [
            _buildDetailRow('MAC Router', orden.macRouter),
            _buildDetailRow('MAC ONT', orden.macOnt),
            _buildDetailRow('MAC Bridge', orden.macBridge),
            _buildDetailRow('Otros Equipos', orden.otrosEquipos),
            _buildDetailRow('Solución', orden.solucionTecnico),
          ]),
        ),
         if (orden.articulos != null && orden.articulos!.isNotEmpty)
        _buildGlassCard(
          child: _buildDetailCard('Artículos', [
             ...orden.articulos!.map((art) => Text('• $art', style: const TextStyle(color: Colors.black54))).toList(),
          ]),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 20.0,
        sigmaX: 10.0,
        sigmaY: 10.0,
        color: Colors.white.withOpacity(0.7), // Frosted White
        child: child,
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
          const Divider(height: 20, thickness: 1, color: Colors.black12),
          ...children,
        ],
      ),
    );
  }
    // MÉTODO ACTUALIZADO PARA HACER EL NÚMERO CLICKEABLE
  Widget _buildDetailRow(String label, String? value, {bool highlight = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    // Si la etiqueta es "Celular", hacemos el valor clickeable
    bool isPhone = label.toLowerCase() == 'celular';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(
            child: isPhone
              ? InkWell(
                  onTap: () => _launchCaller(value),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                    color: highlight ? Colors.orangeAccent[700] : Colors.black87,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}