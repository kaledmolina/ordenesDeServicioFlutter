import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureScreen extends StatefulWidget {
  final String orderNumber;

  const SignatureScreen({super.key, required this.orderNumber});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final SignatureController _technicianController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final SignatureController _subscriberController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _technicianController.dispose();
    _subscriberController.dispose();
    super.dispose();
  }

  Future<void> _exportSignatures() async {
    if (_technicianController.isEmpty || _subscriberController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambas firmas son obligatorias')),
      );
      return;
    }

    final Uint8List? techSignature = await _technicianController.toPngBytes();
    final Uint8List? subSignature = await _subscriberController.toPngBytes();

    if (techSignature != null && subSignature != null) {
      if (mounted) {
        Navigator.pop(context, {
          'technician': techSignature,
          'subscriber': subSignature,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firmas Orden #${widget.orderNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSignaturePad(
              controller: _technicianController,
              label: 'Firma del Técnico',
            ),
            const SizedBox(height: 24),
            _buildSignaturePad(
              controller: _subscriberController,
              label: 'Firma del Suscriptor',
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _exportSignatures,
              icon: const Icon(Icons.check_circle_outline, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Confirmar Firmas', style: TextStyle(fontSize: 18)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturePad({
    required SignatureController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: controller,
              height: 200,
              backgroundColor: Colors.grey[200]!,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => controller.clear(),
            icon: const Icon(Icons.clear, color: Colors.red),
            label: const Text('Limpiar', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
