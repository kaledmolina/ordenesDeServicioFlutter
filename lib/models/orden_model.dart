import 'package:flutter/foundation.dart';

class Orden {
  final int id;
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
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      numeroOrden: json['numero_orden']?.toString() ?? '',
      nombreCliente: json['nombre_cliente'] ?? 'Cliente Desconocido',
      technicianId: json['technician_id'],
      status: json['status'] ?? 'desconocido',
      fechaHora: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '')?.toLocal(),
      fechaProgramada: DateTime.tryParse(json['fecha_programada'] ?? '')?.toLocal(),
      clienteId: json['cliente_id'],
      direccion: json['direccion'],
      cedula: json['cedula'],
      precinto: json['precinto'],
      tipoOrden: json['tipo_orden'],
      tipoFuncion: json['tipo_funcion'],
      fechaTrn: DateTime.tryParse(json['fecha_trn'] ?? '')?.toLocal(),
      fechaVencimiento: DateTime.tryParse(json['fecha_vencimiento'] ?? '')?.toLocal(),
      estadoOrden: json['estado_orden'],
      tipo: json['tipo'],
      estadoInterno: json['estado_interno'],
      direccionAsociado: json['direccion_asociado'],
      telefono: json['telefono']?.toString(), // Primary phone field
      saldoCliente: json['saldo_cliente']?.toString(),
      solicitadoPor: json['solicitado_por'],
      estadoTv: json['estado_tv'],
      tecnicoAuxiliarId: json['tecnico_auxiliar_id'],
      solicitudSuscriptor: json['solicitud_suscriptor'],
      solucionTecnico: json['solucion_tecnico'],
      valorServicio: double.tryParse(json['valor_total']?.toString() ?? json['valor_servicio']?.toString() ?? '0'),
      observaciones: json['observaciones'],
      articulos: json['articulos'],
      fechaInicioAtencion: DateTime.tryParse(json['fecha_inicio_atencion'] ?? '')?.toLocal(),
      fechaFinAtencion: DateTime.tryParse(json['fecha_fin_atencion'] ?? '')?.toLocal(),
      fechaCierre: DateTime.tryParse(json['fecha_cierre'] ?? '')?.toLocal(),
      fechaLlegada: DateTime.tryParse(json['fecha_llegada'] ?? '')?.toLocal(),
      fechaAsignacion: null, // Placeholder if needed
      macRouter: json['mac_router'],
      macBridge: json['mac_bridge'],
      macOnt: json['mac_ont'],
      otrosEquipos: json['otros_equipos'],
      firmaTecnico: json['firma_tecnico'],
      firmaSuscriptor: json['firma_suscriptor'],
    );
  }
}
