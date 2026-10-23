import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/orden_model.dart';
import '../models/user_model.dart';

// Top-level function for background JSON parsing
dynamic _decodeJsonIsolate(String source) => jsonDecode(source);

class ApiService {
  static const String _baseUrlDomain = 'https://ordenes.intalnet.com';
  static const String baseUrl = '$_baseUrlDomain/api';
  static const String domain = _baseUrlDomain;
  static const Duration defaultTimeout = Duration(seconds: 10);

  String getBaseUrl() => baseUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  Future<bool> checkApiStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/v1/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e, stack) {
      debugPrint("Fallo en la verificación de la API: $e");
      debugPrint("Stack trace: $stack");
      return false;
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    final token = await AuthService.instance.getToken();
    if (token == null) return;
    final response = await http.post(
      Uri.parse('$baseUrl/v1/update-fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcm_token': fcmToken}),
    ).timeout(defaultTimeout);
    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getOrders({
    int page = 1,
    int perPage = 50,
    String status = 'todas',
    String? search,
    String? barrio,
  }) async {
    final token = await AuthService.instance.getToken();
    String url = '$baseUrl/v1/orders?page=$page&per_page=$perPage&status=$status';
    if (search != null && search.isNotEmpty) {
      url += '&search=$search';
    }
    if (barrio != null && barrio.isNotEmpty) {
      url += '&barrio=$barrio';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }



  Future<int> getPendingCount() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/count-pending'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    final data = await _handleResponse(response);
    return data['count'] as int;
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<Orden> getOrderDetails(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/$orderNumber'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) {
      if (data.containsKey('order')) return Orden.fromJson(data['order']);
      if (data.containsKey('data')) return Orden.fromJson(data['data']);
    }
    return Orden.fromJson(data);
  }

  // CAMBIO: Acepta un String en lugar de un int y datos opcionales (como fecha offline)
  Future<Orden> acceptOrder(String orderNumber, {Map<String, dynamic>? data}) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/accept'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: data != null ? jsonEncode(data) : null,
    ).timeout(defaultTimeout);
    final responseData = await _handleResponse(response);
    return Orden.fromJson(responseData['order']);
  }

  Future<Orden> cancelStartOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/cancel-start'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      },
    ).timeout(defaultTimeout);
    final responseData = await _handleResponse(response);
    return Orden.fromJson(responseData['order']);
  }

  // CAMBIO: Nuevo método para reportar en sitio con datos opcionales
  Future<Orden> reportOnSite(String orderNumber, {Map<String, dynamic>? data}) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/report-on-site'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: data != null ? jsonEncode(data) : null,
    ).timeout(defaultTimeout);
    final responseData = await _handleResponse(response);
    return Orden.fromJson(responseData['order']);
  }
  
  // CAMBIO: Acepta un String en lugar de un int y datos de cierre
  Future<Orden> closeOrder(String orderNumber, Map<String, dynamic> data) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/close'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(data),
    ).timeout(defaultTimeout);
    final responseData = await _handleResponse(response);
    return Orden.fromJson(responseData['order']);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<Map<String, dynamic>> rejectOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reject'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> reassignOrder(String orderNumber, String motivo) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reassign'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'motivo': motivo}),
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> rescheduleOrder(String orderNumber, String motivo) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reschedule'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'motivo': motivo}),
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<void> updateDetails(String orderNumber, Map<String, dynamic> data) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/update-details'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    ).timeout(defaultTimeout);
    await _handleResponse(response);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<List<dynamic>> getUploadedPhotos(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/photos'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as List<dynamic>;
    }
    return data as List<dynamic>;
  }

  Future<List<String>> getBarrios() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/barrios'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    final data = await _handleResponse(response);
    return List<String>.from(data);
  }

  Future<List<String>> getEvidenceTypes() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/evidence-types'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    final data = await _handleResponse(response);
    return List<String>.from(data);
  }

  Future<List<Map<String, dynamic>>> getAuxiliaryTechnicians([String? orderNumber]) async {
    try {
      final token = await AuthService.instance.getToken();
      final url = (orderNumber != null && orderNumber.isNotEmpty)
          ? '$baseUrl/v1/orders/$orderNumber/auxiliary-technicians'
          : '$baseUrl/v1/auxiliary-technicians';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(defaultTimeout);
      final data = await _handleResponse(response);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo técnicos auxiliares: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getPendingOrders({int page = 1, String? barrio}) async {
    final token = await AuthService.instance.getToken();
    String url = '$baseUrl/v1/pending-orders?page=$page';
    if (barrio != null && barrio.isNotEmpty) {
      url += '&barrio=$barrio';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  Future<void> claimOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/claim'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getRankings() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/rankings'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    dynamic body;
    if (response.body.length > 20480) {
      body = await compute(_decodeJsonIsolate, response.body);
    } else {
      body = jsonDecode(response.body);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body is Map ? (body['message'] ?? 'Ocurrió un error') : 'Ocurrió un error');
    }
  }
  Future<Map<String, dynamic>> getProfile() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/profile'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(defaultTimeout);
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateSignature(File signatureFile) async {
    final token = await AuthService.instance.getToken();
    final uri = Uri.parse('$baseUrl/v1/profile/signature');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('signature', signatureFile.path));
      
    final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
    final responseBody = await streamedResponse.stream.bytesToString();
    
    if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
      return jsonDecode(responseBody);
    } else {
       final body = jsonDecode(responseBody);
       throw Exception(body['message'] ?? 'Error updating signature');
    }
  }

  Future<void> sendLocation(double latitude, double longitude, {double? speed, int? batteryLevel, String? deviceId, String? deviceModel}) async {
    final token = await AuthService.instance.getToken();
    if (token == null) return;

    final response = await http.post(
      Uri.parse('$baseUrl/v1/location'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (speed != null) 'speed': speed,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceModel != null) 'device_model': deviceModel,
      }),
    ).timeout(defaultTimeout);
    await _handleResponse(response);
  }
}
