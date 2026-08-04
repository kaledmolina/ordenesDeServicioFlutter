import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'auth_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  static LocationService get instance => _instance;

  LocationService._internal();

  Timer? _timer;
  bool _isTracking = false;
  final ApiService _apiService = ApiService();

  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Los servicios de ubicación están desactivados.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permiso de ubicación denegado.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permisos de ubicación denegados permanentemente.');
      return false;
    }

    return true;
  }

  void startTracking({Duration interval = const Duration(minutes: 5)}) async {
    if (_isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _isTracking = true;
    debugPrint('Iniciando rastreo de ubicación en tiempo real...');

    // Send immediately once
    _updateCurrentLocation();

    // Schedule periodic update
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      _updateCurrentLocation();
    });
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _isTracking = false;
    debugPrint('Rastreo de ubicación detenido.');
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final isLoggedIn = await AuthService.instance.isLoggedIn();
      if (!isLoggedIn) {
        stopTracking();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      await _apiService.sendLocation(
        position.latitude,
        position.longitude,
        speed: position.speed >= 0 ? position.speed : null,
      );

      debugPrint('Ubicación enviada: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error enviando ubicación: $e');
    }
  }
}
