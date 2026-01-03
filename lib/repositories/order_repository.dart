import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/orden_model.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OrderRepository {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<Orden>> getOrders({int page = 1, String status = 'todas'}) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        final response = await _apiService.getOrders(page: page, status: status);
        print('API Response Data Length: ${(response['data'] as List).length}');
        
        final ordersData = response['data'] as List;
        
        // Save to local first (SyncService logic prevents overwriting if valid, but let's be safe here too)
        // Actually, we should merge.
        
        // 1. Get IDs of orders with pending operations
        final pendingOps = await _dbService.getPendingOperations();
        final pendingOrderNumbers = pendingOps.map((op) => op['order_number'].toString()).toSet();
        
        // 2. Transform API data to Orden objects, but favor local version if pending
        List<Orden> orders = [];
        
        for (var json in ordersData) {
          final orderNumber = json['numero_orden'].toString();
          if (pendingOrderNumbers.contains(orderNumber)) {
             // Fetch from local because it has the partial update (e.g. status changed)
             final localOrder = await _getOrderFromLocal(orderNumber);
             if (localOrder != null) {
               orders.add(localOrder);
             } else {
               orders.add(Orden.fromJson(json));
             }
          } else {
             orders.add(Orden.fromJson(json));
          }
        }

        // Also save to local, but SyncService handles the "don't overwrite" logic nicely. 
        // We can just call _saveOrdersToLocal - the SyncService might have already run or will run.
        // But to be consistent with SyncService logic, we should filter before saving if we are essentially "syncing" here.
        // However, this method is "getOrders", not "sync". 
        // We will save what we got, but we rely on SyncService prevention mechanism? 
        // No, we should replicate the safety mechanism here too if we want to write to DB.
        
        final ordersToSave = ordersData
          .where((json) => !pendingOrderNumbers.contains(json['numero_orden'].toString()))
          .toList();
          
        await _saveOrdersToLocal(ordersToSave);
        
        return orders;
      } catch (e, stack) {
        print('Error fetching orders from API: $e');
        print('Stack trace: $stack');
        final localOrders = await _getOrdersFromLocal(status: status);
        if (localOrders.isEmpty) {
           // Si no hay datos locales, lanzamos el error para verlo en la UI
           throw Exception('Error API: $e');
        }
        return localOrders;
      }
    }
    
    return await _getOrdersFromLocal(status: status);
  }

  Future<Orden> getOrderDetails(String orderNumber) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        final order = await _apiService.getOrderDetails(orderNumber);
        await _saveOrderToLocal(order);
        return order;
      } catch (e) {
        final localOrder = await _getOrderFromLocal(orderNumber);
        if (localOrder != null) return localOrder;
        rethrow;
      }
    }
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) return localOrder;
    throw Exception('Orden no encontrada localmente y sin conexión');
  }

  Future<Orden> acceptOrder(String orderNumber) async {
    // Validar si ya hay una orden en proceso (excluyendo la actual)
    final ordersInProcess = await _dbService.getOrdersInProcess();
    
    // Obtener todas las operaciones pendientes
    final allPendingOps = await _dbService.getPendingOperations();
    
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
          return orderNum != orderNumber && !ordersBeingClosed.contains(orderNum);
        })
        .toList();
    
    if (otherOrdersInProcess.isNotEmpty) {
      throw Exception('Ya tienes una orden de servicio en proceso. Debes finalizarla antes de iniciar otra.');
    }
    
    // Validar si hay operaciones pendientes de aceptar para otras órdenes
    // (excluyendo las que están siendo cerradas)
    final otherAcceptOps = allPendingOps
        .where((op) => 
            op['operation_type'] == 'accept' && 
            op['order_number'] != orderNumber &&
            !ordersBeingClosed.contains(op['order_number'] as String))
        .toList();
    
    if (otherAcceptOps.isNotEmpty) {
      throw Exception('Ya tienes una orden de servicio en proceso. Debes finalizarla antes de iniciar otra.');
    }
    
    final hasConnection = await _hasConnection();
    
    // Verificar si ya existe una operación pendiente de aceptar para esta orden
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasAcceptPending = existingOps.any((op) => op['operation_type'] == 'accept');
    
    if (hasAcceptPending) {
      // Si ya hay una operación pendiente, retornar orden con estado actualizado localmente
      final localOrder = await _getOrderFromLocal(orderNumber);
      if (localOrder != null) {
        return Orden(
          id: localOrder.id,
          numeroOrden: localOrder.numeroOrden,
          nombreCliente: localOrder.nombreCliente,
          fechaHora: localOrder.fechaHora,
          valorServicio: localOrder.valorServicio,

          direccion: localOrder.direccion,
          observaciones: localOrder.observaciones,
          fechaProgramada: localOrder.fechaProgramada,
          status: Orden.ESTADO_EN_PROCESO,
          fechaLlegada: localOrder.fechaLlegada,
          solucionTecnico: localOrder.solucionTecnico,
          macRouter: localOrder.macRouter,
          macBridge: localOrder.macBridge,
          macOnt: localOrder.macOnt,
          otrosEquipos: localOrder.otrosEquipos,
          firmaTecnico: localOrder.firmaTecnico,
          firmaSuscriptor: localOrder.firmaSuscriptor,
          articulos: localOrder.articulos,
          technicianId: localOrder.technicianId,
          clienteId: localOrder.clienteId,
          cedula: localOrder.cedula,
          precinto: localOrder.precinto,
          tipoOrden: localOrder.tipoOrden,
          tipoFuncion: localOrder.tipoFuncion,
          fechaTrn: localOrder.fechaTrn,
          fechaVencimiento: localOrder.fechaVencimiento,
          estadoOrden: localOrder.estadoOrden,
          tipo: localOrder.tipo,
          estadoInterno: localOrder.estadoInterno,
          direccionAsociado: localOrder.direccionAsociado,
          telefono: localOrder.telefono,
          saldoCliente: localOrder.saldoCliente,
          solicitadoPor: localOrder.solicitadoPor,
          estadoTv: localOrder.estadoTv,
          tecnicoAuxiliarId: localOrder.tecnicoAuxiliarId,
          solicitudSuscriptor: localOrder.solicitudSuscriptor,
          fechaInicioAtencion: DateTime.now(),
          fechaFinAtencion: localOrder.fechaFinAtencion,
          fechaCierre: localOrder.fechaCierre,
        );
      }
    }
    
    if (hasConnection) {
      try {
        final order = await _apiService.acceptOrder(orderNumber);
        await _saveOrderToLocal(order);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('accept', orderNumber),
        );
        return order;
      } catch (e) {
        // Actualizar estado local inmediatamente
        await _updateLocalOrderStatus(orderNumber, Orden.ESTADO_EN_PROCESO);
        await _queueOperation('accept', orderNumber, {});
        rethrow;
      }
    }
    
    // Actualizar estado local inmediatamente antes de encolar
    await _updateLocalOrderStatus(orderNumber, Orden.ESTADO_EN_PROCESO);
    await _queueOperation('accept', orderNumber, {});
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) {
      return localOrder;
    }
    throw Exception('Orden no encontrada');
  }

  Future<Orden> reportOnSite(String orderNumber) async {
    final hasConnection = await _hasConnection();
    
    // Verificar si ya existe una operación pendiente de reporte en sitio
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasReportPending = existingOps.any((op) => op['operation_type'] == 'report_on_site');
    
    if (hasReportPending) {
      final localOrder = await _getOrderFromLocal(orderNumber);
      if (localOrder != null) {
        return Orden(
          id: localOrder.id,
          numeroOrden: localOrder.numeroOrden,
          nombreCliente: localOrder.nombreCliente,
          fechaHora: localOrder.fechaHora,
          valorServicio: localOrder.valorServicio,
          direccion: localOrder.direccion,
          observaciones: localOrder.observaciones,
          fechaProgramada: localOrder.fechaProgramada,
          status: Orden.ESTADO_EN_SITIO, // Optimistic Update
          fechaLlegada: DateTime.now(),   // Set arrival time optimistically
          solucionTecnico: localOrder.solucionTecnico,
          macRouter: localOrder.macRouter,
          macBridge: localOrder.macBridge,
          macOnt: localOrder.macOnt,
          otrosEquipos: localOrder.otrosEquipos,
          firmaTecnico: localOrder.firmaTecnico,
          firmaSuscriptor: localOrder.firmaSuscriptor,
          articulos: localOrder.articulos,
          technicianId: localOrder.technicianId,
          clienteId: localOrder.clienteId,
          cedula: localOrder.cedula,
          precinto: localOrder.precinto,
          tipoOrden: localOrder.tipoOrden,
          tipoFuncion: localOrder.tipoFuncion,
          fechaTrn: localOrder.fechaTrn,
          fechaVencimiento: localOrder.fechaVencimiento,
          estadoOrden: localOrder.estadoOrden,
          tipo: localOrder.tipo,
          estadoInterno: localOrder.estadoInterno,
          direccionAsociado: localOrder.direccionAsociado,
          telefono: localOrder.telefono,
          saldoCliente: localOrder.saldoCliente,
          solicitadoPor: localOrder.solicitadoPor,
          estadoTv: localOrder.estadoTv,
          tecnicoAuxiliarId: localOrder.tecnicoAuxiliarId,
          solicitudSuscriptor: localOrder.solicitudSuscriptor,
          fechaInicioAtencion: localOrder.fechaInicioAtencion,
          fechaFinAtencion: localOrder.fechaFinAtencion,
          fechaCierre: localOrder.fechaCierre,
        );
      }
    }
    
    if (hasConnection) {
      try {
        final order = await _apiService.reportOnSite(orderNumber);
        await _saveOrderToLocal(order);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('report_on_site', orderNumber),
        );
        return order;
      } catch (e) {
        // Fallback to offline
        await _updateLocalOrderStatus(orderNumber, Orden.ESTADO_EN_SITIO);
        // Also update arrival time locally
        await _updateLocalOrder(orderNumber, {'fecha_llegada': DateTime.now().toIso8601String()});
        await _queueOperation('report_on_site', orderNumber, {});
        rethrow;
      }
    }

    // Offline mode
    await _updateLocalOrderStatus(orderNumber, Orden.ESTADO_EN_SITIO);
    await _updateLocalOrder(orderNumber, {'fecha_llegada': DateTime.now().toIso8601String()});
    await _queueOperation('report_on_site', orderNumber, {});
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) return localOrder;
    throw Exception('Orden no encontrada');
  }

  Future<Orden> closeOrder(String orderNumber, Map<String, dynamic> closingData) async {
    final hasConnection = await _hasConnection();
    
    // Verificar si ya existe una operación pendiente de cerrar
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasClosePending = existingOps.any((op) => op['operation_type'] == 'close');
    
    if (hasClosePending) {
      // Si ya hay una operación pendiente, retornar orden con estado actualizado localmente
      final localOrder = await _getOrderFromLocal(orderNumber);
      if (localOrder != null) {
        // Apply optimistic updates from closingData if needed, 
        // usually just returning the current local state which should be executed is enough
        // but let's be safe and ensure the status is returned as executed
        return Orden(
          id: localOrder.id,
          numeroOrden: localOrder.numeroOrden,
          nombreCliente: localOrder.nombreCliente,
          fechaHora: localOrder.fechaHora,
          valorServicio: localOrder.valorServicio,
          direccion: localOrder.direccion,
          observaciones: localOrder.observaciones,
          fechaProgramada: localOrder.fechaProgramada,
          status: Orden.ESTADO_EJECUTADA,
          fechaLlegada: localOrder.fechaLlegada,
          solucionTecnico: localOrder.solucionTecnico,
          macRouter: closingData['mac_router'] ?? localOrder.macRouter,
          macBridge: closingData['mac_bridge'] ?? localOrder.macBridge,
          macOnt: closingData['mac_ont'] ?? localOrder.macOnt,
          otrosEquipos: closingData['otros_equipos'] ?? localOrder.otrosEquipos,
          firmaTecnico: closingData['firma_tecnico'] ?? localOrder.firmaTecnico,
          firmaSuscriptor: closingData['firma_suscriptor'] ?? localOrder.firmaSuscriptor,
          articulos: closingData['articulos'] ?? localOrder.articulos,
          technicianId: localOrder.technicianId,
          clienteId: localOrder.clienteId,
          cedula: localOrder.cedula,
          precinto: localOrder.precinto,
          tipoOrden: localOrder.tipoOrden,
          tipoFuncion: localOrder.tipoFuncion,
          fechaTrn: localOrder.fechaTrn,
          fechaVencimiento: localOrder.fechaVencimiento,
          estadoOrden: localOrder.estadoOrden,
          tipo: localOrder.tipo,
          estadoInterno: localOrder.estadoInterno,
          direccionAsociado: localOrder.direccionAsociado,
          telefono: localOrder.telefono,
          saldoCliente: localOrder.saldoCliente,
          solicitadoPor: localOrder.solicitadoPor,
          estadoTv: localOrder.estadoTv,
          tecnicoAuxiliarId: localOrder.tecnicoAuxiliarId,
          solicitudSuscriptor: localOrder.solicitudSuscriptor,
          fechaInicioAtencion: localOrder.fechaInicioAtencion,
          fechaFinAtencion: DateTime.now(),
          fechaCierre: DateTime.now(),
        );
      }
    }
    
    if (hasConnection) {
      try {
        final order = await _apiService.closeOrder(orderNumber, closingData);
        await _saveOrderToLocal(order);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('close', orderNumber),
        );
        return order;
      } catch (e) {
        // Actualizar estado local inmediatamente
        await _updateLocalOrderStatus(orderNumber, Orden.ESTADO_EJECUTADA);
        // Also update local order with closing data
        // Convert map values to String for updateLocalOrder if feasible or handle complex types
        // For simplicity, we queue the full JSON operation, and maybe update simple fields locally
        await _queueOperation('close', orderNumber, closingData);
        rethrow;
      }
    }
    
    // Actualizar estado local inmediatamente antes de encolar
    await _updateLocalOrderStatus(orderNumber, Orden.ESTADO_EJECUTADA);
     // Convert dynamic map to Map<String, String> for simple update, skipping complex fields for now 
    // or improve _updateLocalOrder to handle dynamic.
    // Ideally we should update the local DB with all closing data so the UI reflects it.
    // For now we rely on the status update and the queue.
    await _queueOperation('close', orderNumber, closingData);
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) {
      // Manually construct returned object with new data for immediate UI feedback
       return Orden(
          id: localOrder.id,
          numeroOrden: localOrder.numeroOrden,
          nombreCliente: localOrder.nombreCliente,
          fechaHora: localOrder.fechaHora,
          valorServicio: localOrder.valorServicio,
          direccion: localOrder.direccion,
          observaciones: localOrder.observaciones,
          fechaProgramada: localOrder.fechaProgramada,
          status: Orden.ESTADO_EJECUTADA,
          fechaLlegada: localOrder.fechaLlegada,
          solucionTecnico: localOrder.solucionTecnico,
          macRouter: closingData['mac_router'] ?? localOrder.macRouter,
          macBridge: closingData['mac_bridge'] ?? localOrder.macBridge,
          macOnt: closingData['mac_ont'] ?? localOrder.macOnt,
          otrosEquipos: closingData['otros_equipos'] ?? localOrder.otrosEquipos,
          firmaTecnico: closingData['firma_tecnico'] ?? localOrder.firmaTecnico,
          firmaSuscriptor: closingData['firma_suscriptor'] ?? localOrder.firmaSuscriptor,
          articulos: closingData['articulos'] ?? localOrder.articulos,
          technicianId: localOrder.technicianId,
          clienteId: localOrder.clienteId,
          cedula: localOrder.cedula,
          precinto: localOrder.precinto,
          tipoOrden: localOrder.tipoOrden,
          tipoFuncion: localOrder.tipoFuncion,
          fechaTrn: localOrder.fechaTrn,
          fechaVencimiento: localOrder.fechaVencimiento,
          estadoOrden: localOrder.estadoOrden,
          tipo: localOrder.tipo,
          estadoInterno: localOrder.estadoInterno,
          direccionAsociado: localOrder.direccionAsociado,
          telefono: localOrder.telefono,
          saldoCliente: localOrder.saldoCliente,
          solicitadoPor: localOrder.solicitadoPor,
          estadoTv: localOrder.estadoTv,
          tecnicoAuxiliarId: localOrder.tecnicoAuxiliarId,
          solicitudSuscriptor: localOrder.solicitudSuscriptor,
          fechaInicioAtencion: localOrder.fechaInicioAtencion,
          fechaFinAtencion: DateTime.now(), // Optimistic
          fechaCierre: DateTime.now(), // Optimistic
        );
    }
    throw Exception('Orden no encontrada');
  }

  Future<void> rejectOrder(String orderNumber) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        await _apiService.rejectOrder(orderNumber);
        await _dbService.deleteOrder(orderNumber);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('reject', orderNumber),
        );
      } catch (e) {
        await _queueOperation('reject', orderNumber, {});
        rethrow;
      }
    } else {
      await _queueOperation('reject', orderNumber, {});
    }
  }

  Future<void> updateOrderDetails(String orderNumber, Map<String, String> data) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        await _apiService.updateDetails(orderNumber, data);
        await _updateLocalOrder(orderNumber, data);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('update_details', orderNumber),
        );
      } catch (e) {
        await _queueOperation('update_details', orderNumber, data);
        rethrow;
      }
    } else {
      await _queueOperation('update_details', orderNumber, data);
      await _updateLocalOrder(orderNumber, data);
    }
  }

  Future<bool> _hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<void> _saveOrdersToLocal(List<dynamic> ordersData) async {
    final orders = ordersData.map((json) => _orderJsonToDbMap(json)).toList();
    await _dbService.saveOrders(orders);
    await _dbService.setLastSyncOrders(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  Future<void> _saveOrderToLocal(Orden order) async {
    final orderMap = _ordenToDbMap(order);
    await _dbService.saveOrder(orderMap);
  }

  Future<List<Orden>> _getOrdersFromLocal({String? status}) async {
    final ordersData = await _dbService.getOrders(status: status);
    return ordersData.map((map) => _dbMapToOrden(map)).toList();
  }

  Future<Orden?> _getOrderFromLocal(String orderNumber) async {
    final orderData = await _dbService.getOrderByNumber(orderNumber);
    if (orderData == null) return null;
    return _dbMapToOrden(orderData);
  }

  Future<void> _updateLocalOrder(String orderNumber, Map<String, String> data) async {
    final updates = <String, dynamic>{};
    if (data.containsKey('celular')) updates['celular'] = data['celular'];
    if (data.containsKey('observaciones')) {
      updates['observaciones'] = data['observaciones'];
    }
    await _dbService.updateOrder(orderNumber, updates);
  }

  Future<void> _updateLocalOrderStatus(String orderNumber, String newStatus) async {
    await _dbService.updateOrder(orderNumber, {'status': newStatus});
  }

  Future<void> _queueOperation(String type, String orderNumber, Map<String, dynamic> data) async {
    // Verificar si ya existe una operación del mismo tipo para esta orden
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasDuplicate = existingOps.any((op) => op['operation_type'] == type);
    
    if (!hasDuplicate) {
      await _dbService.addPendingOperation(
        operationType: type,
        orderNumber: orderNumber,
        operationData: data,
      );
      // Notificar que se agregó una nueva operación pendiente
      SyncService.instance.notifyPendingOperationChange(orderNumber);
    }
  }

  Future<int> _findPendingOperation(String type, String orderNumber) async {
    final pending = await _dbService.getPendingOperationsForOrder(orderNumber);
    final operation = pending.firstWhere(
      (op) => op['operation_type'] == type,
      orElse: () => {'id': 0},
    );
    return operation['id'] as int;
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

  Map<String, dynamic> _ordenToDbMap(Orden order) {
    return {
      'id': order.id,
      'numero_orden': order.numeroOrden,
      'nombre_cliente': order.nombreCliente,
      'fecha_hora': order.fechaHora.toIso8601String(),
      'valor_servicio': order.valorServicio?.toString(),
      'celular': order.celular,
      'direccion': order.direccion,
      'observaciones': order.observaciones,
      'fecha_programada': order.fechaProgramada?.toIso8601String(),
      'status': order.status,
      'fecha_llegada': order.fechaLlegada?.toIso8601String(),
      'solucion_tecnico': order.solucionTecnico,
      'mac_router': order.macRouter,
      'mac_bridge': order.macBridge,
      'mac_ont': order.macOnt,
      'otros_equipos': order.otrosEquipos,
      'firma_tecnico': order.firmaTecnico,
      'firma_suscriptor': order.firmaSuscriptor,
      'articulos': order.articulos != null ? jsonEncode(order.articulos) : null,
      'technician_id': order.technicianId,
      'cliente_id': order.clienteId,
      'cedula': order.cedula,
      'precinto': order.precinto,
      'tipo_orden': order.tipoOrden,
      'tipo_funcion': order.tipoFuncion,
      'fecha_trn': order.fechaTrn?.toIso8601String(),
      'fecha_vencimiento': order.fechaVencimiento?.toIso8601String(),
      'estado_orden': order.estadoOrden,
      'tipo': order.tipo,
      'estado_interno': order.estadoInterno,
      'direccion_asociado': order.direccionAsociado,
      'telefono': order.telefono,
      'saldo_cliente': order.saldoCliente,
      'solicitado_por': order.solicitadoPor,
      'estado_tv': order.estadoTv,
      'tecnico_auxiliar_id': order.tecnicoAuxiliarId,
      'solicitud_suscriptor': order.solicitudSuscriptor,
      'fecha_inicio_atencion': order.fechaInicioAtencion?.toIso8601String(),
      'fecha_fin_atencion': order.fechaFinAtencion?.toIso8601String(),
      'fecha_cierre': order.fechaCierre?.toIso8601String(),
    };
  }

  Orden _dbMapToOrden(Map<String, dynamic> map) {
    return Orden(
      id: map['id'] as int,
      numeroOrden: map['numero_orden']?.toString() ?? '',
      nombreCliente: map['nombre_cliente']?.toString() ?? '',
      fechaHora: DateTime.tryParse(map['fecha_hora']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      valorServicio: map['valor_servicio'] != null
          ? double.tryParse(map['valor_servicio'].toString())
          : null,
      direccion: map['direccion']?.toString(),
      observaciones: map['observaciones']?.toString(),
      fechaProgramada: map['fecha_programada'] != null
          ? DateTime.tryParse(map['fecha_programada'].toString())?.toLocal()
          : null,
      status: map['status']?.toString() ?? 'desconocido',
      fechaLlegada: map['fecha_llegada'] != null ? DateTime.tryParse(map['fecha_llegada'].toString())?.toLocal() : null,
      solucionTecnico: map['solucion_tecnico']?.toString(),
      macRouter: map['mac_router']?.toString(),
      macBridge: map['mac_bridge']?.toString(),
      macOnt: map['mac_ont']?.toString(),
      otrosEquipos: map['otros_equipos']?.toString(),
      firmaTecnico: map['firma_tecnico']?.toString(),
      firmaSuscriptor: map['firma_suscriptor']?.toString(),
      articulos: map['articulos'] != null ? jsonDecode(map['articulos'].toString()) as List<dynamic> : null,
      technicianId: map['technician_id'] != null ? int.tryParse(map['technician_id'].toString()) : null,
      clienteId: map['cliente_id'] != null ? int.tryParse(map['cliente_id'].toString()) : null,
      cedula: map['cedula']?.toString(),
      precinto: map['precinto']?.toString(),
      tipoOrden: map['tipo_orden']?.toString(),
      tipoFuncion: map['tipo_funcion']?.toString(),
      fechaTrn: map['fecha_trn'] != null ? DateTime.tryParse(map['fecha_trn'].toString())?.toLocal() : null,
      fechaVencimiento: map['fecha_vencimiento'] != null ? DateTime.tryParse(map['fecha_vencimiento'].toString())?.toLocal() : null,
      estadoOrden: map['estado_orden']?.toString(),
      tipo: map['tipo']?.toString(),
      estadoInterno: map['estado_interno']?.toString(),
      direccionAsociado: map['direccion_asociado']?.toString(),
      telefono: map['telefono']?.toString(),
      saldoCliente: map['saldo_cliente']?.toString(),
      solicitadoPor: map['solicitado_por']?.toString(),
      estadoTv: map['estado_tv']?.toString(),
      tecnicoAuxiliarId: map['tecnico_auxiliar_id'] != null ? int.tryParse(map['tecnico_auxiliar_id'].toString()) : null,
      solicitudSuscriptor: map['solicitud_suscriptor']?.toString(),
      fechaInicioAtencion: map['fecha_inicio_atencion'] != null ? DateTime.tryParse(map['fecha_inicio_atencion'].toString())?.toLocal() : null,
      fechaFinAtencion: map['fecha_fin_atencion'] != null ? DateTime.tryParse(map['fecha_fin_atencion'].toString())?.toLocal() : null,
      fechaCierre: map['fecha_cierre'] != null ? DateTime.tryParse(map['fecha_cierre'].toString())?.toLocal() : null,
    );
  }

}

