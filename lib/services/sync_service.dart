import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/upload_service.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  static final SyncService instance = SyncService._init();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;
  
  // StreamController para notificar cambios en operaciones pendientes
  final _pendingOperationsController = StreamController<String>.broadcast();
  Stream<String> get pendingOperationsStream => _pendingOperationsController.stream;

  SyncService._init();

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) || 
          result.contains(ConnectivityResult.wifi)) {
        debugPrint("Conexión detectada. Iniciando sincronización...");
        sync();
      }
    });
    sync();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingOperationsController.close();
  }
  
  // Método para notificar cambios manualmente (útil cuando se agregan nuevas operaciones)
  void notifyPendingOperationChange(String orderNumber) {
    if (!_pendingOperationsController.isClosed) {
      _pendingOperationsController.add(orderNumber);
    }
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      await _dbService.setSyncStatus('syncing');
      
      // 1. Subir operaciones pendientes (Upload first to update server)
      await _syncPendingOperations();
      
      // 2. Descargar órdenes actualizadas del servidor
      await _syncOrdersFromServer();
      
      // 3. Subir inspecciones pendientes

      
      // 4. Subir fotos pendientes (ya manejado por UploadService)
      await UploadService.instance.syncPendingUploads();
      
      await _dbService.setSyncStatus('idle');
      debugPrint("Sincronización completada exitosamente");
      // Notificar que se completó la sincronización (vacío significa actualizar todas)
      _pendingOperationsController.add('');
    } catch (e) {
      await _dbService.setSyncStatus('error');
      debugPrint("Error en sincronización: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncOrdersFromServer() async {
    try {
      final response = await _apiService.getOrders(page: 1, status: 'todas');
      final ordersData = response['data'] as List;
      
      // Obtener órdenes con operaciones pendientes para no sobrescribirlas
      final pendingOps = await _dbService.getPendingOperations();
      final pendingOrderNumbers = pendingOps.map((op) => op['order_number'].toString()).toSet();

      final orders = ordersData
          .where((json) => !pendingOrderNumbers.contains(json['numero_orden'].toString()))
          .map((json) => _orderJsonToDbMap(json))
          .toList();
      
      if (orders.isNotEmpty) {
        await _dbService.saveOrders(orders);
      }
      
      await _dbService.setLastSyncOrders(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      debugPrint("Órdenes sincronizadas: ${orders.length} (Ignoradas por pendientes: ${ordersData.length - orders.length})");
    } catch (e) {
      debugPrint("Error al sincronizar órdenes: $e");
    }
  }

  Future<void> _syncPendingOperations() async {
    final pending = await _dbService.getPendingOperations();
    debugPrint("Sincronizando ${pending.length} operaciones pendientes");
    
    for (var operation in pending) {
      final id = operation['id'] as int;
      final type = operation['operation_type'] as String;
      final orderNumber = operation['order_number'] as String;
      final data = jsonDecode(operation['operation_data'] as String);
      
      try {
        switch (type) {
          case 'accept':
            await _apiService.acceptOrder(orderNumber);
            break;
          case 'close':
            await _apiService.closeOrder(orderNumber, data);
            break;
          case 'reject':
            await _apiService.rejectOrder(orderNumber);
            break;
          case 'update_details':
            await _apiService.updateDetails(
              orderNumber,
              Map<String, String>.from(data),
            );
            break;
        }
        
        await _dbService.deletePendingOperation(id);
        debugPrint("Operación $type para orden $orderNumber sincronizada");
        // Notificar que se eliminó una operación pendiente para esta orden
        _pendingOperationsController.add(orderNumber);
      } catch (e) {
        await _dbService.incrementRetryCount(id, e.toString());
        debugPrint("Error al sincronizar operación $id: $e");
      }
    }
  }



  Map<String, dynamic> _orderJsonToDbMap(Map<String, dynamic> json) {
    return {
      'id': json['id'],
      'numero_orden': json['numero_orden'],
      'nombre_cliente': json['nombre_cliente'] ?? 'Cliente Desconocido',
      'fecha_hora': json['created_at'] ?? json['fecha_hora'] ?? DateTime.now().toIso8601String(),
      'valor_servicio': json['valor_servicio']?.toString() ?? json['valor_total']?.toString(),
      'celular': json['celular'] ?? json['telefono'],
      'direccion': json['direccion'], 
      'observaciones': json['observaciones'],
      'fecha_programada': json['fecha_programada'],
      'status': (json['estado_orden'] != null && json['estado_orden'].toString().isNotEmpty) ? json['estado_orden'] : json['status'],
      'fecha_llegada': json['fecha_llegada'],
      'solucion_tecnico': json['solucion_tecnico'],
      'mac_router': json['mac_router'],
      'mac_bridge': json['mac_bridge'],
      'mac_ont': json['mac_ont'],
      'otros_equipos': json['otros_equipos'],
      'firma_tecnico': json['firma_tecnico'],
      'firma_suscriptor': json['firma_suscriptor'],
      'articulos': json['articulos'] != null ? jsonEncode(json['articulos']) : null,
      'technician_id': json['technician_id'],
      'cliente_id': json['cliente_id'],
      'cedula': json['cedula'],
      'precinto': json['precinto'],
      'tipo_orden': json['tipo_orden'],
      'tipo_funcion': json['tipo_funcion'],
      'fecha_trn': json['fecha_trn'],
      'fecha_vencimiento': json['fecha_vencimiento'],
      'estado_orden': json['estado_orden'],
      'tipo': json['tipo'],
      'estado_interno': json['estado_interno'],
      'direccion_asociado': json['direccion_asociado'],
      'telefono': json['telefono'],
      'saldo_cliente': json['saldo_cliente'],
      'solicitado_por': json['solicitado_por'],
      'estado_tv': json['estado_tv'],
      'tecnico_auxiliar_id': json['tecnico_auxiliar_id'],
      'solicitud_suscriptor': json['solicitud_suscriptor'],
      'fecha_inicio_atencion': json['fecha_inicio_atencion'],
      'fecha_fin_atencion': json['fecha_fin_atencion'],
      'fecha_cierre': json['fecha_cierre'],
    };
  }

  Future<SyncStatus> getSyncStatus() async {
    final status = await _dbService.getSyncStatus();
    switch (status) {
      case 'idle':
        return SyncStatus.idle;
      case 'syncing':
        return SyncStatus.syncing;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.idle;
    }
  }

  Future<int> getPendingOperationsCount() async {
    return await _dbService.getPendingOperationsCount();
  }
}

