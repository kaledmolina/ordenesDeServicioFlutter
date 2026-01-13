import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../services/sync_service.dart';
import 'manage_order_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/connection_status_indicator.dart';
import 'signature_screen.dart';
import '../widgets/processing_overlay.dart';

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
  String _loadingMessage = 'Procesando...';

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }
  
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final cachedOrder = await _orderRepo.getOrderDetails(widget.orderNumber);
      if (mounted) setState(() { _currentOrder = cachedOrder; _isLoading = false; });
    } catch (e) {
      try {
        final order = await _orderRepo.getOrderDetails(widget.orderNumber);
        if (mounted) setState(() { _currentOrder = order; _isLoading = false; });
      } catch (err) {
        if (mounted) setState(() { _error = err.toString(); _isLoading = false; });
      }
    }
  }

  // --- ACTIONS ---
  Future<void> _takeOrder() async {
    setState(() {
       _isLoading = true;
       _loadingMessage = 'Iniciando ruta...';
    });
    try {
      final hasActive = await _orderRepo.hasActiveOrder();
      if (hasActive) {
        if (mounted) _msg('Ya tienes una orden en proceso. Ejecútala para tomar otra.', Colors.orange);
        return;
      }
      final updatedOrder = await _orderRepo.acceptOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        _hasStateChanged = true;
        _msg('Orden iniciada. ¡Buen viaje!', Colors.green);
      }
    } catch (e) {
      if (mounted) _msg('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectOrder() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Rechazando orden...';
    });
    try {
      await _orderRepo.rejectOrder(widget.orderNumber);
      if (mounted) {
        _msg('Orden rechazada.', Colors.orange);
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) _msg('Error al rechazar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reportOnSite() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Confirmando llegada...';
    });
    try {
      final updatedOrder = await _orderRepo.reportOnSite(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        _hasStateChanged = true;
        _msg('Has confirmado tu llegada al sitio.', Colors.blue);
      }
    } catch (e) {
      if (mounted) _msg('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _showConfirmationDialog({required String title, required String content, required String confirmText, required VoidCallback onConfirm}) async {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(child: const Text('Cancelar', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10447E), foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(context); onConfirm(); },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

   Future<void> _launchCaller(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasStateChanged ? 'refresh' : null);
        return false;
      },
      child: AppBackground(
          child: ProcessingOverlay(
            isLoading: _isLoading && _currentOrder != null,
            message: _loadingMessage,
            child: Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                title: Text('Orden N° ${widget.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                foregroundColor: const Color(0xFF111827),
                actions: const [
                  Padding(padding: EdgeInsets.only(right: 16.0), child: ConnectionStatusIndicator()),
                ],
              ),
              body: _buildBody(),
              bottomNavigationBar: _currentOrder != null ? _buildBottomActionArea(_currentOrder!) : null,
            ),
          ),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading && _currentOrder == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10447E)));
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_currentOrder == null) {
      return const Center(child: Text('No se encontraron datos.', style: TextStyle(color: Colors.grey)));
    }
    
    final orden = _currentOrder!;
    
    return RefreshIndicator(
      onRefresh: _loadOrderDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Status Stepper
            _buildStatusStepper(orden.status),
            const SizedBox(height: 20),
            
            // 2. Details
            _buildDetailSection(orden),
            const SizedBox(height: 80), // Space for Bottom Bar
          ],
        ),
      ),
    );
  }

  // --- STEPPER WIDGET ---
  Widget _buildStatusStepper(String currentStatus) {
    final steps = ['Asignada', 'En Proceso', 'En Sitio', 'Ejecutada'];
    
    // Normalize status for comparison
    String normalizedStatus = currentStatus.toLowerCase().trim().replaceAll('_', ' ');
    if (normalizedStatus == 'pendiente') normalizedStatus = 'asignada'; // Fallback mapping if needed

    int currentStepIndex = steps.indexWhere((s) => s.toLowerCase() == normalizedStatus);
    
    // Fallback if not found (e.g., 'cerrada' maps to 'ejecutada' visually)
    if (currentStepIndex == -1) {
        if (normalizedStatus.contains('cerrada') || normalizedStatus.contains('terminada')) {
            currentStepIndex = 3;
        } else {
            currentStepIndex = 0;
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          final isCompleted = index <= currentStepIndex;
          final isCurrent = index == currentStepIndex;
          final color = isCompleted ? (isCurrent ? const Color(0xFF10447E) : Colors.green) : Colors.grey.shade300;
          
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: isCompleted 
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? const Color(0xFF10447E) : Colors.grey
                  ),
                )
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- BOTTOM ACTION AREA ---
  Widget _buildBottomActionArea(Orden orden) {
    final status = orden.status.toLowerCase().trim().replaceAll(' ', '_');

    if (status == 'ejecutada' || status == 'cancelada' || status == 'rechazada') {
       return Container(height: 0); 
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildActionButtons(orden, status),
        ),
      ),
    );
  }

  // --- DIALOGS FOR SPECIAL ACTIONS ---
  Future<void> _promptForObservationAndClose(String solutionType, String title, String confirmText) async {
      final obsController = TextEditingController();
      await showDialog(
        context: context, 
        builder: (_) => AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text('Por favor, indica el motivo:'),
               const SizedBox(height: 10),
               TextField(
                 controller: obsController,
                 decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Escribe el motivo aquí...'),
                 maxLines: 3,
               )
             ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                  if (obsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El motivo es obligatorio'), backgroundColor: Colors.orange));
                      return;
                  }
                  Navigator.pop(context); // Close dialog
                  setState(() {
                     _isLoading = true;
                     _loadingMessage = 'Procesando solicitud...';
                  });
                  try {
                     final closingData = {
                        'solucion_tecnico': solutionType,
                        'observaciones': obsController.text.trim(),
                        // Minimal required fields to pass validation if any
                        'firma_tecnico': null,
                        'firma_suscriptor': null,
                     };
                     await _orderRepo.closeOrder(widget.orderNumber, closingData);
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Orden procesada: $solutionType'), backgroundColor: Colors.green));
                        Navigator.of(context).popUntil((route) => route.isFirst);
                     }
                  } catch (e) {
                     if (mounted) _msg('Error: $e', Colors.red);
                  } finally {
                     if (mounted) setState(() => _isLoading = false);
                  }
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10447E), foregroundColor: Colors.white),
              child: Text(confirmText)
            ),
          ],
        )
      );
  }

  List<Widget> _buildActionButtons(Orden orden, String status) {
    // 1. ASIGNADA
    if (status == Orden.ESTADO_ASIGNADA) {
      return [
        const Text(
          '¿Estás listo para iniciar?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _promptForObservationAndClose('Solicitar Cierre', 'Solicitar Cierre', 'Enviar Solicitud'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Solicitar Cierre'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _showConfirmationDialog(
                  title: 'Iniciar Orden',
                  content: 'El cliente será notificado de que estás en camino.',
                  confirmText: 'Iniciar Ahora',
                  onConfirm: _takeOrder,
                ),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text('INICIAR RUTA', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10447E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ];
    }

    // 2. EN PROCESO
    if (status == Orden.ESTADO_EN_PROCESO) {
      return [
        const Text(
          'Dirígete a la ubicación del cliente',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => _showConfirmationDialog(
            title: 'Llegada a Sitio',
            content: '¿Has llegado a la ubicación del cliente?',
            confirmText: 'Sí, estoy aquí',
            onConfirm: _reportOnSite,
          ),
          icon: const Icon(Icons.location_on, color: Colors.white),
          label: const Text('CONFIRMAR LLEGADA', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10447E), 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 5,
          ),
        ),
      ];
    }

    // 3. EN SITIO
    if (status == Orden.ESTADO_EN_SITIO) {
      return [
        const Text(
          'Completa el formulario para finalizar',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
             Expanded(
               child: OutlinedButton(
                 onPressed: () => _promptForObservationAndClose('Reprogramar', 'Reprogramar Orden', 'Reprogramar'),
                 style: OutlinedButton.styleFrom(
                   foregroundColor: Colors.orange,
                   side: const BorderSide(color: Colors.orange),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 child: const Text('Reprogramar', style: TextStyle(fontSize: 12)),
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               flex: 2,
               child: ElevatedButton.icon(
                 onPressed: () async {
                   final result = await Navigator.of(context).push(
                     MaterialPageRoute(builder: (_) => ManageOrderScreen(orden: orden)),
                   );
                   if (result == 'refresh' && mounted) _loadOrderDetails();
                 },
                 icon: const Icon(Icons.assignment_turned_in, color: Colors.white, size: 20),
                 label: const Text('GESTIONAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF10447E),
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   elevation: 5,
                 ),
               ),
             ),
          ],
        ),
      ];
    }

    return [const SizedBox.shrink()];
  }

  // --- HELPERS ---
  Widget _buildDetailSection(Orden orden) {
    // final dateFormatter = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');
    
    return Column(
      children: [
        _buildInfoContainer('Información General', [
            _buildDetailRow('Cliente', orden.nombreCliente, isTitle: true),
            if (orden.cedula != null) _buildDetailRow('Cédula', orden.cedula),
            _buildDetailRow('Dirección', orden.direccion, icon: Icons.map),
            if (orden.barrio != null) _buildDetailRow('Barrio', orden.barrio),
            _buildDetailRow('Celular', orden.celular, icon: Icons.phone, isPhone: true),
            if (orden.otroTelefono != null && orden.otroTelefono!.isNotEmpty) _buildDetailRow('Otro Teléfono', orden.otroTelefono, icon: Icons.phone_android, isPhone: true),
            if (orden.solicitudSuscriptor != null) _buildDetailRow('Reporte', orden.solicitudSuscriptorLabel, icon: Icons.report_problem),
        ]),
        const SizedBox(height: 16),
        _buildInfoContainer('Detalles Técnicos', [
             if (orden.codigoContrato != null) _buildDetailRow('Código', orden.codigoContrato),
             _buildDetailRow('Plan', orden.planInternet),
             _buildDetailRow('Saldo', orden.saldoCliente),
             if (orden.macRouter != null) _buildDetailRow('MAC Router', orden.macRouter),
             if (orden.observaciones != null) _buildDetailRow('Observaciones', orden.observaciones),
             if (orden.novedadesNoc != null) _buildNocRow(orden.novedadesNoc!),
        ]),
         const SizedBox(height: 16),
         if (orden.articulos != null && orden.articulos!.isNotEmpty)
          _buildInfoContainer('Artículos', [
             _buildArticleList(orden.articulos!),
          ]),
      ],
    );
  }

  Widget _buildInfoContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10447E))),
          const Divider(height: 24),
          ...children
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isTitle = false, IconData? icon, bool isPhone = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
             Icon(icon, size: 16, color: Colors.grey),
             const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isTitle) Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                isPhone 
                ? InkWell(
                    onTap: () => _launchCaller(value),
                    child: Text(value, style: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold)),
                  )
                : Text(value, style: TextStyle(fontSize: 15, fontWeight: isTitle ? FontWeight.bold : FontWeight.w500, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildArticleList(List<dynamic> articulos) {
     return Column(
      children: articulos.map<Widget>((art) {
        final map = art is Map ? art : {};
        final nombre = map['articulo']?.toString() ?? map['grupo_articulo']?.toString() ?? 'Artículo';
        final cantidad = map['cantidad']?.toString() ?? '0';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w500))),
               Text('x$cantidad', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNocRow(String message) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50], 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red[800]),
                const SizedBox(width: 8),
                Text('NOVEDADES NOC', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: Colors.red[900], fontSize: 14)),
        ],
      ),
    );
  }
}
