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
  static const String ESTADO_REASIGNAR = 'reasignar';
  static const String ESTADO_REPROGRAMADA = 'reprogramada';
  
  final String numeroOrden;
  final String nombreCliente;
  final int? technicianId;
  // final String status; // Removed, using estadoOrden
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
  final String? barrio;
  final String? planInternet;
  final String? clasificacion;
  final String? codigoContrato;
  final String? novedadesNoc;
  final String? otroTelefono;
  final String? telefonoFacturacion;
  final DateTime? deadlineAt;

  // Celular alias for UI compatibility (maps to telefono)
  String? get celular => telefono;

  // Label Getters
  String get tipoOrdenLabel => tipoOrdenOptions[tipoOrden] ?? tipoOrden ?? 'Desconocido';
  String get solicitudSuscriptorLabel => solicitudSuscriptorOptions[solicitudSuscriptor] ?? solicitudSuscriptor ?? 'Sin Reporte';

  // Status alias for UI compatibility (maps to estadoOrden)
  String get status => estadoOrden?.toLowerCase() ?? 'pendiente';

  Orden({
    required this.id,
    required this.numeroOrden,
    required this.nombreCliente,
    this.technicianId,
    // required this.status, REMOVED
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
    this.barrio,
    this.planInternet,
    this.clasificacion,
    this.codigoContrato,
    this.novedadesNoc,
    this.otroTelefono,
    this.telefonoFacturacion,
    this.deadlineAt,
  });

  // Option Maps (Mirrors PHP Constants)
  static const Map<String, String> tipoOrdenOptions = {
    '025': '025 REVISION TECNICA',
    '037': '037 CAMBIO CONTRASEÑA',
    '038': '038 TRASLADO INTERNO',
    '004': '004 SUSPENSION',
    '005': '005 RECONEXION',
    '010': '010 TRASLADO',
    '018': '018 CAMBIO DE EQUIPO',
    '001': '001 INSTALACION',
    '002': '002 RETIRO',
  };

  static const Map<String, String> solicitudSuscriptorOptions = {
    'LUZ ROJA': 'LUZ ROJA',
    'MEJORAMIENTO DE POTENCIA': 'MEJORAMIENTO DE POTENCIA',
    'SIN SERVICIO DE INTERNET': 'SIN SERVICIO DE INTERNET',
    'SERVICIO LENTO E INTERMITENTE': 'SERVICIO LENTO E INTERMITENTE',
    'GARANTIA INTERNET': 'GARANTIA INTERNET',
    'GARANTIA TV E INTERNET': 'GARANTIA TV E INTERNET',
    'GARANTIA TV': 'GARANTIA TV',
    'SIN SERVICIO DE TV': 'SIN SERVICIO DE TV',
    'MANTENIMIENTO CORRECTIVO': 'MANTENIMIENTO CORRECTIVO',
    'CAMBIO DE EQUIPO': 'CAMBIO DE EQUIPO',
    'CAMBIO DE CUENTA EN WIM': 'CAMBIO DE CUENTA EN WIM',
    'INSTALACION AUTOMONITOREO': 'INSTALACION AUTOMONITOREO',
    'REVISION AUTOMONITOREO': 'REVISION AUTOMONITOREO',
    'REUBICACION DE EQUIPO': 'REUBICACION DE EQUIPO',
    'OTRO': 'OTRO',
  };

  static const Map<String, String> solucionTecnicoOptions = {
    '1 CAMBIO - CONECTOR MECÁNICO PARTIDO': '1 CAMBIO - CONECTOR MECÁNICO PARTIDO',
    '2 CAIDA GENERAL - PROVEEDOR': '2 CAIDA GENERAL - PROVEEDOR',
    '3 CAIDA GENERAL - CABECERA': '3 CAIDA GENERAL - CABECERA',
    '4 CONFIGURACIÓN DE EQUIPO': '4 CONFIGURACIÓN DE EQUIPO',
    '5 FIBRA PARTIDA - SE INSTALA ROSETA': '5 FIBRA PARTIDA - SE INSTALA ROSETA',
    '6 FIBRA PARTIDA - CAMBIO FIBRA': '6 FIBRA PARTIDA - CAMBIO FIBRA',
    '7 CAMBIO -EQUIPO DEFECTUOSO': '7 CAMBIO -EQUIPO DEFECTUOSO',
    '8 CAMBIO -EQUIPO QUEMADO': '8 CAMBIO -EQUIPO QUEMADO',
    '9 CAMBIO- EQUIPO MAL USO USUARIO': '9 CAMBIO- EQUIPO MAL USO USUARIO',
    '10 REFRESH DE MEGAS': '10 REFRESH DE MEGAS',
    '11 CAMBIO CONECTOR DE CAJA': '11 CAMBIO CONECTOR DE CAJA',
    '12 ENFRENTADOR DE CAJA': '12 ENFRENTADOR DE CAJA',
    '13 FIBRA ATENUADA': '13 FIBRA ATENUADA',
    '14 RETENCION DE FIBRA': '14 RETENCION DE FIBRA',
    '15 USUARIO SUSPENDIDO': '15 USUARIO SUSPENDIDO',
    '16 CAMBIO CONECTOR RF': '16 CAMBIO CONECTOR RF',
    '17 ESCANEO DE CANALES': '17 ESCANEO DE CANALES',
    '18 CAMBIO NOMBRE WINBOX': '18 CAMBIO NOMBRE WINBOX',
    '19 MEJORA DE POTENCIA': '19 MEJORA DE POTENCIA',
    '20 DAÑO MASIVO': '20 DAÑO MASIVO',
    '21 CONFIGURACIÓN DE TV': '21 CONFIGURACIÓN DE TV',
    '22 FIBRA PARTIDA- USO DE RESERVA': '22 FIBRA PARTIDA- USO DE RESERVA',
    '23 SERVICIO OPERATIVO': '23 SERVICIO OPERATIVO',
    '24 CAMBIO DE BRIDGE': '24 CAMBIO DE BRIDGE',
    '25 CAMBIO DE CAMARA': '25 CAMBIO DE CAMARA',
    '26 REUBICACION DE FIBRA': '26 REUBICACION DE FIBRA',
    '49 TRASLADO INTERNO': '49 TRASLADO INTERNO',
    '50 CAMBIO DE CONTRASEÑA': '50 CAMBIO DE CONTRASEÑA',
    '51 CAJA SIN POTENCIA': '51 CAJA SIN POTENCIA',
  };

  // Improved parsing for array or string
  static String? _parseSolucionTecnico(dynamic val) {
    if (val == null) return null;
    if (val is List) return val.join(', '); // Join array into a single string for display/legacy compat
    return val.toString();
  }

  factory Orden.fromJson(Map<String, dynamic> json) {
    return Orden(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      numeroOrden: json['numero_orden']?.toString() ?? '',
      nombreCliente: json['nombre_cliente']?.toString() ?? 'Cliente Desconocido',
      technicianId: int.tryParse(json['technician_id']?.toString() ?? ''),
      // status field removed. status getter uses estadoOrden
      fechaHora: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '')?.toLocal(),
      fechaProgramada: DateTime.tryParse(json['fecha_programada'] ?? '')?.toLocal(),
      clienteId: int.tryParse(json['cliente_id']?.toString() ?? ''),
      direccion: json['direccion']?.toString(),
      cedula: json['cedula']?.toString() ?? json['cliente']?['cedula']?.toString() ?? json['cliente']?['nit']?.toString(),
      precinto: json['precinto']?.toString(),
      tipoOrden: json['tipo_orden']?.toString(),
      tipoFuncion: json['tipo_funcion']?.toString(),
      fechaTrn: DateTime.tryParse(json['fecha_trn'] ?? '')?.toLocal(),
      fechaVencimiento: DateTime.tryParse(json['fecha_vencimiento'] ?? '')?.toLocal(),
      estadoOrden: json['estado_orden']?.toString() ?? json['status']?.toString() ?? 'pendiente', // Fallback for old API responses if any
      tipo: json['tipo']?.toString(),
      estadoInterno: json['estado_interno']?.toString(),
      direccionAsociado: json['direccion_asociado']?.toString(),
      telefono: json['telefono']?.toString() ?? json['cliente']?['celular']?.toString() ?? json['cliente']?['telefono']?.toString(), 
      saldoCliente: json['cliente']?['saldo_total']?.toString() ?? json['saldo_cliente']?.toString(),
      solicitadoPor: json['solicitado_por']?.toString(),
      estadoTv: json['estado_tv']?.toString(),
      tecnicoAuxiliarId: int.tryParse(json['tecnico_auxiliar_id']?.toString() ?? ''),
      solicitudSuscriptor: json['solicitud_suscriptor']?.toString(),
      solucionTecnico: _parseSolucionTecnico(json['solucion_tecnico']),
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
      barrio: json['cliente']?['barrio']?.toString(), 
      planInternet: json['plan_internet']?.toString() ?? json['cliente']?['plan_internet']?.toString(),
      clasificacion: json['clasificacion']?.toString(),
      codigoContrato: json['codigo_contrato']?.toString() ?? json['cliente']?['codigo_contrato']?.toString(),
      novedadesNoc: json['novedades_noc']?.toString(),
      otroTelefono: json['otro_telefono']?.toString() ?? json['cliente']?['otro_telefono']?.toString(),
      telefonoFacturacion: json['telefono_facturacion']?.toString() ?? json['cliente']?['telefono_facturacion']?.toString(),
      deadlineAt: DateTime.tryParse(json['deadline_at'] ?? '')?.toLocal(),
    );
  }
}
