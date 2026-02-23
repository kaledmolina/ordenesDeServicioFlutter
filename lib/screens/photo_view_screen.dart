import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_status_model.dart';
import '../services/api_service.dart';

class PhotoViewScreen extends StatelessWidget {
  final PhotoDisplay photo;
  final String? authToken;

  const PhotoViewScreen({super.key, required this.photo, this.authToken});

  @override
  Widget build(BuildContext context) {
    Widget image;
    // Use URL if available (handled by repository), else local file
    if (photo.url != null && photo.url!.isNotEmpty) {
      image = Image.network(
        photo.url!,
        headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        loadingBuilder: (context, child, loadingProgress) {
           if (loadingProgress == null) return child;
           return Center(child: CircularProgressIndicator(
             value: loadingProgress.expectedTotalBytes != null
                 ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                 : null
           ));
        },
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
      );
    } else {
      image = Image.file(
        File(photo.path),
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported, color: Colors.white)),
      );
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

