import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/upload_service.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  static final SyncService instance = SyncService._init();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  
  // final ApiService _apiService = ApiService(); // Unused
  // final DatabaseService _dbService = DatabaseService.instance; // Unused for now
  
  // Stream dummy for compatibility if needed elsewhere (though we removed listeners)
  final _pendingOperationsController = StreamController<String>.broadcast();
  Stream<String> get pendingOperationsStream => _pendingOperationsController.stream;

  SyncService._init();

  void start() {
     _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
       if (result.contains(ConnectivityResult.mobile) || 
           result.contains(ConnectivityResult.wifi)) {
         debugPrint("Conexión detectada. Modo Online.");
       }
     });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingOperationsController.close();
  }
  
  void notifyPendingOperationChange(String orderNumber) {
    // No-op
  }

  Future<void> sync() async {
    // Online-only mode: Sync is disabled.
    debugPrint("Sincronización desactivada (Modo 100% Online).");
    await UploadService.instance.syncPendingUploads(); // Still sync photos if needed
  }

  // Legacy methods removed or stubbed
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus.idle;
  }

  Future<int> getPendingOperationsCount() async {
    return 0;
  }
}

