import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  static LocationService get instance => _instance;

  LocationService._internal();

  Timer? _timer;
  bool _isTracking = false;
  final ApiService _apiService = ApiService();

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('unique_device_id');
    if (deviceId == null) {
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('unique_device_id', deviceId);
    }
    return deviceId;
  }

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

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint('getCurrentPosition fallo/timeout, buscando última posición conocida: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint('No se pudo obtener posición GPS actual ni última conocida.');
        return;
      }

      final deviceId = await _getDeviceId();
      final deviceModel = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Móvil');

      await _apiService.sendLocation(
        position.latitude,
        position.longitude,
        speed: position.speed >= 0 ? position.speed : null,
        deviceId: deviceId,
        deviceModel: deviceModel,
      );

      debugPrint('Ubicación enviada: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error enviando ubicación: $e');
    }
  }
}
