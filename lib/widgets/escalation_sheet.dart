import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../utils/image_watermark.dart';

/// Tipos de novedad que el técnico puede reportar al escalar una orden.
/// La clave es la que viaja a la API (debe coincidir con Orden::TIPO_NOVEDAD_OPTIONS).
const Map<String, String> kTiposNovedad = {
  'CAJA_LLENA': 'Caja llena',
  'CAJA_SIN_POTENCIA': 'Caja sin potencia',
  'CAJA_POTENCIA_BAJA': 'Caja con potencia baja',
  'SIN_COBERTURA': 'Sin cobertura',
  'OTROS': 'Otros (escribir la novedad)',
};

/// Hoja inferior para reportar una novedad y crear la orden de escalamiento.
///
/// Devuelve por `Navigator.pop` un mapa con:
/// - `offline`: bool — true si quedó encolada para enviarse al recuperar señal.
/// - `numero_orden`: String? — número de la orden nueva creada en línea.
class EscalationSheet extends StatefulWidget {
  final Orden orden;

  const EscalationSheet({super.key, required this.orden});

  @override
  State<EscalationSheet> createState() => _EscalationSheetState();
}

class _EscalationSheetState extends State<EscalationSheet> {
  static const Color _azulIntalnet = Color(0xFF10447E);

  final OrderRepository _orderRepo = OrderRepository();
  final TextEditingController _detalleController = TextEditingController();

  String? _tipoSeleccionado;
  String? _fotoPath;
  bool _incluirUbicacion = true;
  bool _saving = false;
  bool _procesandoFoto = false;

  @override
  void dispose() {
    _detalleController.dispose();
    super.dispose();
  }

  bool get _requiereDetalle => _tipoSeleccionado == 'OTROS';

  Future<void> _tomarFoto() async {
    setState(() => _procesandoFoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'ESC_${DateTime.now().millisecondsSinceEpoch}_${p.basename(picked.path)}';
      final targetPath = '${appDir.path}/$fileName';

      final resultPath = await compute(processImageWithWatermarkInIsolate, {
        'originalPath': picked.path,
        'targetPath': targetPath,
      });

      if (!mounted) return;
      setState(() => _fotoPath = resultPath);
    } catch (e) {
      if (mounted) _showSnack('No se pudo tomar la foto: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _procesandoFoto = false);
    }
  }

  Future<String?> _obtenerCoordenadas() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return null;

      return '${position.latitude.toStringAsFixed(7)},${position.longitude.toStringAsFixed(7)}';
    } catch (e) {
      debugPrint('Error obteniendo coordenadas para escalamiento: $e');
      return null;
    }
  }

  Future<void> _guardar() async {
    if (_tipoSeleccionado == null) {
      _showSnack('Selecciona el tipo de novedad.', Colors.orange);
      return;
    }
    if (_requiereDetalle && _detalleController.text.trim().isEmpty) {
      _showSnack('Describe la novedad.', Colors.orange);
      return;
    }

    setState(() => _saving = true);
    try {
      String? coordenadas;
      if (_incluirUbicacion) {
        coordenadas = await _obtenerCoordenadas();
      }

      final result = await _orderRepo.createEscalation(
        widget.orden.numeroOrden,
        tipoNovedad: _tipoSeleccionado!,
        detalle: _detalleController.text,
        coordenadas: coordenadas,
        fotoPath: _fotoPath,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('No se pudo crear la orden: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reportar Novedad',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Se creará una orden 039 ESCALAMIENTO pendiente para otro técnico.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tipo de novedad',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...kTiposNovedad.entries.map(
                  (e) => InkWell(
                    onTap: _saving ? null : () => setState(() => _tipoSeleccionado = e.key),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Icon(
                            _tipoSeleccionado == e.key
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: _tipoSeleccionado == e.key
                                ? _azulIntalnet
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.value, style: const TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_requiereDetalle) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detalleController,
                    maxLines: 3,
                    maxLength: 500,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: 'Describe la novedad',
                      hintText: 'Ej: caja NAP 12 sin tapa, fibra expuesta en la esquina...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(),
                SwitchListTile(
                  value: _incluirUbicacion,
                  onChanged: _saving ? null : (v) => setState(() => _incluirUbicacion = v),
                  title: const Text('Adjuntar ubicación GPS', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Si no la adjuntas, la orden hereda las coordenadas originales.',
                    style: TextStyle(fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeColor: _azulIntalnet,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fotoPath == null ? '¿Agregar foto de la novedad?' : 'Foto lista para adjuntar',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: (_saving || _procesandoFoto) ? null : _tomarFoto,
                      icon: _procesandoFoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_fotoPath == null ? Icons.camera_alt : Icons.check_circle,
                              color: _fotoPath == null ? _azulIntalnet : Colors.green),
                      label: Text(_fotoPath == null ? 'Foto' : 'Repetir'),
                    ),
                    if (_fotoPath != null)
                      IconButton(
                        onPressed: _saving ? null : () => setState(() => _fotoPath = null),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Quitar foto',
                      ),
                  ],
                ),
                if (_fotoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_fotoPath!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _guardar,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _saving ? 'CREANDO ORDEN...' : 'CREAR ORDEN DE ESCALAMIENTO',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azulIntalnet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
