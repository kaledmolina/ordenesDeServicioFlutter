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
    SyncService.instance.sync();
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
    if (_isLoading) return; // Prevenir múltiples llamadas
    
    setState(() => _isLoading = true);
    
    try {
      final updatedOrder = await _orderRepo.acceptOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden tomada exitosamente.'), backgroundColor: Colors.green),
        );
        // Force refresh of the whole screen to reflect new state
        _loadOrderDetails();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error al tomar la orden.';
        if (e.toString().contains('No autorizado')) {
          errorMessage = 'No tienes permiso para tomar esta orden.';
        } else if (e.toString().contains('no se puede procesar')) {
          errorMessage = 'La orden no está en un estado válido para ser tomada.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
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
            foregroundColor: Colors.black87,
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error al cargar detalles: $_error'));
    }
    if (_currentOrder == null) {
      return const Center(child: Text('No se encontraron datos.'));
    }
    
    final orden = _currentOrder!;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadOrderDetails,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
            child: _buildDetailSection(orden),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: _buildActionButtons(orden),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Orden orden) {
    final status = orden.status.toLowerCase().replaceAll(' ', '_');
    
    if (status == Orden.ESTADO_ASIGNADA) {
       // ... (existing Accept/Reject logic)
       return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Rechazar Orden',
                content: 'Si rechaza la orden, ya no podrá tomarla y se notificará al operador. ¿Está seguro?',
                confirmText: 'Sí, Rechazar',
                onConfirm: _rejectOrder,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Tomar Orden',
                content: '¿Está seguro de que desea tomar esta orden?',
                confirmText: 'Sí, Tomar',
                onConfirm: _takeOrder,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Tomar Orden', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }
    
    if (status == Orden.ESTADO_EN_PROCESO) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_document, color: Colors.white),
            label: const Text('Gestionar Orden', style: TextStyle(color: Colors.white)),
            onPressed: () async {
               final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageOrderScreen(orden: orden),
                ),
              );
              if (result == 'refresh' && mounted) _loadOrderDetails();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.location_on, color: Colors.white),
            label: const Text('Reportar En Sitio', style: TextStyle(color: Colors.white)),
            onPressed: () => _showConfirmationDialog(
              title: 'Reportar en Sitio',
              content: '¿Confirmas que has llegado al sitio del cliente?',
              confirmText: 'Sí, estoy aquí',
              onConfirm: _reportOnSite,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      );
    }
    
    if (status == Orden.ESTADO_EN_SITIO) { // estado_en_sitio logic
       return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_document, color: Colors.white),
            label: const Text('Gestionar Orden', style: TextStyle(color: Colors.white)),
            onPressed: () async {
               final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageOrderScreen(orden: orden),
                ),
              );
              if (result == 'refresh' && mounted) _loadOrderDetails();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('Finalizar Orden', style: TextStyle(color: Colors.white)),
            onPressed: _closeOrder, // Calls signature flow
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetailSection(Orden orden) {
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
             ...orden.articulos!.map((art) => Text('• $art')).toList(), // Simple list for now
          ]),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 16.0,
        sigmaX: 5.0,
        sigmaY: 5.0,
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
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20, thickness: 1),
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
                      color: Colors.blue.shade800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                    color: highlight ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}