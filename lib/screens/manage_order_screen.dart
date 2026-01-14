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
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/upload_service.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/app_background.dart';
import '../widgets/processing_overlay.dart';
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
  String _loadingMessage = 'Procesando...';
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
             // PREVIOUS BUG: _loadPhotos() here caused the photo to vanish if API wasn't updated yet.
             // FIX: Just update the local object status.
             _galleryPhotos[index] = status;
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

  Future<void> _showSourceSelection() async {
    if (_galleryPhotos.length >= 12) {
      _showSnackbar('Límite de 12 fotos alcanzado.', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Cámara'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFromSource(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galería'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFromSource(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.camera) {
        final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
        if (pickedFile != null) {
          await _processAndUpload([pickedFile]);
        }
      } else {
        final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
        if (pickedFiles.isNotEmpty) {
          await _processAndUpload(pickedFiles);
        }
      }
    } catch (e) {
      _showSnackbar('Error al seleccionar imagen: $e', Colors.red);
    }
  }

  Future<void> _processAndUpload(List<XFile> files) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Procesando y marcando fotos...';
    });

    try {
      int remainingSlots = 12 - _galleryPhotos.length;
      final filesToProcess = files.take(remainingSlots);
      final appDir = await getApplicationDocumentsDirectory();

      for (var pickedFile in filesToProcess) {
        final fileName = 'WM_${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
        final targetPath = '${appDir.path}/$fileName';
        
        // 1. Watermark Processing
        final watermarkedFile = await _addWatermark(File(pickedFile.path), targetPath);
        
        // 2. Compress/Copy logic (Watermark alrdy saves to targetPath, maybe we compress after? 
        // Or if watermark saves high res, we correct. 
        // Simplest: Watermark -> Save. Compressor was used before.
        // Let's compress AFTER watermark if needed, or rely on watermark saving quality.
        // For efficiency, let's just use the watermarked file.
        
        File finalFile = watermarkedFile;

        // Optional: Extra compression if watermarked is still huge, but 'image' package encodes well usually.
        // If we want to strictly follow previous flow:
        // final result = await FlutterImageCompress.compressAndGetFile(...) 
        // But we already decoded/encoded in watermark. Doing it again is slow. 
        // Let's assume _addWatermark saves with good quality/size.

        final localId = await _photoRepo.addPhoto(widget.orden.numeroOrden, finalFile.path);
        if (mounted) {
          setState(() {
            _galleryPhotos.add(PhotoDisplay(localId: localId, path: finalFile.path, status: PhotoStatusType.local));
          });
        }
      }
      UploadService.instance.syncPendingUploads();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) _showSnackbar('Error al procesar imágenes: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<File> _addWatermark(File originalFile, String targetPath) async {
    try {
      final bytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image != null) {
        // Create Watermark Text
        final now = DateTime.now();
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
        final text = 'Intalnet - $dateStr';

        // Draw Text
        // Using built-in font for simplicity. 'arial_24' or similar comes with package usually or we use standard.
        // image package >= 4.0 uses different font handling.
        // Let's use standard default font (arial_24) provided by library if available, or just render.
        
        img.drawString(
          image,
          text,
          font: img.arial24,
          x: 20,
          y: 20,
          color: img.ColorRgb8(255, 165, 0), // Orange/Gold
        );
        
        // Save to target
        final encoded = img.encodeJpg(image, quality: 80);
        final file = File(targetPath);
        await file.writeAsBytes(encoded);
        return file;

      }
      // Fallback if decode fails
      return originalFile.copy(targetPath);
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      return originalFile.copy(targetPath);
    }
  }

  // --- Logic Helpers ---
  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
  
  void _addArticle() {
    String? selected = _predefinedArticles.first;
    final quantityCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final asocCtrl = TextEditingController();

    showDialog(
      context: context, 
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Agregar Artículo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Artículo', border: OutlineInputBorder()),
                  items: _predefinedArticles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setS(() => selected = v),
                ),
                if (selected != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cant.', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: valueCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Valor Unit.', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: asocCtrl,
                    decoration: const InputDecoration(labelText: 'ASOC', border: OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (selected != null) {
                  final qty = int.tryParse(quantityCtrl.text) ?? 1;
                  final val = double.tryParse(valueCtrl.text) ?? 0.0;
                  
                  setState(() => _articles.add({
                    'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
                    'articulo': selected, 
                    'grupo_articulo': selected,
                    'descripcion': descCtrl.text,
                    'asoc': asocCtrl.text,
                    'valor_unitario': val,
                    'cantidad': qty,
                    'total': qty * val
                  }));
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10447E), foregroundColor: Colors.white),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
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
    setState(() {
       _isLoading = true;
       _loadingMessage = 'Finalizando y Sincronizando...';
    });

    try {
      final techSig = await _technicianSignatureController.toPngBytes();
      final subSig = await _subscriberSignatureController.toPngBytes();
      
      final closingData = {
        'celular': _celularController.text,
        'observaciones': _obsOrigenController.text,
        'observaciones': _obsOrigenController.text,
        'solucion_tecnico': _selectedSolution?.split(', ').map((e) => e.trim()).toList(),
        'mac_router': _macRouterController.text,
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
      await SyncService.instance.sync();
      
      // Artificial delay to ensure user sees the "Finishing" status and feels the "server process" time
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('¡Orden finalizada exitosamente!'), backgroundColor: Colors.green),
        // );
        // Navigator.of(context).popUntil((route) => route.isFirst);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 60, color: Colors.green),
                SizedBox(height: 10),
                Text('Orden Finalizada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            content: const Text(
              'La orden ha sido finalizada y sincronizada correctamente.',
              textAlign: TextAlign.center,
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: const Text('Volver al Menú'),
                ),
              ),
            ],
          ),
        );
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
        body: ProcessingOverlay(
          isLoading: _isLoading,
          message: _loadingMessage,
          icon: _loadingMessage.contains('imágenes') ? Icons.photo_library : Icons.cloud_sync,
          child: SingleChildScrollView(
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
             itemBuilder: (ctx, i) {
               final photo = _galleryPhotos[i];
               Widget imageWidget;
               if (photo.url != null && photo.url!.isNotEmpty) {
                 imageWidget = Image.network(photo.url!, width: 100, height: 100, fit: BoxFit.cover,
                   errorBuilder: (context, error, stackTrace) => Container(
                     width: 100, height: 100, color: Colors.grey[300], 
                     child: const Icon(Icons.broken_image, color: Colors.grey)
                   ),
                 );
               } else {
                 imageWidget = Image.file(File(photo.path), width: 100, height: 100, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                     width: 100, height: 100, color: Colors.grey[300], 
                     child: const Icon(Icons.image_not_supported, color: Colors.grey)
                   ),
                 );
               }

               return Padding(
                 padding: const EdgeInsets.only(right: 8),
                 child: Stack(
                   children: [
                     imageWidget,
                     if (photo.status == PhotoStatusType.uploading)
                       const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                     if (photo.status == PhotoStatusType.uploaded)
                       const Positioned(right: 0, top: 0, child: Icon(Icons.check_circle, color: Colors.green, size: 20)),
                   ],
                 ),
               );
             },
           ),
         ),
         TextButton.icon(onPressed: _showSourceSelection, icon: const Icon(Icons.add_a_photo), label: const Text('Agregar Fotos'))
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
    // Parse current selection into a list
    List<String> currentSelections = [];
    if (_selectedSolution != null && _selectedSolution!.isNotEmpty) {
       currentSelections = _selectedSolution!.split(', ').map((e) => e.trim()).toList();
    }
    
    // Sort options to match the ID order if possible or just values
    final options = Orden.solucionTecnicoOptions.values.toList();
    // Add special options
    final allOptions = [...options, 'Solicitar Cierre', 'Reprogramar'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Seleccionar Solución'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allOptions.length,
                  itemBuilder: (context, index) {
                    final option = allOptions[index];
                    final isSelected = currentSelections.contains(option);
                    return CheckboxListTile(
                      title: Text(option, style: const TextStyle(fontSize: 14)),
                      value: isSelected,
                      onChanged: (bool? checked) {
                        setModalState(() {
                          if (checked == true) {
                             // Special cases are exclusive? Or just normal tags? Let's treat them as normal for now or exclusive if needed.
                             // Usually "Reprogramar" is exclusive.
                             if (option == 'Solicitar Cierre' || option == 'Reprogramar') {
                                currentSelections = [option];
                             } else {
                                // Remove exclusive ones if selecting normal ones
                                currentSelections.remove('Solicitar Cierre');
                                currentSelections.remove('Reprogramar');
                                currentSelections.add(option);
                             }
                          } else {
                            currentSelections.remove(option);
                          }
                        });
                      },
                      dense: true,
                      activeColor: const Color(0xFF10447E),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                       _selectedSolution = currentSelections.join(', ');
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10447E), foregroundColor: Colors.white),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
