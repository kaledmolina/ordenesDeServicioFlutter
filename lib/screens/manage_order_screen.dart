import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
import '../widgets/glass_card.dart';
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
  late TextEditingController _solucionController;

  // Equipment
  final _macRouterController = TextEditingController();
  final _macBridgeController = TextEditingController();
  final _macOntController = TextEditingController();
  final _otrosEquiposController = TextEditingController();

  // Signatures
  final SignatureController _technicianSignatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  final SignatureController _subscriberSignatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  // Photos
  List<PhotoDisplay> _galleryPhotos = [];
  bool _isLoading = false;
  StreamSubscription? _uploadSubscription;
  String? _authToken;

  // Articles
  List<Map<String, dynamic>> _articles = [];
  final List<String> _predefinedArticles = [
    'Esclavo con wifi (unidad)',
    'Mecanico sc/apc',
    'Cable drop 1 hilo',
    'Grapas de muro',
    'Ont',
    'Canaleta plastica',
    'Abrazadera metalicas',
    'Chazos(unidad)',
    'Tornillos(unidad)',
    'Amarres plasticos (unidad)',
    'Cinta bandi(centimetro)',
    'Clavos',
    'Conector RG6',
    'Cable coaxial',
  ];

  @override
  void initState() {
    super.initState();
    _celularController = TextEditingController(text: widget.orden.celular);
    _obsOrigenController = TextEditingController(text: widget.orden.observaciones);
    _solucionController = TextEditingController(text: widget.orden.solucionTecnico ?? '');
    _macRouterController.text = widget.orden.macRouter ?? '';
    _macBridgeController.text = widget.orden.macBridge ?? '';
    _macOntController.text = widget.orden.macOnt ?? '';
    _otrosEquiposController.text = widget.orden.otrosEquipos ?? '';
    
    // Load existing articles if any (assuming JSON structure matches)
    if (widget.orden.articulos != null) {
        try {
           _articles = List<Map<String, dynamic>>.from(widget.orden.articulos!);
           // Assign stable IDs for UI keys
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
    _authToken = await AuthService.instance.getToken();
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
    _solucionController.dispose();
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
    setState(() => _isLoading = true);
    try {
      final photos = await _photoRepo.getPhotos(widget.orden.numeroOrden);
      if (mounted) {
        setState(() {
          _galleryPhotos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final int currentCount = _galleryPhotos.length;
    if (currentCount >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya has alcanzado el límite de 12 fotos.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      int remainingSlots = 12 - currentCount;
      final filesToProcess = pickedFiles.take(remainingSlots);
      final appDir = await getApplicationDocumentsDirectory();
      
      List<File> newImages = [];
      for (var pickedFile in filesToProcess) {
        final fileName = p.basename(pickedFile.path);
        final targetPath = '${appDir.path}/$fileName';
        
        final result = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          targetPath,
          quality: 70,
          minWidth: 1920,
          minHeight: 1080,
        );

        if (result != null) {
          newImages.add(File(result.path));
        } else {
          final savedImage = await File(pickedFile.path).copy(targetPath);
          newImages.add(savedImage);
        }
      }
      
      for (var file in newImages) {
        // 1. Guardar en DB inmediatamente y obtener ID
        final localId = await _photoRepo.addPhoto(widget.orden.numeroOrden, file.path);
        
        // 2. Actualizar estado local
        if (mounted) {
          setState(() {
            _galleryPhotos.add(PhotoDisplay(
              localId: localId, 
              path: file.path, 
              status: PhotoStatusType.local
            ));
          });
        }
      }
      
      // 3. Iniciar subida inmediatamente
      UploadService.instance.syncPendingUploads();
    }
  }

  // --- Articles Logic ---

  void _addArticle() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedArticle = _predefinedArticles.first;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Agregar Artículo'),
              content: DropdownButton<String>(
                value: selectedArticle,
                isExpanded: true,
                items: _predefinedArticles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setStateDialog(() => selectedArticle = val),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedArticle != null) {
                      setState(() {
                        _articles.add({
                          'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
                          'articulo': selectedArticle,
                          'grupo_articulo': selectedArticle,
                          'descripcion': '', 
                          'asoc': '', 
                          'valor_unitario': 0.0,
                          'cantidad': 0,
                          'total': 0.0,
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _updateArticle(int index, String field, dynamic value) {
    setState(() {
      _articles[index][field] = value;
      if (field == 'valor_unitario' || field == 'cantidad') {
        final v = double.tryParse(_articles[index]['valor_unitario'].toString()) ?? 0;
        final c = int.tryParse(_articles[index]['cantidad'].toString()) ?? 0;
        _articles[index]['total'] = v * c;
      }
    });
  }

  void _removeArticle(int index) {
      setState(() {
          _articles.removeAt(index);
      });
  }

  void _moveArticle(int oldIndex, int newIndex) {
      setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _articles.removeAt(oldIndex);
          _articles.insert(newIndex, item);
      });
  }
  
  // --- Savings Logic ---

  Future<String?> _exportSignature(SignatureController controller) async {
    if (controller.isEmpty) return null;
    final Uint8List? data = await controller.toPngBytes();
    if (data == null) return null;
    return 'data:image/png;base64,${base64Encode(data)}';
  }

  Future<void> _finalizeOrder() async {
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor revisa los campos requeridos.')),
      );
      return;
    }
    
    if (_technicianSignatureController.isEmpty || _subscriberSignatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambas firmas son obligatorias para finalizar.')),
      );
      return;
    }

    // Validation: 025 REVISION TECNICA requires Solucion Tecnico
    if (widget.orden.tipoOrden != null && widget.orden.tipoOrden!.contains('025')) {
      if (_solucionController.text.trim().isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La Solución Técnica es obligatoria para este tipo de orden.')),
        );
        return;
      }
    }

    // Validation: Photos are mandatory unless it is 037 CAMBIO CONTRASEÑA
    bool isPasswordChange = widget.orden.tipoOrden != null && widget.orden.tipoOrden!.contains('037');
    if (_galleryPhotos.isEmpty && !isPasswordChange) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos una foto de la orden.')),
      );
      return;
    }

    // Validation: Check if all photos are uploaded
    final hasPendingUploads = _galleryPhotos.any((p) => p.status != PhotoStatusType.uploaded);
    if (hasPendingUploads) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor espera a que todas las fotos se suban a la nube antes de finalizar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Process signatures
      final techSig = await _exportSignature(_technicianSignatureController);
      final subSig = await _exportSignature(_subscriberSignatureController);

      // 2. Prepare Data
      final closingData = {
        'celular': _celularController.text,
        'observaciones': _obsOrigenController.text,
        'solucion_tecnico': _solucionController.text,
        'mac_router': _macRouterController.text,
        'mac_bridge': _macBridgeController.text,
        'mac_ont': _macOntController.text,
        'otros_equipos': _otrosEquiposController.text,
        'articulos': _articles,
        'firma_tecnico': techSig,
        'firma_suscriptor': subSig,
      };

      // 3. Close Order
      await _orderRepo.closeOrder(widget.orden.numeroOrden, closingData);

      // 4. Handle Photos (Sync)
      // 4. Handle Photos (Sync) is now handled immediately upon selection
      // Ensure sync is running just in case
      UploadService.instance.syncPendingUploads();
      SyncService.instance.sync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden finalizada exitosamente.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          actions: const [
             Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: ConnectionStatusIndicator(),
            ),
          ],
        ),
      body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAccordionSection(
                  title: 'Información General',
                  icon: Icons.info_outline,
                  child: _buildBasicInfoContent(),
                  initiallyExpanded: false,
                ).animate().fade().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                _buildAccordionSection(
                  title: 'Artículos y Materiales',
                  icon: Icons.handyman, 
                  child: _buildArticlesContent(),
                  initiallyExpanded: false,
                ).animate().fade(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                
                _buildAccordionSection(
                  title: 'Equipos Instalados/Retirados',
                  icon: Icons.router,
                  child: _buildEquipmentContent(),
                  initiallyExpanded: false,
                ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                _buildAccordionSection(
                  title: 'Evidencia Fotográfica',
                  icon: Icons.camera_alt,
                  child: _buildPhotosContent(),
                  initiallyExpanded: false,
                ).animate().fade(delay: 300.ms),
                const SizedBox(height: 16),

                _buildAccordionSection(
                  title: 'Firmas',
                  icon: Icons.draw,
                  child: _buildSignaturesContent(),
                  initiallyExpanded: false,
                ).animate().fade(delay: 400.ms),

                const SizedBox(height: 32),
                
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('FINALIZAR ORDEN'),
                  onPressed: _isLoading ? null : _finalizeOrder,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ).animate().scale(delay: 500.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccordionSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: Colors.white, // Opaque background for readability
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [child],
      ),
    );
  }

  Widget _buildBasicInfoContent() {
    return Column(
      children: [
        TextFormField(
          controller: _celularController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Celular Contacto',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey, // Light grey fill
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _obsOrigenController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observaciones de Cierre',
            prefixIcon: Icon(Icons.comment),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _solucionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Solución Técnico',
            prefixIcon: Icon(Icons.engineering),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildArticlesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Lista de Artículos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            TextButton.icon(
              onPressed: _addArticle,
              icon: const Icon(Icons.add_circle, size: 20),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const Divider(),
        if (_articles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No hay artículos agregados', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _articles.length,
            onReorder: _moveArticle,
            itemBuilder: (context, index) {
               final article = _articles[index];
               final qty = int.tryParse(article['cantidad']?.toString() ?? '0') ?? 0;
               final uuid = article['uuid'] ?? 'temp_$index'; // Fallback
               
               return Card(
                 key: ValueKey(uuid), 
                 margin: const EdgeInsets.only(bottom: 12),
                 elevation: 0,
                 color: Colors.grey.shade50, // Slightly simpler card for inside accordion
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12),
                   side: BorderSide(color: Colors.grey.shade200)
                  ),
                 child: Padding(
                   padding: const EdgeInsets.all(12.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Header: Name and Delete
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Expanded(
                             child: Text(
                               article['grupo_articulo']?.toString() ?? article['articulo']?.toString() ?? 'SIN NOMBRE',
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                             onPressed: () => _removeArticle(index),
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                           ),
                         ],
                       ),
                       const Divider(),
                       
                       // Quantity Stepper and Unit Price
                       Row(
                         children: [
                           // Stepper
                           Container(
                             decoration: BoxDecoration(
                               border: Border.all(color: Colors.grey.shade300),
                               borderRadius: BorderRadius.circular(8),
                               color: Colors.white,
                             ),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 IconButton(
                                   icon: const Icon(Icons.remove, color: Colors.indigo, size: 18),
                                   onPressed: () {
                                     if (qty > 0) _updateArticle(index, 'cantidad', qty - 1);
                                   },
                                   padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                 ),
                                 Text(
                                   '$qty',
                                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                 ),
                                 IconButton(
                                   icon: const Icon(Icons.add, color: Colors.indigo, size: 18),
                                   onPressed: () => _updateArticle(index, 'cantidad', qty + 1),
                                   padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(width: 12),
                           
                           // Unit Price Input
                           Expanded(
                             child: TextFormField(
                               initialValue: article['valor_unitario']?.toString() ?? '0',
                               decoration: const InputDecoration(
                                 labelText: 'Valor Unit.',
                                 prefixText: '\$',
                                 isDense: true,
                                 border: OutlineInputBorder(),
                                 contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                               ),
                               keyboardType: TextInputType.number,
                               onChanged: (val) => _updateArticle(index, 'valor_unitario', val),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 8),
                       
                       // Description and ASOC
                       Row(
                         children: [
                           Expanded(
                             flex: 2,
                             child: TextFormField(
                               initialValue: article['descripcion']?.toString() ?? '',
                               decoration: const InputDecoration(
                                 labelText: 'Serial/Desc',
                                 isDense: true,
                                 border: OutlineInputBorder(),
                                 contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                               ),
                               onChanged: (val) => _updateArticle(index, 'descripcion', val),
                             ),
                           ),
                           const SizedBox(width: 8),
                           Expanded(
                             flex: 1,
                             child: TextFormField(
                               initialValue: article['asoc']?.toString() ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'ASOC',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (val) => _updateArticle(index, 'asoc', val),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 8),
                       
                       // Total Footer
                       Align(
                         alignment: Alignment.centerRight,
                         child: Text(
                           'Total: \$${article['total']?.toString() ?? '0'}',
                           style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                         ),
                       ),
                     ],
                   ),
                 ),
               );
            },
          ),
      ],
    );
  }

  Widget _buildEquipmentContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _macRouterController,
          decoration: const InputDecoration(labelText: 'Mac Router', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _macBridgeController,
          decoration: const InputDecoration(labelText: 'Mac Bridge', border: OutlineInputBorder()),
        ),
         const SizedBox(height: 12),
        TextFormField(
          controller: _macOntController,
          decoration: const InputDecoration(labelText: 'Mac Ont', border: OutlineInputBorder()),
        ),
         const SizedBox(height: 12),
        TextFormField(
          controller: _otrosEquiposController,
          decoration: const InputDecoration(labelText: 'Otros Equipos', border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildPhotosContent() {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              _isLoading && _galleryPhotos.isEmpty 
                  ? const Center(child: CircularProgressIndicator()) 
                  : _buildPhotoGrid(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo, color: Colors.blue),
                label: const Text('Añadir Foto'),
                onPressed: _pickImage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.blue),
                  foregroundColor: Colors.blue,
                ),
              ),
          ],
      );
  }

  Widget _buildSignaturesContent() {
    return Column(
      children: [
        _buildSignaturePadContent('Firma Técnico', _technicianSignatureController),
        const SizedBox(height: 16),
        _buildSignaturePadContent('Firma Suscriptor', _subscriberSignatureController),
      ],
    );
  }

  Widget _buildSignaturePadContent(String title, SignatureController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
             Row(
               children: [
                 IconButton(
                   icon: const Icon(Icons.undo, size: 20), 
                   onPressed: () => controller.undo(),
                   tooltip: 'Deshacer',
                 ),
                 IconButton(
                   icon: const Icon(Icons.clear, color: Colors.red, size: 20), 
                   onPressed: () => controller.clear(),
                   tooltip: 'Limpiar',
                 ),
               ],
             )
           ],
         ),
         Container(
           height: 150,
           decoration: BoxDecoration(
             border: Border.all(color: Colors.grey.shade400),
             borderRadius: BorderRadius.circular(8),
             color: Colors.white,
           ),
           clipBehavior: Clip.antiAlias,
           child: Signature(
             controller: controller,
             backgroundColor: Colors.transparent,
             height: 150,
             width: double.infinity,
           ),
         ),
      ],
    );
  }
  
  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _galleryPhotos.length,
      itemBuilder: (context, index) {
        return _buildPhotoItem(_galleryPhotos[index]);
      },
    );
  }

  Widget _buildPhotoItem(PhotoDisplay photo) {
    Widget imageWidget;
    if (photo.status == PhotoStatusType.uploaded && photo.url != null) {
      imageWidget = Image.network(
        photo.url!,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $_authToken'},
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image, color: Colors.red);
        },
      );
    } else {
      imageWidget = Image.file(File(photo.path), fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PhotoViewScreen(photo: photo, authToken: _authToken),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (photo.status == PhotoStatusType.local)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 30),
              ),
            if (photo.status == PhotoStatusType.uploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
             if (photo.status == PhotoStatusType.error)
              Container(
                 color: Colors.black.withOpacity(0.5),
                 child: const Icon(Icons.error_outline, color: Colors.red, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}
