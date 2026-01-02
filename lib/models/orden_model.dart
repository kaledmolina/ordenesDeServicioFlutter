class Orden {
  final int id;
  final String numeroOrden;
  final String? numeroExpediente;
  final String nombreCliente;
  final DateTime fechaHora;
  final double? valorServicio;
  final String? celular;
  final String? direccion;
  final String? observaciones;
  final String status;
  final String? nombreAsignado;
  final bool esProgramada;
  final DateTime? fechaProgramada;
  final DateTime? fechaLlegada;
  final String? solucionTecnico;
  final String? macRouter;
  final String? macBridge;
  final String? macOnt;
  final String? otrosEquipos;
  final String? firmaTecnico;
  final String? firmaSuscriptor;
  final List<dynamic>? articulos;

  Orden({
    required this.id,
    required this.numeroOrden,
    this.numeroExpediente,
    required this.nombreCliente,
    required this.fechaHora,
    this.valorServicio,
    this.celular,
    this.direccion,
    this.observaciones,
    required this.status,
    this.nombreAsignado,
    required this.esProgramada,
    this.fechaProgramada,
    this.fechaLlegada,
    this.solucionTecnico,
    this.macRouter,
    this.macBridge,
    this.macOnt,
    this.otrosEquipos,
    this.firmaTecnico,
    this.firmaSuscriptor,
    this.articulos,
  });

  factory Orden.fromJson(Map<String, dynamic> json) {
    return Orden(
      id: json['id'],
      numeroOrden: json['numero_orden'],
      numeroExpediente: json['numero_expediente'],
      nombreCliente: json['nombre_cliente'] ?? 'Cliente Desconocido',
      fechaHora: DateTime.tryParse(json['created_at'] ?? json['fecha_hora'] ?? '')?.toLocal() ?? DateTime.now(),
      valorServicio: double.tryParse(json['valor_servicio']?.toString() ?? json['valor_total']?.toString() ?? '0'),
      celular: json['celular'] ?? json['telefono'],
      direccion: json['direccion'],
      observaciones: json['observaciones'],
      status: json['status'] ?? 'desconocido',
      nombreAsignado: json['nombre_asignado'],
      esProgramada: json['es_programada'] == 1 || json['es_programada'] == true,
      fechaProgramada: DateTime.tryParse(json['fecha_programada'] ?? '')?.toLocal(),
      fechaLlegada: DateTime.tryParse(json['fecha_llegada'] ?? '')?.toLocal(),
      solucionTecnico: json['solucion_tecnico'],
      macRouter: json['mac_router'],
      macBridge: json['mac_bridge'],
      macOnt: json['mac_ont'],
      otrosEquipos: json['otros_equipos'],
      firmaTecnico: json['firma_tecnico'],
      firmaSuscriptor: json['firma_suscriptor'],
      articulos: json['articulos'],
    );
  }
}
