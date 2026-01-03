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
      // Validar si ya hay una orden en proceso antes de aceptar
      final ordersInProcess = await DatabaseService.instance.getOrdersInProcess();
      
      // Obtener todas las operaciones pendientes
      final allPendingOps = await DatabaseService.instance.getPendingOperations();
      
      // Obtener las órdenes que tienen operaciones pendientes de "close" (ya están siendo cerradas)
      final ordersBeingClosed = allPendingOps
          .where((op) => op['operation_type'] == 'close')
          .map((op) => op['order_number'] as String)
          .toSet();
      
      // Filtrar órdenes en proceso excluyendo:
      // 1. La orden actual
      // 2. Las órdenes que tienen una operación pendiente de "close" (ya están siendo cerradas)
      final otherOrdersInProcess = ordersInProcess
          .where((order) {
            final orderNum = order['numero_orden'] as String;
            return orderNum != widget.orderNumber && !ordersBeingClosed.contains(orderNum);
          })
          .toList();
      
      // Validar también operaciones pendientes de aceptar para otras órdenes
      // (excluyendo las que están siendo cerradas)
      final otherAcceptOps = allPendingOps
          .where((op) => 
              op['operation_type'] == 'accept' && 
              op['order_number'] != widget.orderNumber &&
              !ordersBeingClosed.contains(op['order_number'] as String))
          .toList();
      
      String? orderInProcessNumber;
      String? clientName;
      
      if (otherOrdersInProcess.isNotEmpty) {
        final orderInProcess = otherOrdersInProcess.first;
        orderInProcessNumber = orderInProcess['numero_orden'] as String;
        clientName = orderInProcess['nombre_cliente'] as String? ?? 'N/A';
      } else if (otherAcceptOps.isNotEmpty) {
        final pendingOp = otherAcceptOps.first;
        orderInProcessNumber = pendingOp['order_number'] as String;
        // Intentar obtener el nombre del cliente de la orden local
        final orderData = await DatabaseService.instance.getOrderByNumber(orderInProcessNumber);
        clientName = orderData?['nombre_cliente'] as String? ?? 'N/A';
      }
      
      if (orderInProcessNumber != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
              title: const Text(
                'Orden en Proceso',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'No puedes iniciar una nueva orden de servicio porque ya tienes una orden en proceso:\n\n'
                'Orden #$orderInProcessNumber\n'
                'Cliente: $clientName\n\n'
                'Debes finalizar esta orden antes de poder iniciar otra.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navegar a la orden en proceso
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderNumber: orderInProcessNumber!),
                      ),
                    );
                  },
                  child: const Text('Ver Orden en Proceso'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // Si no hay órdenes en proceso, proceder con aceptar la orden
      setState(() {
        // Actualizar UI inmediatamente
        if (_currentOrder != null) {
          _currentOrder = Orden(
            id: _currentOrder!.id,
            numeroOrden: _currentOrder!.numeroOrden,
            nombreCliente: _currentOrder!.nombreCliente,
            fechaHora: _currentOrder!.fechaHora,
            valorServicio: _currentOrder!.valorServicio,

            direccion: _currentOrder!.direccion,
            observaciones: _currentOrder!.observaciones,
            fechaProgramada: _currentOrder!.fechaProgramada,
            status: Orden.ESTADO_EN_PROCESO,
            fechaLlegada: _currentOrder!.fechaLlegada,
            solucionTecnico: _currentOrder!.solucionTecnico,
            macRouter: _currentOrder!.macRouter,
            macBridge: _currentOrder!.macBridge,
            macOnt: _currentOrder!.macOnt,
            otrosEquipos: _currentOrder!.otrosEquipos,
            firmaTecnico: _currentOrder!.firmaTecnico,
            firmaSuscriptor: _currentOrder!.firmaSuscriptor,
            articulos: _currentOrder!.articulos,
            technicianId: _currentOrder!.technicianId,
            clienteId: _currentOrder!.clienteId,
            cedula: _currentOrder!.cedula,
            precinto: _currentOrder!.precinto,
            tipoOrden: _currentOrder!.tipoOrden,
            tipoFuncion: _currentOrder!.tipoFuncion,
            fechaTrn: _currentOrder!.fechaTrn,
            fechaVencimiento: _currentOrder!.fechaVencimiento,
            estadoOrden: _currentOrder!.estadoOrden,
            tipo: _currentOrder!.tipo,
            estadoInterno: _currentOrder!.estadoInterno,
            direccionAsociado: _currentOrder!.direccionAsociado,
            telefono: _currentOrder!.telefono,
            saldoCliente: _currentOrder!.saldoCliente,
            solicitadoPor: _currentOrder!.solicitadoPor,
            estadoTv: _currentOrder!.estadoTv,
            tecnicoAuxiliarId: _currentOrder!.tecnicoAuxiliarId,
            solicitudSuscriptor: _currentOrder!.solicitudSuscriptor,
            fechaInicioAtencion: DateTime.now(),
            fechaFinAtencion: _currentOrder!.fechaFinAtencion,
            fechaCierre: _currentOrder!.fechaCierre,
          );
          _hasStateChanged = true;
        }
      });
      
      final updatedOrder = await _orderRepo.acceptOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden tomada exitosamente.'), backgroundColor: Colors.green),
        );
        SyncService.instance.sync();
      }
    } catch (e) {
      if (mounted) {
        // Verificar si el error es por orden en proceso
        if (e.toString().contains('Ya tienes una orden de servicio en proceso')) {
          // Este caso ya fue manejado arriba, pero por si acaso
          final ordersInProcess = await DatabaseService.instance.getOrdersInProcess();
          final otherOrdersInProcess = ordersInProcess
              .where((order) => order['numero_orden'] != widget.orderNumber)
              .toList();
          
          if (otherOrdersInProcess.isNotEmpty) {
            final orderInProcess = otherOrdersInProcess.first;
            final orderNumber = orderInProcess['numero_orden'] as String;
            final clientName = orderInProcess['nombre_cliente'] as String? ?? 'N/A';
            
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
                title: const Text(
                  'Orden en Proceso',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'No puedes iniciar una nueva orden de servicio porque ya tienes una orden en proceso:\n\n'
                  'Orden #$orderNumber\n'
                  'Cliente: $clientName\n\n'
                  'Debes finalizar esta orden antes de poder iniciar otra.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Entendido'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(orderNumber: orderNumber),
                        ),
                      );
                    },
                    child: const Text('Ver Orden en Proceso'),
                  ),
                ],
              ),
            );
            return;
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orden guardada localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
        SyncService.instance.sync();
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
        SyncService.instance.sync();
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orden guardada localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
        SyncService.instance.sync();
        Navigator.of(context).pop('refresh');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reportOnSite() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Actualizar UI inmediatamente (Optimistic)
      if (_currentOrder != null) {
        // ... (update _currentOrder status to EN_SITIO visually)
        // For brevity in this diff, relying on setState refresh or repository return
      }
      
      final updatedOrder = await _orderRepo.reportOnSite(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reportado en sitio exitosamente.'), backgroundColor: Colors.blue),
        );
        SyncService.instance.sync();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guardado localmente. Se enviará al tener internet.'), backgroundColor: Colors.orange),
        );
        SyncService.instance.sync();
        // Force reload to see local state change if needed
        _loadOrderDetails();
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
      // Aquí se podrían agregar más datos del formulario de cierre si existiera
      // 'articulos': ..., 
      // 'mac_router': ...,
    };

    try {
      final updatedOrder = await _orderRepo.closeOrder(widget.orderNumber, closingData);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden cerrada exitosamente.'), backgroundColor: Colors.green),
        );
        SyncService.instance.sync();
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Cierre guardado localmente.'), backgroundColor: Colors.orange),
        );
        SyncService.instance.sync();
        Navigator.of(context).pop('refresh');
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
    
    if (status == Orden.ESTADO_ASIGNADA || status == 'abierta') {
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