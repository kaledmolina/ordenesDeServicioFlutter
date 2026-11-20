import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

/// Aplica la marca de agua de Intalnet con fecha y hora a una foto y la guarda
/// en [args] `targetPath`. Corre en un isolate aparte (`compute`), por eso recibe
/// y devuelve tipos simples.
///
/// Devuelve la ruta del archivo resultante. Si algo falla, copia el original tal cual.
Future<String> processImageWithWatermarkInIsolate(Map<String, String> args) async {
  final originalPath = args['originalPath']!;
  final targetPath = args['targetPath']!;

  try {
    final originalFile = File(originalPath);
    final bytes = await originalFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image != null) {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
      final text = 'Intalnet - $dateStr';

      if (image.width > 1600 || image.height > 1600) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 1600 : null,
          height: image.height > image.width ? 1600 : null,
        );
      }

      img.drawString(
        image,
        text,
        font: img.arial24,
        x: 20,
        y: 20,
        color: img.ColorRgb8(255, 165, 0), // Orange/Gold
      );

      final encoded = img.encodeJpg(image, quality: 80);
      final file = File(targetPath);
      await file.writeAsBytes(encoded);
      return targetPath;
    }

    await originalFile.copy(targetPath);
    return targetPath;
  } catch (e) {
    debugPrint('Error adding watermark in isolate: $e');
    final originalFile = File(originalPath);
    await originalFile.copy(targetPath);
    return targetPath;
  }
}
