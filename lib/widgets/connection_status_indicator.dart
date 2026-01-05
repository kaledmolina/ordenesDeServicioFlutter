import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../services/sync_service.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() => _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> {
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _checkConnection();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
    if (mounted && _isOnline != isOnline) {
      setState(() => _isOnline = isOnline);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('Sin conexión', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text('En Línea', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

