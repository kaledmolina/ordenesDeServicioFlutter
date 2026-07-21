import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../models/photo_status_model.dart';
import '../repositories/photo_repository.dart';
import 'photo_view_screen.dart';
import '../services/sync_service.dart';
import 'manage_order_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/connection_status_indicator.dart';
import 'signature_screen.dart';
import '../widgets/processing_overlay.dart';
import '../services/auth_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  final VoidCallback? onOrderUpdated;
  const OrderDetailScreen({super.key, required this.orderNumber, this.onOrderUpdated});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  Orden? _currentOrder;
  List<PhotoDisplay> _photos = [];
  bool _isLoading = true;
  String? _error;

  bool _hasStateChanged = false;
  String _loadingMessage = 'Procesando...';

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }
  
  void _safePop([String? result]) {
    final finalResult = result ?? (_hasStateChanged ? 'refresh' : null);
    if (widget.onOrderUpdated != null && finalResult == 'refresh') {
      widget.onOrderUpdated!();
    } else {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(finalResult);
      }
    }
  }
  
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final cachedOrder = await _orderRepo.getOrderDetails(widget.orderNumber);
      final cachedPhotos = await _photoRepo.getPhotos(widget.orderNumber);
      if (mounted) setState(() { _currentOrder = cachedOrder; _photos = cachedPhotos; _isLoading = false; });
    } catch (e) {
      try {
        final order = await _orderRepo.getOrderDetails(widget.orderNumber);
        final fetchedPhotos = await _photoRepo.getPhotos(widget.orderNumber);
        if (mounted) setState(() { _currentOrder = order; _photos = fetchedPhotos; _isLoading = false; });
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
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.mobile) && 
          !connectivityResult.contains(ConnectivityResult.wifi) &&
          !connectivityResult.contains(ConnectivityResult.ethernet)) {
        if (mounted) _msg('Para iniciar una ruta debes estar conectado a internet.', Colors.red);
        return;
      }

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
        _hasStateChanged = true;
        _safePop('refresh');
      }
    } catch (e) {
      if (mounted) _msg('Error al rechazar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelStart() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Cancelando ruta...';
    });
    try {
      final updatedOrder = await _orderRepo.cancelStartOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        _hasStateChanged = true;
        _msg('Inicio de ruta cancelado. La orden vuelve a estar Asignada.', Colors.blue);
      }
    } catch (e) {
      if (mounted) _msg('Error al cancelar inicio: $e', Colors.red);
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
        _safePop();
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
            _buildStatusStepper(orden.status)
                .animate().fadeIn().slideY(begin: 0.2, end: 0),
            const SizedBox(height: 20),
            
            // 2. Details
            _buildDetailSection(orden)
                .animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
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
  Future<void> _promptForReassign() async {
      final obsController = TextEditingController();
      final user = await AuthService.instance.getCurrentUser();
      if (!mounted) return;
      await showModalBottomSheet(
        context: context, 
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (dialogCtx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               const Text('Reasignar Orden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
               const SizedBox(height: 15),
               const Text('Por favor, indica el motivo detallado de la reasignación (mínimo 15 caracteres):'),
               const SizedBox(height: 10),
               TextField(
                 controller: obsController,
                 decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Motivo de la falla...'),
                 maxLines: 3,
                 maxLength: 150,
               ),
               const SizedBox(height: 15),
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
                   const SizedBox(width: 10),
                   ElevatedButton(
                     onPressed: () async {
                         if (obsController.text.trim().length < 15) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El motivo debe tener al menos 15 caracteres'), backgroundColor: Colors.orange));
                             return;
                         }
                         
                         final now = DateTime.now();
                         final formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(now);
                         final userName = user?.name ?? 'Técnico';
                         final finalMotivo = '${obsController.text.trim()}\n[Escrito por: $userName el $formattedDate]';
                         
                         Navigator.pop(dialogCtx); // Close dialog
                         setState(() {
                            _isLoading = true;
                            _loadingMessage = 'Procesando reasignación...';
                         });
                         try {
                            await _orderRepo.reassignOrder(widget.orderNumber, finalMotivo);
                            if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden marcada para reasignar'), backgroundColor: Colors.blue));
                               _hasStateChanged = true;
                               _safePop('refresh');
                            }
                         } catch (e) {
                            if (mounted) _msg('Error al reasignar: $e', Colors.red);
                         } finally {
                            if (mounted) setState(() => _isLoading = false);
                         }
                     }, 
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10447E), foregroundColor: Colors.white),
                     child: const Text('Reasignar')
                   ),
                 ],
               ),
               const SizedBox(height: 20),
             ],
          ),
        )
      );
  }

  Future<void> _promptForReschedule() async {
      final obsController = TextEditingController();
      final user = await AuthService.instance.getCurrentUser();
      if (!mounted) return;
      DateTime? selectedDate;
      String? selectedJornada;
      
      await showModalBottomSheet(
        context: context, 
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   const Text('Reprogramar Orden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                   const SizedBox(height: 15),
                   const Text('Fecha de reprogramación:'),
                   const SizedBox(height: 5),
                   InkWell(
                     onTap: () async {
                        final date = await showDatePicker(
                          context: context, 
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30))
                        );
                        if (date != null) {
                           setDialogState(() => selectedDate = date);
                        }
                     },
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                       decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate!) : 'Seleccionar fecha'),
                           const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                         ],
                       ),
                     ),
                   ),
                   const SizedBox(height: 15),
                   const Text('Jornada:'),
                   const SizedBox(height: 5),
                   DropdownButtonFormField<String>(
                     decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                     value: selectedJornada,
                     hint: const Text('Seleccionar jornada'),
                     items: ['Mañana', 'Tarde'].map((String value) {
                       return DropdownMenuItem<String>(
                         value: value,
                         child: Text(value),
                       );
                     }).toList(),
                     onChanged: (newValue) {
                       setDialogState(() => selectedJornada = newValue);
                     },
                   ),
                   const SizedBox(height: 15),
                   const Text('Motivo:'),
                   const SizedBox(height: 5),
                   TextField(
                     controller: obsController,
                     decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Motivo...'),
                     maxLines: 2,
                   ),
                   const SizedBox(height: 15),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
                       const SizedBox(width: 10),
                       ElevatedButton(
                         onPressed: () async {
                             if (selectedDate == null) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar una fecha'), backgroundColor: Colors.orange));
                                 return;
                             }
                             if (selectedJornada == null) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar una jornada'), backgroundColor: Colors.orange));
                                 return;
                             }
                             if (obsController.text.trim().isEmpty) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El motivo es obligatorio'), backgroundColor: Colors.orange));
                                 return;
                             }
                             
                             final now = DateTime.now();
                             final formattedNow = DateFormat('dd/MM/yyyy hh:mm a').format(now);
                             final formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate!);
                             final userName = user?.name ?? 'Técnico';
                             
                             final finalMotivo = '${obsController.text.trim()}\n[Reprogramado para: $formattedDate - $selectedJornada]\n[Escrito por: $userName el $formattedNow]';

                             Navigator.pop(dialogCtx); // Close dialog
                             setState(() {
                                _isLoading = true;
                                _loadingMessage = 'Reprogramando...';
                             });
                             try {
                                await _orderRepo.rescheduleOrder(widget.orderNumber, finalMotivo);
                              if (mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden reprogramada'), backgroundColor: Colors.green));
                                 _hasStateChanged = true;
                                 _safePop('refresh');
                              }
                           } catch (e) {
                              if (mounted) _msg('Error al reprogramar: $e', Colors.red);
                           } finally {
                              if (mounted) setState(() => _isLoading = false);
                           }
                         }, 
                         style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10447E), foregroundColor: Colors.white),
                         child: const Text('Reprogramar')
                       ),
                     ],
                   ),
                   const SizedBox(height: 20),
                 ],
              ),
            ),
          ),
        ),
      );
  }

  List<Widget> _buildActionButtons(Orden orden, String status) {
    List<Widget> mainAction = [];

    // 1. ASIGNADA / REPROGRAMADA / REASIGNAR
    if (status == Orden.ESTADO_ASIGNADA || status == Orden.ESTADO_REPROGRAMADA || status == Orden.ESTADO_REASIGNAR) {
      mainAction = [
        const Text(
          '¿Estás listo para iniciar?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
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
      ];
    }
    // 2. EN PROCESO
    else if (status == Orden.ESTADO_EN_PROCESO) {
      mainAction = [
        const Text(
          'Dirígete a la ubicación del cliente',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
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
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showConfirmationDialog(
              title: 'Dejar para más tarde',
              content: '¿Estás seguro de que deseas cancelar el inicio de esta ruta? La orden volverá a estar "Asignada".',
              confirmText: 'Sí, cancelar inicio',
              onConfirm: _cancelStart,
            ),
            icon: const Icon(Icons.history, color: Colors.grey),
            label: const Text('DEJAR PARA MÁS TARDE', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ];
    }
    // 3. EN SITIO
    else if (status == Orden.ESTADO_EN_SITIO) {
      mainAction = [
        const Text(
          'Completa el formulario para finalizar',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ManageOrderScreen(orden: orden)),
              );
              if (result == 'refresh' && mounted) {
                _hasStateChanged = true;
                _safePop('refresh');
              }
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
      ];
    }

    if (mainAction.isEmpty && status != 'reasignar' && status != 'reprogramada') {
      return [const SizedBox.shrink()];
    }

    // Secondary buttons for active orders
    List<Widget> finalActions = [...mainAction];

    // Show secondary actions if it is an active or special status that user still owns
    if ([Orden.ESTADO_ASIGNADA, Orden.ESTADO_EN_PROCESO, Orden.ESTADO_EN_SITIO, Orden.ESTADO_REASIGNAR, Orden.ESTADO_REPROGRAMADA].contains(status)) {
         finalActions.addAll([
             const SizedBox(height: 16),
             Row(
               children: [
                 Expanded(
                   child: OutlinedButton(
                     onPressed: _promptForReassign,
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.redAccent,
                       side: const BorderSide(color: Colors.redAccent),
                       padding: const EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     child: const Text('Reasignar'),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () {
                         if (status == Orden.ESTADO_ASIGNADA || status == Orden.ESTADO_REPROGRAMADA || status == Orden.ESTADO_REASIGNAR) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes INICIAR RUTA para poder reprogramar la orden.'), backgroundColor: Colors.orange));
                             return;
                         }
                         _promptForReschedule();
                     },
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.orange,
                       side: const BorderSide(color: Colors.orange),
                       padding: const EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     child: const Text('Reprogramar'),
                   ),
                 ),
               ],
             )
         ]);
    }

    return finalActions;
  }

  // --- HELPERS ---
  Widget _buildDetailSection(Orden orden) {
    // final dateFormatter = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');
    
    return Column(
      children: [
        _buildInfoContainer('Información General', [
            _buildDetailRow('Cliente', orden.nombreCliente, isTitle: true),
            if (orden.cedula != null) _buildDetailRow('Cédula', orden.cedula, isCopyable: true),
            _buildDetailRow('Dirección', orden.direccion, icon: Icons.map),
            if (orden.barrio != null) _buildDetailRow('Barrio', orden.barrio),
            _buildDetailRow('Celular Principal', orden.telefono ?? 'N/A', icon: Icons.phone, isPhone: orden.telefono != null),
            _buildDetailRow('Teléfono Facturación', orden.telefonoFacturacion?.isNotEmpty == true ? orden.telefonoFacturacion : 'N/A', icon: Icons.receipt, isPhone: orden.telefonoFacturacion?.isNotEmpty == true),
            _buildDetailRow('Otro Teléfono', orden.otroTelefono?.isNotEmpty == true ? orden.otroTelefono : 'N/A', icon: Icons.phone_android, isPhone: orden.otroTelefono?.isNotEmpty == true),
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
         const SizedBox(height: 16),
         _buildAttachedPhotos(),
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

  Widget _buildDetailRow(String label, String? value, {bool isTitle = false, IconData? icon, bool isPhone = false, bool isCopyable = false}) {
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
                if (isPhone || isCopyable)
                  Row(
                    children: [
                      if (isPhone)
                        InkWell(
                          onTap: () => _launchCaller(value),
                          child: Text(value, style: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold)),
                        )
                      else
                        Text(value, style: TextStyle(fontSize: 15, fontWeight: isTitle ? FontWeight.bold : FontWeight.w500, color: Colors.black87)),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado al portapapeles')));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                        ),
                      ),
                    ],
                  )
                else
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: isTitle ? FontWeight.bold : FontWeight.w500, color: Colors.black87)),
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

  Widget _buildAttachedPhotos() {
    if (_photos.isEmpty) return const SizedBox.shrink();
    return _buildInfoContainer('Fotos Adjuntas', [
       SizedBox(
        height: 120, // Increased height for label
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _photos.length,
          itemBuilder: (context, index) {
            final photo = _photos[index];
            return GestureDetector(
              onTap: () async {
                final token = await AuthService.instance.getToken();
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhotoViewScreen(photo: photo, authToken: token),
                  ));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: (photo.path.isNotEmpty && File(photo.path).existsSync())
                          ? Image.file(File(photo.path), fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                          : photo.url != null && photo.url!.isNotEmpty 
                            ? FutureBuilder<String?>(
                                future: AuthService.instance.getToken(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  }
                                  final token = snapshot.data;
                                  return CachedNetworkImage(
                                    imageUrl: photo.url!, 
                                    httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : null,
                                    fit: BoxFit.cover, 
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorWidget: (context, url, error) => const Icon(Icons.broken_image)
                                  );
                                }
                              )
                            : const Icon(Icons.broken_image),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      photo.type ?? 'Foto adjunta',
                      style: const TextStyle(fontSize: 10, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
       )
    ]);
  }
}
