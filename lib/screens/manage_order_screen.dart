import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
import '../services/api_service.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/app_background.dart';
import '../widgets/processing_overlay.dart';
import 'photo_view_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageOrderScreen extends StatefulWidget {
  final Orden orden;
  const ManageOrderScreen({super.key, required this.orden});

  @override
  _ManageOrderScreenState createState() => _ManageOrderScreenState();
}

class _ManageOrderScreenState extends State<ManageOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  Timer? _draftDebounce;
  static const String _draftKeyPrefix = "draft_order_";
  
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
  File? _savedSignatureFile;

  // Photos
  List<PhotoDisplay> _galleryPhotos = [];
  bool _isLoading = false;
  String _loadingMessage = 'Procesando...';
  StreamSubscription? _uploadSubscription;
  Key _signatureKey = UniqueKey();
  File? _savedSubscriberSignatureFile;

  // Articles
  List<Map<String, dynamic>> _articles = [];
  final List<String> _predefinedArticles = [
    'Esclavo con wifi (unidad)', 'Mecanico sc/apc', 'Cable drop 1 hilo', 'Grapas de muro', 'Ont',
    'Canaleta plastica', 'Abrazadera metalicas', 'Chazos(unidad)', 'Tornillos(unidad)', 
    'Amarres plasticos (unidad)', 'Cinta bandi(centimetro)', 'Clavos',    'Conector RG6',
    'Cable coaxial',
    'Router',
    'Bridge',
    'Camara',
    'Onu',
    'Otros',
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
    
    _addDraftListeners();
    // We run the async loading sequence safely after the first frame builds
    Future.microtask(() async {
       await _loadPhotos();
       await _loadDraft();
       await _loadSubscriberSignature();
       await _initialize();
    });
    _startDeadlineTimer();
  }

  Future<void> _loadSubscriberSignature() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final signFile = File(p.join(appDir.path, 'sub_sig_${widget.orden.numeroOrden}.png'));
      if (await signFile.exists()) {
        if (mounted) setState(() => _savedSubscriberSignatureFile = signFile);
      }
    } catch (e) {
      debugPrint('Error loading subscriber signature: $e');
    }
  }

  void _addDraftListeners() {
    _celularController.addListener(_onFieldChanged);
    _obsOrigenController.addListener(_onFieldChanged);
    _macRouterController.addListener(_onFieldChanged);
    _macBridgeController.addListener(_onFieldChanged);
    _macOntController.addListener(_onFieldChanged);
    _otrosEquiposController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_draftDebounce?.isActive ?? false) _draftDebounce!.cancel();
    _draftDebounce = Timer(const Duration(seconds: 1), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = {
        'celular': _celularController.text,
        'obs': _obsOrigenController.text,
        'solucion': _selectedSolution,
        'mac_router': _macRouterController.text,
        'mac_bridge': _macBridgeController.text,
        'mac_ont': _macOntController.text,
        'otros': _otrosEquiposController.text,
        'articles': _articles,
      };
      await prefs.setString('$_draftKeyPrefix${widget.orden.numeroOrden}', jsonEncode(draftData));
    } catch(e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_draftKeyPrefix${widget.orden.numeroOrden}';
      final draftString = prefs.getString(key);
      
      if (draftString != null) {
        final data = jsonDecode(draftString) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _celularController.text = data['celular'] ?? _celularController.text;
            _obsOrigenController.text = data['obs'] ?? _obsOrigenController.text;
            _selectedSolution = data['solucion'] ?? _selectedSolution;
            _macRouterController.text = data['mac_router'] ?? _macRouterController.text;
            _macBridgeController.text = data['mac_bridge'] ?? _macBridgeController.text;
            _macOntController.text = data['mac_ont'] ?? _macOntController.text;
            _otrosEquiposController.text = data['otros'] ?? _otrosEquiposController.text;
             
            if (data['articles'] != null) {
              _articles = List<Map<String, dynamic>>.from(data['articles']);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Borrador local recuperado'), duration: Duration(seconds: 2))
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_draftKeyPrefix${widget.orden.numeroOrden}');
    } catch (e) {
      debugPrint('Error clearing draft: $e');
    }
  }

  // Timer Logic
  Timer? _deadlineTimer;
  Duration _timeLeft = Duration.zero;
  bool _isOverdue = false;

  void _startDeadlineTimer() {
    if (widget.orden.deadlineAt == null) return;
    
    _updateTimeLeft(); // Initial check
    
    _deadlineTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeLeft();
        });
      }
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final deadline = widget.orden.deadlineAt!;
    
    if (now.isAfter(deadline)) {
      _isOverdue = true;
      _timeLeft = now.difference(deadline);
    } else {
      _isOverdue = false;
      _timeLeft = deadline.difference(now);
    }
  }

  Widget _buildDeadlineWidget() {
    if (widget.orden.deadlineAt == null) return const SizedBox.shrink();

    // Format duration: "Xh Ym"
    String formatDuration(Duration d) {
      int hours = d.inHours;
      int minutes = d.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    }

    final color = _isOverdue ? Colors.redAccent : Colors.lightGreenAccent;
    final icon = _isOverdue ? Icons.warning_amber_rounded : Icons.timer;
    final text = _isOverdue 
        ? 'VENCIDA HACE: ${formatDuration(_timeLeft)}' 
        : 'VENCE EN: ${formatDuration(_timeLeft)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text, 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)
          ),
        ],
      ),
    );
  }

  List<String> _evidenceTypes = [
    'Test velocidad',
    'Vista general router',
    'Mac router instalado',
    'Mac britge intalada',
    'Mac router desintalda',
    'Mac britge desintalda',
    'Serial camara intalada',
    'Serial camara desintalada',
    'Potencia',
  ];

  Future<void> _initialize() async {
    _fetchEvidenceTypes();
    _fetchProfileAndSignature();
    
    _uploadSubscription = UploadService.instance.uploadStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          final index = _galleryPhotos.indexWhere((p) => p.localId == status.localId);
          if (index != -1) {
             _galleryPhotos[index] = status;
          }
        });
      }
    });
  }

  Future<void> _fetchProfileAndSignature() async {
    try {
      final profile = await ApiService().getProfile();
      final signatureUrl = profile['signature_url'];
      if (signatureUrl != null && signatureUrl.isNotEmpty) {
         await _cacheSignature(signatureUrl);
      } else {
         // Fallback to local file check (legacy)
         _loadSavedSignature();
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      _loadSavedSignature();
    }
  }

  Future<void> _cacheSignature(String url) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, 'technician_signature.png'));
      
      // Always download fresh or check timestamp? For now, download to sync updates.
      // Or check if file exists and maybe skip? User wants "always consult".
      // Let's download if we have a URL.
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes, flush: true);
        if (mounted) {
             setState(() => _savedSignatureFile = file);
        }
      } else {
        debugPrint('Failed to download signature: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error caching signature: $e');
    }
  }

  Future<void> _loadSavedSignature() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, 'technician_signature.png'));
      if (await file.exists()) {
        if (mounted) setState(() => _savedSignatureFile = file);
      }
    } catch (e) {
      debugPrint('Error loading saved signature: $e');
    }
  }

  void _showSignatureDialog() {
    final controller = SignatureController(penStrokeWidth: 3);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Firma del Técnico'),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             SizedBox(
               height: 180,
               width: 300,
               child: Container(
                 decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                 child: Stack(
                   children: [
                     Signature(controller: controller, backgroundColor: Colors.white, height: 180, width: 300),
                     Positioned(right:4, top:4, child: IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => controller.clear()))
                   ]
                 ),
               ),
             ),
           ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.isNotEmpty) {
                Navigator.pop(ctx);
                await _saveAndUploadSignature(controller);
              }
            },
            child: const Text('Guardar y Actualizar')
          )
        ],
      )
    );
  }

  Future<void> _saveAndUploadSignature(SignatureController controller) async {
    setState(() { _isLoading = true; _loadingMessage = 'Guardando firma...'; });
    try {
      final bytes = await controller.toPngBytes();
      if (bytes != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File(p.join(appDir.path, 'technician_signature.png'));
        await file.writeAsBytes(bytes, flush: true);
        
        // Upload (graceful fallback if offline)
        try {
          await ApiService().updateSignature(file);
        } catch (e) {
          debugPrint('Aviso: Firma guardada localmente, pero no se pudo sincronizar el perfil: $e');
        }
        
        await FileImage(file).evict();
        
        setState(() {
          _savedSignatureFile = file;
          _signatureKey = UniqueKey();
        });
        _showSnackbar('Firma guardada correctamente', Colors.green);
      }
    } catch (e) {
      _showSnackbar('Error al guardar firma: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEvidenceTypes() async {
    try {
      final types = await ApiService().getEvidenceTypes();
      if (mounted && types.isNotEmpty) {
        setState(() => _evidenceTypes = types);
      }
    } catch (e) {
      debugPrint('Error fetching evidence types, using defaults: $e');
    }
  }
  
  @override
  void dispose() {
    _deadlineTimer?.cancel();
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

  Future<String?> _showTypeSelectionDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // Force selection or cancel explicitly
      builder: (ctx) => SimpleDialog(
        title: const Text('Seleccionar Tipo de Foto'),
        children: [
          ..._evidenceTypes.map((type) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, type),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(type, style: const TextStyle(fontSize: 16)),
            ),
          )),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '__OTRO__'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Otro (Escribir Motivo)', style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null), // Return null on cancel
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCustomTypeDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingresar Motivo de Foto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ej. Daño en fachada, cableado roto...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSourceSelection() async {
    if (_galleryPhotos.length >= 12) {
      _showSnackbar('Límite de 12 fotos alcanzado.', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
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
        // Ask for Evidence Type FIRST
        String? selectedType;
        if (_evidenceTypes.isNotEmpty) {
           selectedType = await _showTypeSelectionDialog();
           if (selectedType == null && mounted) {
             // If user cancels, we might want to skip this photo or stop.
             continue; 
           }
           if (selectedType == '__OTRO__' && mounted) {
             selectedType = await _showCustomTypeDialog();
             if (selectedType == null || selectedType.trim().isEmpty) continue;
           }
        }
      
        final fileName = 'WM_${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
        final targetPath = '${appDir.path}/$fileName';
        
        // 1. Watermark Processing
        final watermarkedFile = await _addWatermark(File(pickedFile.path), targetPath);
        
        File finalFile = watermarkedFile;

        final localId = await _photoRepo.addPhoto(widget.orden.numeroOrden, finalFile.path, tipo: selectedType);
        if (mounted) {
          setState(() {
            _galleryPhotos.add(PhotoDisplay(localId: localId, path: finalFile.path, type: selectedType, status: PhotoStatusType.local));
          });
        }
      }
      // REMOVED: Immediate upload
      // UploadService.instance.syncPendingUploads();
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
        
        // Resize if too big (Max 1600px) to prevent upload errors
        if (image.width > 1600 || image.height > 1600) {
           image = img.copyResize(image, width: image.width > image.height ? 1600 : null, height: image.height > image.width ? 1600 : null);
        }

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

  Widget _buildFinalizeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _finalizeOrder,
        icon: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Icon(Icons.check),
        label: Text(_isLoading ? 'PROCESANDO...' : 'FINALIZAR ORDEN', style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10447E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
      ),
    );
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
                  
                  setState(() {
                    _articles.add({
                      'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
                      'articulo': selected, 
                      'grupo_articulo': selected,
                      'descripcion': descCtrl.text,
                      'asoc': asocCtrl.text,
                      'valor_unitario': val,
                      'cantidad': qty,
                      'total': qty * val
                    });
                    _onFieldChanged();
                  });
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
    if (_selectedSolution == null || _selectedSolution!.isEmpty) missingFields.add('Solución Técnico (Obligatorio)');
    
    // 2. Normal Flow Checks
    // Signatures
    if (_savedSignatureFile == null) missingFields.add('Firma del Técnico (Debe crearla)');
    if (_savedSubscriberSignatureFile == null) missingFields.add('Firma del Cliente');
        
        // Photos (Except 037)
        bool isPasswordChange = widget.orden.tipoOrden != null && widget.orden.tipoOrden!.contains('037');
        
        // Count only technician photos (they have 'WM_' in the file name or are local pending or have a type)
        int techPhotoCount = _galleryPhotos.where((p) {
          if (p.status == PhotoStatusType.local) return true;
          if (p.type != null && p.type!.isNotEmpty) return true;
          return p.url != null && p.url!.contains('WM_');
        }).length;
        
        if (techPhotoCount == 0 && !isPasswordChange) {
           missingFields.add('Al menos 1 foto propia como evidencia (las del panel admin no cuentan)');
        }
        
        // REMOVED: Blocking check for pending uploads. 
        // Background service manages uploads now.

    // SHOW DETAILED ERROR DIALOG
     // SHOW DETAILED ERROR DIALOG
     if (missingFields.isNotEmpty) {
        if (mounted) {
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Cerrar',
            barrierColor: Colors.black.withOpacity(0.5),
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
            transitionBuilder: (ctx, anim1, anim2, child) {
              return ScaleTransition(
                scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                child: FadeTransition(
                  opacity: anim1,
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: Colors.white,
                    elevation: 10,
                    contentPadding: EdgeInsets.zero,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: Colors.red.shade50,
                             borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                           ),
                           child: Column(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(12),
                                 decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                 child: const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange)
                               ).animate().shake(duration: 500.ms),
                               const SizedBox(height: 12),
                               const Text('Atención Requerida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                             ],
                           ),
                         ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Por favor complete los siguientes campos obligatorios:', style: TextStyle(color: Colors.black87, fontSize: 15)),
                              const SizedBox(height: 16),
                              ...missingFields.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 18, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(e, style: const TextStyle(fontWeight: FontWeight.w500))),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        return;
     }

    // Proceed to Close
    setState(() {
       _isLoading = true;
       _loadingMessage = 'Finalizando y Sincronizando...';
    });

    try {
      Uint8List? techSig;
      
      // Handle Technician Signature Logic
      if (_savedSignatureFile == null) {
         throw 'Falta la firma del técnico. Por favor cree o actualice su firma.';
      }
      techSig = await _savedSignatureFile!.readAsBytes();

      Uint8List? subSig;
      if (_savedSubscriberSignatureFile != null && await _savedSubscriberSignatureFile!.exists()) {
        subSig = await _savedSubscriberSignatureFile!.readAsBytes();
      }
      
      final closingData = {
        'celular': _celularController.text,
        'observaciones': _obsOrigenController.text,
        'solucion_tecnico': _selectedSolution?.split(', ').map((e) => e.trim()).toList(),
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
      await _clearDraft();
      
      // Artificial delay to ensure user sees the "Finishing" status and feels the "server process" time
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('¡Orden finalizada exitosamente!'), backgroundColor: Colors.green),
        // );
        // Navigator.of(context).popUntil((route) => route.isFirst);

        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.5),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
          transitionBuilder: (ctx, anim1, anim2, child) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
              child: FadeTransition(
                opacity: anim1,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: Colors.white,
                  elevation: 10,
                  contentPadding: EdgeInsets.zero,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            Container(
                               padding: const EdgeInsets.all(16),
                               decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                               child: const Icon(Icons.check_rounded, size: 48, color: Colors.green)
                            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                            const SizedBox(height: 16),
                            const Text('¡Orden Finalizada!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'La orden #${widget.orden.numeroOrden} se ha guardado y sincronizado correctamente con el servidor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 15, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).pop('refresh');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                child: const Text('Volver al Menú', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        if (mounted) _showSnackbar('Error de conexión. Por favor, asegúrate de estar conectado a Internet.', Colors.red);
      } else {
        if (mounted) _showSnackbar('Error: $e', Colors.red);
      }
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
          actions: const [
            ConnectionStatusIndicator(),
            SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: ProcessingOverlay(
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
                        if (widget.orden.cedula != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('C.C. ${widget.orden.cedula}', style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: widget.orden.cedula!));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cédula copiada al portapapeles')));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                    child: const Icon(Icons.copy, size: 14, color: Colors.white),
                                  ),
                                )
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(widget.orden.direccion ?? 'Sin Dirección', style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        _buildDeadlineWidget(),
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
                 _buildCard('Equipos Retirados', Icons.router, [
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
                     if (_savedSignatureFile != null)
                       Column(
                         children: [
                           Container(
                             height: 120,
                             width: double.infinity,
                             decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                             child: GestureDetector(
                               onTap: _showSignatureDialog,
                               child: Image.file(_savedSignatureFile!, fit: BoxFit.scaleDown, key: _signatureKey),
                             ),
                           ),
                           const SizedBox(height: 8),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               const Icon(Icons.check_circle, color: Colors.green, size: 16),
                               const SizedBox(width: 4),
                               const Text('Firma guardada', style: TextStyle(color: Colors.green)),
                               const SizedBox(width: 16),
                               TextButton.icon(
                                 onPressed: _showSignatureDialog,
                                 icon: const Icon(Icons.edit), 
                                 label: const Text('Actualizar Firma')
                               )
                             ],
                           )
                         ],
                       )
                     else
                       Center(
                         child: ElevatedButton.icon(
                           onPressed: _showSignatureDialog,
                           icon: const Icon(Icons.draw),
                           label: const Text('Crear Firma Digital'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.blue.shade50,
                             foregroundColor: Colors.blue,
                             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                           ),
                         ),
                       ),
                     
                     const SizedBox(height: 20),
                     const Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                     _buildSubscriberSignatureArea(),
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
                   _buildFinalizeButton(),
                 ]),
              ],
            ),
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

  Widget _buildSubscriberSignatureArea() {
    return Column(
      children: [
        if (_savedSubscriberSignatureFile != null)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8), color: Colors.white),
            child: Stack(
              children: [
                Center(
                  child: Image.file(_savedSubscriberSignatureFile!, fit: BoxFit.contain, key: ValueKey(_savedSubscriberSignatureFile!.path)),
                ),
                Positioned(
                  right: 4, top: 4,
                  child: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () async {
                      if (await _savedSubscriberSignatureFile!.exists()) {
                        await _savedSubscriberSignatureFile!.delete();
                      }
                      setState(() => _savedSubscriberSignatureFile = null);
                    },
                    tooltip: 'Borrar firma',
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: Text(_savedSubscriberSignatureFile != null ? 'Volver a Firmar' : 'Firmar (Pantalla Completa)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _savedSubscriberSignatureFile != null ? Colors.orange.shade50 : Colors.blue.shade50,
              foregroundColor: _savedSubscriberSignatureFile != null ? Colors.orange : Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _showFullscreenSignatureDialog(),
          ),
        ),
      ],
    );
  }

  void _showFullscreenSignatureDialog() {
    final ctrl = SignatureController(penStrokeWidth: 3);
    
    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                Signature(
                  controller: ctrl,
                  backgroundColor: Colors.white,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: FloatingActionButton.extended(
                    heroTag: 'cancel_sig',
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      _restoreOrientationAndPop(context);
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton.extended(
                    heroTag: 'clear_sig',
                    backgroundColor: Colors.orange,
                    icon: const Icon(Icons.clear, color: Colors.white),
                    label: const Text('Limpiar', style: TextStyle(color: Colors.white)),
                    onPressed: () => ctrl.clear(),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton.extended(
                    heroTag: 'save_sig',
                    backgroundColor: Colors.green,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Guardar Firma', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      if (ctrl.isNotEmpty) {
                        final bytes = await ctrl.toPngBytes();
                        if (bytes != null) {
                           final appDir = await getApplicationDocumentsDirectory();
                           final path = p.join(appDir.path, 'sub_sig_${widget.orden.numeroOrden}.png');
                           final file = File(path);
                           await file.writeAsBytes(bytes, flush: true);
                           setState(() {
                              _savedSubscriberSignatureFile = file;
                           });
                        }
                        _restoreOrientationAndPop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La firma no puede estar vacía'), backgroundColor: Colors.orange));
                      }
                    },
                  ),
                ),
                // "Firme Aquí" watermark
                const Center(
                  child: IgnorePointer(
                    child: Text(
                      'FIRME AQUÍ',
                      style: TextStyle(
                        color: Color(0x22000000), // Very light transparent black
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _restoreOrientationAndPop(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pop();
  }

  Widget _buildPhotoGallery() {
    // Only show technician photos (local or containing 'WM_' or having a type from DB/API)
    final techPhotos = _galleryPhotos.where((p) {
      if (p.status == PhotoStatusType.local) return true;
      if (p.type != null && p.type!.isNotEmpty) return true;
      return p.url != null && p.url!.contains('WM_');
    }).toList();

    return Column(
      children: [
         if (techPhotos.isEmpty) const Text('Sin fotos agregadas', style: TextStyle(color: Colors.grey)),
         if (techPhotos.isNotEmpty) SizedBox(
           height: 140, // Increased height for title
           child: ListView.builder(
             scrollDirection: Axis.horizontal,
             itemCount: techPhotos.length,
             itemBuilder: (ctx, i) {
               final photo = techPhotos[i];
               Widget imageWidget;
               bool hasLocalFile = photo.path.isNotEmpty && File(photo.path).existsSync();
               
               if (hasLocalFile) {
                 imageWidget = Image.file(File(photo.path), width: 100, height: 100, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                     width: 100, height: 100, color: Colors.grey[300], 
                     child: const Icon(Icons.image_not_supported, color: Colors.grey)
                   ),
                 );
               } else if (photo.url != null && photo.url!.isNotEmpty) {
                 imageWidget = Image.network(photo.url!, width: 100, height: 100, fit: BoxFit.cover,
                   errorBuilder: (context, error, stackTrace) => Container(
                     width: 100, height: 100, color: Colors.grey[300], 
                     child: const Icon(Icons.broken_image, color: Colors.grey)
                   ),
                 );
               } else {
                 imageWidget = Container(
                     width: 100, height: 100, color: Colors.grey[300], 
                     child: const Icon(Icons.image_not_supported, color: Colors.grey)
                 );
               }

               return Padding(
                 padding: const EdgeInsets.only(right: 12),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     // Type Title
                     if (photo.type != null)
                       Padding(
                         padding: const EdgeInsets.only(bottom: 4),
                         child: Text(
                           photo.type!,
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       
                     Stack(
                       children: [
                         GestureDetector(
                           onTap: () => _showPhotoDetail(photo),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: imageWidget,
                           ),
                         ),
                         
                         // Status Icons
                         if (photo.status == PhotoStatusType.uploading)
                           const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                         if (photo.status == PhotoStatusType.uploaded)
                           const Positioned(right: 0, top: 0, child: Icon(Icons.check_circle, color: Colors.green, size: 18)),
                           
                         // Delete Button (Always visible for local photos now that upload is delayed)
                         if (photo.status == PhotoStatusType.local)
                           Positioned(
                             right: -4,
                             top: -4,
                             child: GestureDetector(
                               onTap: () => _deletePhoto(photo),
                               child: Container(
                                 decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                 padding: const EdgeInsets.all(4),
                                 child: const Icon(Icons.close, color: Colors.white, size: 14),
                               ),
                             ),
                           ),
                       ],
                     ),
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
          onPressed: () => setState(() {
            _articles.remove(a);
            _onFieldChanged();
          })
        ),
      );
    }).toList());
  }

  Future<void> _deletePhoto(PhotoDisplay photo) async {
    final curStep = _isLoading; 
    if (curStep) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Foto'),
        content: const Text('¿Estás seguro de que quieres eliminar esta foto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (photo.localId != null) {
        await _photoRepo.deletePendingPhoto(photo.localId!);
      }
      setState(() {
        _galleryPhotos.remove(photo);
      });
    }
  }

  void _showPhotoDetail(PhotoDisplay photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
               child: Column(
                 children: [
                   if (photo.type != null)
                     Text(photo.type!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                   const SizedBox(height: 4),
                   Text(photo.status == PhotoStatusType.local ? 'Pendiente por subir' : 'Subida exitosamente', 
                     style: TextStyle(color: photo.status == PhotoStatusType.local ? Colors.orange : Colors.green, fontSize: 12)
                   ),
                 ],
               )
             ),
             Container(
               color: Colors.black,
               height: 400,
               child: InteractiveViewer(
                 child: (photo.path.isNotEmpty && File(photo.path).existsSync())
                  ? Image.file(File(photo.path))
                  : (photo.url != null && photo.url!.isNotEmpty) ? Image.network(photo.url!) : const Icon(Icons.broken_image, size: 50, color: Colors.white),
               ),
             ),
             Container(
               decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                   ),
                   if (photo.status == PhotoStatusType.local)
                     TextButton.icon(
                       onPressed: () {
                         Navigator.pop(context); // Close dialog first
                         _deletePhoto(photo);
                       },
                       icon: const Icon(Icons.delete, color: Colors.red),
                       label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                     ),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }

  void _showSolutionSelectionModal() {
    // Parse current selection into a list
    List<String> currentSelections = [];
    if (_selectedSolution != null && _selectedSolution!.isNotEmpty) {
       currentSelections = _selectedSolution!.split(', ').map((e) => e.trim()).toList();
    }
    
    // Sort options to match the ID order if possible or just values
    final options = Orden.solucionTecnicoOptions.values.toList();
    final allOptions = options;

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
                            currentSelections.add(option);
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
                       _onFieldChanged();
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
