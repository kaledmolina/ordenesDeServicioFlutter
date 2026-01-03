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
    try {
      final response = await _apiService.getOrders(page: page, status: status);
      print('API Response Data Length: ${(response['data'] as List).length}');
      
      final ordersData = response['data'] as List;
      final orders = ordersData.map((json) => Orden.fromJson(json)).toList();
      
      // Optional: Save to local just for caching view, but no offline logic interaction
      await _saveOrdersToLocal(ordersData);
      
      return orders;
    } catch (e, stack) {
      print('Error fetching orders from API: $e');
      print('Stack trace: $stack');
      rethrow; // Fail directly if API fails
    }
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
    // Validar con una llamada rápida si se desea, o dejar que el backend valide (mejor).
    // Para simpleza y remover offline: llamada directa.
    
    try {
      final order = await _apiService.acceptOrder(orderNumber);
      // Actualizar local para caché visual
      await _saveOrderToLocal(order); 
      return order;
    } catch (e) {
      rethrow;
    }
  }

  Future<Orden> reportOnSite(String orderNumber) async {
    try {
      final order = await _apiService.reportOnSite(orderNumber);
      await _saveOrderToLocal(order);
      return order;
    } catch (e) {
      rethrow;
    }
  }

  Future<Orden> closeOrder(String orderNumber, Map<String, dynamic> closingData) async {
    try {
      final order = await _apiService.closeOrder(orderNumber, closingData);
      await _saveOrderToLocal(order);
      return order;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectOrder(String orderNumber) async {
    try {
      await _apiService.rejectOrder(orderNumber);
      await _dbService.deleteOrder(orderNumber);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderDetails(String orderNumber, Map<String, String> data) async {
    try {
      await _apiService.updateDetails(orderNumber, data);
      await _updateLocalOrder(orderNumber, data);
    } catch (e) {
      rethrow;
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

