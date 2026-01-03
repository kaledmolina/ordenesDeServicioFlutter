import 'package:flutter/foundation.dart';

class Orden {
  final int id;
  
  // Status Constants
  static const String ESTADO_PENDIENTE = 'pendiente';
  static const String ESTADO_ASIGNADA = 'asignada';
  static const String ESTADO_EN_SITIO = 'en_sitio';
  static const String ESTADO_EN_PROCESO = 'en_proceso';
  static const String ESTADO_EJECUTADA = 'ejecutada';
  static const String ESTADO_CERRADA = 'cerrada';
  static const String ESTADO_ANULADA = 'anulada';
  
  final String numeroOrden;
  final String nombreCliente;
  final int? technicianId;
  final String status;
  final DateTime fechaHora; // created_at
  final DateTime? updatedAt;
  final DateTime? fechaProgramada;
  final int? clienteId;
  final String? direccion;
  final String? cedula;
  final String? precinto;
  final String? tipoOrden;
  final String? tipoFuncion;
  final DateTime? fechaTrn;
  final DateTime? fechaVencimiento;
  final String? estadoOrden;
  final String? tipo;
  final String? estadoInterno;
  final String? direccionAsociado;
  final String? telefono;
  final String? saldoCliente;
  final String? solicitadoPor;
  final String? estadoTv;
  final int? tecnicoAuxiliarId;
  final String? solicitudSuscriptor;
  final String? solucionTecnico;
  final double? valorServicio; // valor_total in JSON? No, kept as is or mapped from null. JSON has valor_total: null
  final String? observaciones;
  final List<dynamic>? articulos;
  
  // Fields for local use / extra JSON fields
  final DateTime? fechaInicioAtencion;
  final DateTime? fechaFinAtencion;
  final DateTime? fechaCierre;
  final DateTime? fechaLlegada;
  final DateTime? fechaAsignacion; // Changed from Timestamp to DateTime
  final String? macRouter;
  final String? macBridge;
  final String? macOnt;
  final String? otrosEquipos;
  final String? firmaTecnico;
  final String? firmaSuscriptor;

  // Celular alias for UI compatibility (maps to telefono)
  String? get celular => telefono;

  Orden({
    required this.id,
    required this.numeroOrden,
    required this.nombreCliente,
    this.technicianId,
    required this.status,
    required this.fechaHora,
    this.updatedAt,
    this.fechaProgramada,
    this.clienteId,
    this.direccion,
    this.cedula,
    this.precinto,
    this.tipoOrden,
    this.tipoFuncion,
    this.fechaTrn,
    this.fechaVencimiento,
    this.estadoOrden,
    this.tipo,
    this.estadoInterno,
    this.direccionAsociado,
    this.telefono,
    this.saldoCliente,
    this.solicitadoPor,
    this.estadoTv,
    this.tecnicoAuxiliarId,
    this.solicitudSuscriptor,
    this.solucionTecnico,
    this.valorServicio,
    this.observaciones,
    this.articulos,
    this.fechaInicioAtencion,
    this.fechaFinAtencion,
    this.fechaCierre,
    this.fechaLlegada,
    this.fechaAsignacion,
    this.macRouter,
    this.macBridge,
    this.macOnt,
    this.otrosEquipos,
    this.firmaTecnico,
    this.firmaSuscriptor,
  });

  factory Orden.fromJson(Map<String, dynamic> json) {
    return Orden(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      numeroOrden: json['numero_orden']?.toString() ?? '',
      nombreCliente: json['nombre_cliente']?.toString() ?? 'Cliente Desconocido',
      technicianId: int.tryParse(json['technician_id']?.toString() ?? ''),
      status: (json['estado_orden'] != null && json['estado_orden'].toString().isNotEmpty) 
          ? json['estado_orden'].toString() 
          : (json['status']?.toString() ?? 'desconocido'),
      fechaHora: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '')?.toLocal(),
      fechaProgramada: DateTime.tryParse(json['fecha_programada'] ?? '')?.toLocal(),
      clienteId: int.tryParse(json['cliente_id']?.toString() ?? ''),
      direccion: json['direccion']?.toString(),
      cedula: json['cedula']?.toString(),
      precinto: json['precinto']?.toString(),
      tipoOrden: json['tipo_orden']?.toString(),
      tipoFuncion: json['tipo_funcion']?.toString(),
      fechaTrn: DateTime.tryParse(json['fecha_trn'] ?? '')?.toLocal(),
      fechaVencimiento: DateTime.tryParse(json['fecha_vencimiento'] ?? '')?.toLocal(),
      estadoOrden: json['estado_orden']?.toString(),
      tipo: json['tipo']?.toString(),
      estadoInterno: json['estado_interno']?.toString(),
      direccionAsociado: json['direccion_asociado']?.toString(),
      telefono: json['telefono']?.toString(), 
      saldoCliente: json['saldo_cliente']?.toString(),
      solicitadoPor: json['solicitado_por']?.toString(),
      estadoTv: json['estado_tv']?.toString(),
      tecnicoAuxiliarId: int.tryParse(json['tecnico_auxiliar_id']?.toString() ?? ''),
      solicitudSuscriptor: json['solicitud_suscriptor']?.toString(),
      solucionTecnico: json['solucion_tecnico']?.toString(),
      valorServicio: double.tryParse(json['valor_total']?.toString() ?? json['valor_servicio']?.toString() ?? '0'),
      observaciones: json['observaciones']?.toString(),
      articulos: json['articulos'],
      fechaInicioAtencion: DateTime.tryParse(json['fecha_inicio_atencion'] ?? '')?.toLocal(),
      fechaFinAtencion: DateTime.tryParse(json['fecha_fin_atencion'] ?? '')?.toLocal(),
      fechaCierre: DateTime.tryParse(json['fecha_cierre'] ?? '')?.toLocal(),
      fechaLlegada: DateTime.tryParse(json['fecha_llegada'] ?? '')?.toLocal(),
      fechaAsignacion: null,
      macRouter: json['mac_router']?.toString(),
      macBridge: json['mac_bridge']?.toString(),
      macOnt: json['mac_ont']?.toString(),
      otrosEquipos: json['otros_equipos']?.toString(),
      firmaTecnico: json['firma_tecnico']?.toString(),
      firmaSuscriptor: json['firma_suscriptor']?.toString(),
    );    );
  }
}
