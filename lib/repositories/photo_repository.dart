import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/photo_status_model.dart';
import '../services/auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PhotoRepository {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<PhotoDisplay>> getPhotos(String orderNumber) async {
    final hasConnection = await _hasConnection();
    final List<PhotoDisplay> photos = [];

    if (hasConnection) {
      try {
        final uploaded = await _apiService.getUploadedPhotos(orderNumber);
        
        // Cache remotely fetched photos
        await _cacheRemotePhotos(orderNumber, uploaded);
        
        photos.addAll(uploaded.map((p) => PhotoDisplay(
          remoteId: p['id'],
          path: p['path'],
          url: p['url'],
          type: p['tipo'] ?? p['evidence_type'], // Try to get type from API response
          status: PhotoStatusType.uploaded,
        )));
      } catch (e) {
        // If API fails, try loading from cache
        photos.addAll(await _getCachedRemotePhotos(orderNumber));
      }
    } else {
        // If offline, load from cache
        photos.addAll(await _getCachedRemotePhotos(orderNumber));
    }

    // Obtener fotos pendientes desde DB local
    final pending = await _dbService.getPendingPhotosForOrder(orderNumber);
    photos.addAll(pending.map((p) => PhotoDisplay(
      localId: p['id'] as int,
      path: p['image_path'] as String,
      type: p['tipo'] as String?,
      status: PhotoStatusType.local,
    )));

    return photos;
  }

  Future<int> addPhoto(String orderNumber, String imagePath, {String? tipo}) async {
    return await _dbService.addPendingPhoto(orderNumber, imagePath, tipo: tipo);
  }

  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    return await _dbService.getPendingPhotos();
  }

  Future<List<Map<String, dynamic>>> getPendingPhotosForOrder(String orderNumber) async {
    return await _dbService.getPendingPhotosForOrder(orderNumber);
  }

  Future<void> deletePendingPhoto(int id) async {
    await _dbService.deletePendingPhoto(id);
  }

  Future<bool> _hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  // Caching Methods
  Future<void> _cacheRemotePhotos(String orderNumber, List<dynamic> uploadedPhotos) async {
    try {
      final token = await AuthService.instance.getToken();
      final prefs = await SharedPreferences.getInstance();
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/cached_remote_photos');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      List<Map<String, dynamic>> cachedData = [];

      for (var p in uploadedPhotos) {
        if (p['url'] == null || p['id'] == null) continue;
        
        final localPath = '${cacheDir.path}/remote_${p['id']}.jpg';
        final file = File(localPath);
        
        // Download if it doesn't exist locally
        if (!await file.exists()) {
          try {
            final response = await http.get(
              Uri.parse(p['url']),
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            );
            if (response.statusCode == 200) {
              await file.writeAsBytes(response.bodyBytes);
            } else {
              debugPrint('Error caching photo ${p['id']}: ${response.statusCode}');
            }
          } catch(e) {
            debugPrint('Exception caching photo ${p['id']}: $e');
            // ignore download errors, will just try again next time
          }
        }
        
        cachedData.add({
          'id': p['id'],
          'local_path': localPath,
          'url': p['url'],
          'tipo': p['tipo'] ?? p['evidence_type']
        });
      }
      
      await prefs.setString('cached_photos_$orderNumber', jsonEncode(cachedData));
    } catch(e) {
       // ignore caching errors to prevent breaking the flow
    }
  }

  Future<List<PhotoDisplay>> _getCachedRemotePhotos(String orderNumber) async {
    List<PhotoDisplay> cachedPhotos = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('cached_photos_$orderNumber');
      if (dataStr != null) {
        final List<dynamic> data = jsonDecode(dataStr);
        for (var p in data) {
           final localPath = p['local_path'] as String;
           final file = File(localPath);
           if (await file.exists()) {
              cachedPhotos.add(PhotoDisplay(
                remoteId: p['id'],
                path: localPath, // use local path because it's offline
                url: p['url'],   // keep URL for reference
                type: p['tipo'],
                status: PhotoStatusType.uploaded // mark as uploaded so UI handles it normally
              ));
           }
        }
      }
    } catch(e) {
        // ignore
    }
    return cachedPhotos;
  }
}

