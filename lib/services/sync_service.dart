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
  Timer? _debounceTimer;
  bool _isSyncing = false;
  
  final _pendingOperationsController = StreamController<String>.broadcast();
  Stream<String> get pendingOperationsStream => _pendingOperationsController.stream;

  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  SyncService._init() {
    // Initial count update
    _updatePendingCount();
  }

  void _updatePendingCount() async {
    try {
      final count = await getPendingOperationsCount();
      _pendingCountController.add(count);
    } catch (e) {
      debugPrint("Error updating pending count: $e");
    }
  }

  void start() {
     Future.delayed(const Duration(seconds: 3), () {
       _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
         if (result.contains(ConnectivityResult.mobile) || 
             result.contains(ConnectivityResult.wifi) ||
             result.contains(ConnectivityResult.ethernet)) {
           if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
           _debounceTimer = Timer(const Duration(seconds: 3), () {
             debugPrint("Conexión detectada. Modo Online.");
             sync();
           });
         }
       });
     });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    _pendingOperationsController.close();
    _pendingCountController.close();
  }
  
  void notifyPendingOperationChange(String orderNumber) {
    _pendingOperationsController.add(orderNumber);
    _updatePendingCount();
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _updatePendingCount(); // Start syncing pulse
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.mobile) && 
          !connectivityResult.contains(ConnectivityResult.wifi) &&
          !connectivityResult.contains(ConnectivityResult.ethernet)) {
        return;
      }
      
      debugPrint("Iniciando sincronización...");
      
      final dbService = DatabaseService.instance;
      final apiService = ApiService();
      
      final pendingOps = await dbService.getPendingOperations();
      for (var op in pendingOps) {
        final id = op['id'] as int;
        final type = op['operation_type'] as String;
        final orderNumber = op['order_number'] as String;
        final dataStr = op['operation_data'] as String;
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        
        try {
          switch (type) {
            case 'accept':
              await apiService.acceptOrder(orderNumber, data: data);
              break;
            case 'cancelStart':
              await apiService.cancelStartOrder(orderNumber);
              break;
            case 'reportOnSite':
              await apiService.reportOnSite(orderNumber, data: data);
              break;
            case 'close':
              await apiService.closeOrder(orderNumber, data);
              break;
            case 'reject':
              await apiService.rejectOrder(orderNumber);
              break;
            case 'reassign':
              await apiService.reassignOrder(orderNumber, data['motivo'] ?? '');
              break;
            case 'reschedule':
              await apiService.rescheduleOrder(orderNumber, data['motivo'] ?? '');
              break;
            case 'updateDetails':
              await apiService.updateDetails(orderNumber, Map<String, dynamic>.from(data));
              break;
          }
          await dbService.deletePendingOperation(id);
          notifyPendingOperationChange(orderNumber);
        } catch (e) {
          debugPrint("Error syncing operation $id for order $orderNumber: $e");
          await dbService.incrementRetryCount(id, e.toString());
        }
      }

      await UploadService.instance.syncPendingUploads();
    } finally {
      _isSyncing = false;
      _updatePendingCount(); // Final count update
    }
  }

  Future<SyncStatus> getSyncStatus() async {
    return _isSyncing ? SyncStatus.syncing : SyncStatus.idle;
  }

  Future<int> getPendingOperationsCount() async {
    return await DatabaseService.instance.getPendingOperationsCount();
  }
}

