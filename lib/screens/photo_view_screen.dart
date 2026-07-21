import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/photo_status_model.dart';
import '../services/api_service.dart';

class PhotoViewScreen extends StatelessWidget {
  final PhotoDisplay photo;
  final String? authToken;

  const PhotoViewScreen({super.key, required this.photo, this.authToken});

  @override
  Widget build(BuildContext context) {
    Widget image;
    // Prioritize local file if it exists, otherwise use network URL
    if (photo.path.isNotEmpty && File(photo.path).existsSync()) {
      image = Image.file(
        File(photo.path),
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported, color: Colors.white)),
      );
    } else if (photo.url != null && photo.url!.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: photo.url!,
        httpHeaders: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
        fit: BoxFit.contain,
      );
    } else {
      image = const Center(child: Icon(Icons.broken_image, color: Colors.white));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: image,
        ),
      ),
    );
  }
}

