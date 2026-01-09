import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:signature/signature.dart';
import '../models/orden_model.dart';
import '../models/photo_status_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/photo_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/upload_service.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/app_background.dart';
import 'photo_view_screen.dart';

class ManageOrderScreen extends StatefulWidget {
  final Orden orden;
  const ManageOrderScreen({super.key, required this.orden});

  @override
  _ManageOrderScreenState createState() => _ManageOrderScreenState();
}

class _ManageOrderScreenState extends State<ManageOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info
  late TextEditingController _celularController;
  late TextEditingController _obsOrigenController;
  String? _selectedSolution;

  // Equipment
  final _macRouterController = TextEditingController();
  final _macBridgeController = TextEditingController();
  final _macOntController = TextEditingController();
  final _otrosEquiposController = TextEditingController();

  // Signatures
  final SignatureController _technicianSignatureController = SignatureController(penStrokeWidth: 3);
  final SignatureController _subscriberSignatureController = SignatureController(penStrokeWidth: 3);

  // Photos
  List<PhotoDisplay> _galleryPhotos = [];
  bool _isLoading = false;
  StreamSubscription? _uploadSubscription;

  // Articles
  List<Map<String, dynamic>> _articles = [];
  final List<String> _predefinedArticles = [
    'Esclavo con wifi (unidad)', 'Mecanico sc/apc', 'Cable drop 1 hilo', 'Grapas de muro', 'Ont',
    'Canaleta plastica', 'Abrazadera metalicas', 'Chazos(unidad)', 'Tornillos(unidad)', 
    'Amarres plasticos (unidad)', 'Cinta bandi(centimetro)', 'Clavos', 'Conector RG6', 'Cable coaxial',
  ];

  @override
  void initState() {
    super.initState();
    _celularController = TextEditingController(text: widget.orden.celular);
    _obsOrigenController = TextEditingController(text: widget.orden.observaciones);
    _selectedSolution = widget.orden.solucionTecnico;
    _macRouterController.text = widget.orden.macRouter ?? '';
    _macBridgeController.text = widget.orden.macBridge ?? '';
    _macOntController.text = widget.orden.macOnt ?? '';
    _otrosEquiposController.text = widget.orden.otrosEquipos ?? '';
    
    if (widget.orden.articulos != null) {
        try {
           _articles = List<Map<String, dynamic>>.from(widget.orden.articulos!);
           for (var i = 0; i < _articles.length; i++) {
             _articles[i]['uuid'] = 'existing_$i';
           }
        } catch (e) {
           debugPrint('Error parsing existing articles: $e');
        }
    }
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPhotos();
    _uploadSubscription = UploadService.instance.uploadStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          final index = _galleryPhotos.indexWhere((p) => p.localId == status.localId);
          if (index != -1) {
            if (status.status == PhotoStatusType.uploaded) {
              _loadPhotos();
            } else {
              _galleryPhotos[index] = status;
            }
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _celularController.dispose();
    _obsOrigenController.dispose();
    _macRouterController.dispose();
    _macBridgeController.dispose();
    _macOntController.dispose();
    _otrosEquiposController.dispose();
    _technicianSignatureController.dispose();
    _subscriberSignatureController.dispose();
    super.dispose();
  }

  final PhotoRepository _photoRepo = PhotoRepository();
  final OrderRepository _orderRepo = OrderRepository();

  Future<void> _loadPhotos() async {
    try {
      final photos = await _photoRepo.getPhotos(widget.orden.numeroOrden);
      if (mounted) setState(() => _galleryPhotos = photos);
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    if (_galleryPhotos.length >= 12) {
      _showSnackbar('Límite de 12 fotos alcanzado.', Colors.orange);
      return;
    }
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      int remainingSlots = 12 - _galleryPhotos.length;
      final filesToProcess = pickedFiles.take(remainingSlots);
      final appDir = await getApplicationDocumentsDirectory();
      
      for (var pickedFile in filesToProcess) {
        final fileName = p.basename(pickedFile.path);
        final targetPath = '${appDir.path}/$fileName';
        File finalFile;
        
        final result = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path, targetPath, quality: 70, minWidth: 1920, minHeight: 1080,
        );
        finalFile = result != null ? File(result.path) : await File(pickedFile.path).copy(targetPath);
        
        final localId = await _photoRepo.addPhoto(widget.orden.numeroOrden, finalFile.path);
        if (mounted) {
          setState(() {
            _galleryPhotos.add(PhotoDisplay(localId: localId, path: finalFile.path, status: PhotoStatusType.local));
          });
        }
      }
      UploadService.instance.syncPendingUploads();
    }
  }

  // --- Logic Helpers ---
  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
  
  void _addArticle() {
    String? selected = _predefinedArticles.first;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Agregar Artículo'),
      content: DropdownButton<String>(
        value: selected, isExpanded: true,
        items: _predefinedArticles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setS(() => selected = v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () {
          if (selected != null) {
            setState(() => _articles.add({
              'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
              'articulo': selected, 'grupo_articulo': selected,
              'descripcion': '', 'asoc': '', 'valor_unitario': 0.0, 'cantidad': 0, 'total': 0.0
            }));
            Navigator.pop(ctx);
          }
        }, child: const Text('Agregar')),
      ],
    )));
  }

  // --- VALIDATION AND FINALIZE ---
  Future<void> _finalizeOrder() async {
    List<String> missingFields = [];

    // 1. Solución Técnico check
    if (_selectedSolution == null) missingFields.add('Solución Técnico (Obligatorio)');
    
    bool isSpecialCase = _selectedSolution == 'Solicitar Cierre' || _selectedSolution == 'Reprogramar';

    // 2. Observations
    if (isSpecialCase && _obsOrigenController.text.trim().isEmpty) {
        missingFields.add('Motivo/Observaciones (Obligatorio para reprogramar o cerrar)');
    }

    // 3. Normal Flow Checks
    if (!isSpecialCase) {
        // Signatures
        if (_technicianSignatureController.isEmpty) missingFields.add('Firma del Técnico');
        if (_subscriberSignatureController.isEmpty) missingFields.add('Firma del Cliente');
        
        // Photos (Except 037)
        bool isPasswordChange = widget.orden.tipoOrden != null && widget.orden.tipoOrden!.contains('037');
        if (_galleryPhotos.isEmpty && !isPasswordChange) {
           missingFields.add('Al menos 1 foto como evidencia');
        }
        
        // Pending Uploads
        if (_galleryPhotos.any((p) => p.status != PhotoStatusType.uploaded)) {
            missingFields.add('Esperar subida de todas las fotos');
        }
    }

    // SHOW DETAILED ERROR DIALOG
    if (missingFields.isNotEmpty) {
       showDialog(
         context: context,
         builder: (_) => AlertDialog(
           title: const Row(children: [Icon(Icons.error, color: Colors.orange), SizedBox(width: 8), Text('Faltan Datos')]),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: missingFields.map((e) => Padding(
               padding: const EdgeInsets.symmetric(vertical: 4),
               child: Row(children: [const Icon(Icons.circle, size: 8, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(e))]),
             )).toList(),
           ),
           actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
         )
       );
       return;
    }

    // Proceed to Close
    setState(() => _isLoading = true);
    try {
      final techSig = await _technicianSignatureController.toPngBytes();
      final subSig = await _subscriberSignatureController.toPngBytes();
      
      final closingData = {
        'celular': _celularController.text,
        'observaciones': _obsOrigenController.text,
        'solucion_tecnico': _selectedSolution,
        'mac_router': _macRouterController.text,
        'mac_bridge': _macBridgeController.text,
        'mac_ont': _macOntController.text,
        'otros_equipos': _otrosEquiposController.text,
        'articulos': _articles,
        'firma_tecnico': techSig != null ? 'data:image/png;base64,${base64Encode(techSig)}' : null,
        'firma_suscriptor': subSig != null ? 'data:image/png;base64,${base64Encode(subSig)}' : null,
      };

      await _orderRepo.closeOrder(widget.orden.numeroOrden, closingData);
      UploadService.instance.syncPendingUploads();
      SyncService.instance.sync();

      if (mounted) {
        _showSnackbar('Orden finalizada exitosamente.', Colors.green);
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) _showSnackbar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDING BLOCKS ---
  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Gestionar Orden #${widget.orden.numeroOrden}'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
                // Persistent Header
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10447E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Text(widget.orden.nombreCliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(widget.orden.direccion ?? 'Sin Dirección', style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                    ],
                  ),
                ),

               _buildCard('Información', Icons.info, [
                  _buildTextField(_celularController, 'Celular', Icons.phone),
               ]),
               _buildCard('Artículos', Icons.handyman, [
                  _buildArticlesList(),
                  TextButton.icon(onPressed: _addArticle, icon: const Icon(Icons.add), label: const Text('Agregar Artículo')),
               ]),
               _buildCard('Equipos', Icons.router, [
                  _buildTextField(_macRouterController, 'MAC Router', Icons.router),
                  const SizedBox(height: 10),
                  _buildTextField(_macBridgeController, 'MAC Bridge', Icons.settings_ethernet),
                  const SizedBox(height: 10),
                  _buildTextField(_macOntController, 'MAC ONT', Icons.router),
                  const SizedBox(height: 10),
                  _buildTextField(_otrosEquiposController, 'Otros Equipos', Icons.devices_other),
               ]),
               _buildCard('Evidencia Fotográfica', Icons.camera_alt, [
                  _buildPhotoGallery(),
               ]),
               _buildCard('Firmas', Icons.draw, [
                  const Text('Técnico', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildSignaturePad(_technicianSignatureController),
                  const SizedBox(height: 10),
                  const Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildSignaturePad(_subscriberSignatureController),
               ]),
               _buildCard('Cierre', Icons.check_circle, [
                 ListTile(
                   title: const Text('Solución Técnico'),
                   subtitle: Text(_selectedSolution ?? 'Seleccionar...', style: const TextStyle(color: Colors.blue)),
                   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                   onTap: _showSolutionSelectionModal,
                   contentPadding: EdgeInsets.zero,
                 ),
                 const Divider(),
                 _buildTextField(_obsOrigenController, _selectedSolution == 'Reprogramar' ? 'Motivo Reprogramación' : 'Observaciones', Icons.comment, maxLines: 3),
                 const SizedBox(height: 20),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton.icon(
                     onPressed: _isLoading ? null : _finalizeOrder,
                     icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
                     label: const Text('FINALIZAR ORDEN', style: TextStyle(fontWeight: FontWeight.bold)),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF10447E),
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       elevation: 5,
                     ),
                   ),
                 )
               ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Icon(icon, color: const Color(0xFF10447E)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const Divider(height: 24),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
    );
  }

  Widget _buildSignaturePad(SignatureController ctrl) {
    return Container(
      height: 120,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
      child: Signature(controller: ctrl, backgroundColor: Colors.white),
    );
  }

  Widget _buildPhotoGallery() {
    return Column(
      children: [
         if (_galleryPhotos.isEmpty) const Text('Sin fotos agregadas', style: TextStyle(color: Colors.grey)),
         if (_galleryPhotos.isNotEmpty) SizedBox(
           height: 100,
           child: ListView.builder(
             scrollDirection: Axis.horizontal,
             itemCount: _galleryPhotos.length,
             itemBuilder: (ctx, i) => Padding(
               padding: const EdgeInsets.only(right: 8),
               child: Image.file(File(_galleryPhotos[i].path), width: 100, height: 100, fit: BoxFit.cover),
             ),
           ),
         ),
         TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.add_a_photo), label: const Text('Agregar Fotos'))
      ],
    );
  }

  Widget _buildArticlesList() {
    if (_articles.isEmpty) return const SizedBox.shrink();
    return Column(children: _articles.map((a) {
      final nombre = a['grupo_articulo']?.toString() ?? a['articulo']?.toString() ?? 'Sin Nombre';
      final cantidad = a['cantidad']?.toString() ?? '0';
      return ListTile(
        title: Text(nombre), 
        subtitle: Text('Cant: $cantidad'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red), 
          onPressed: () => setState(() => _articles.remove(a))
        ),
      );
    }).toList());
  }

  void _showSolutionSelectionModal() {
      showModalBottomSheet(context: context, builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          '1 CAMBIO - CONECTOR', '2 REINICIO EQUIPOS', '3 CAMBIO EQUIPO', 'Solicitar Cierre', 'Reprogramar'
        ].map((e) => ListTile(
          title: Text(e),
          onTap: () { setState(() => _selectedSolution = e); Navigator.pop(context); },
        )).toList(),
      ));
  }
}
