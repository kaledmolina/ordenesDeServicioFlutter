import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/orden_model.dart';
import '../models/user_model.dart';

class ApiService {
  static const String _baseUrlDomain = 'https://ordenes.intalnet.com';
  static const String baseUrl = '$_baseUrlDomain/api';
  static const String domain = _baseUrlDomain;

  String getBaseUrl() => baseUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
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
    );
    _handleResponse(response);
  }

  Future<Map<String, dynamic>> getOrders({int page = 1, String status = 'todas', String? search, String? barrio}) async {
    final token = await AuthService.instance.getToken();
    String url = '$baseUrl/v1/orders?page=$page&status=$status';
    if (search != null && search.isNotEmpty) {
      url += '&search=$search';
    }
    if (barrio != null && barrio.isNotEmpty) {
      url += '&barrio=$barrio';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }



  Future<int> getPendingCount() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/count-pending'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return data['count'] as int;
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<Orden> getOrderDetails(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/$orderNumber'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    if (data is Map<String, dynamic> && data.containsKey('order')) {
      return Orden.fromJson(data['order']);
    }
    return Orden.fromJson(data);
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<Orden> acceptOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/accept'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return Orden.fromJson(data['order']);
  }

  // CAMBIO: Nuevo método para reportar en sitio
  Future<Orden> reportOnSite(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/report-on-site'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return Orden.fromJson(data['order']);
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
    );
    final responseData = _handleResponse(response);
    return Orden.fromJson(responseData['order']);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<Map<String, dynamic>> rejectOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reject'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> reassignOrder(String orderNumber, String motivo) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reassign'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'motivo': motivo}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> rescheduleOrder(String orderNumber, String motivo) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reschedule'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'motivo': motivo}),
    );
    return _handleResponse(response);
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
    );
    _handleResponse(response);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<List<dynamic>> getUploadedPhotos(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/photos'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
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
    );
    final data = _handleResponse(response);
    return List<String>.from(data);
  }

  Future<List<String>> getEvidenceTypes() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/evidence-types'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return List<String>.from(data);
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
    );
    return _handleResponse(response);
  }

  Future<void> claimOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/claim'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    _handleResponse(response);
  }

  Future<Map<String, dynamic>> getRankings() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/rankings'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer \$token'},
    );
    return _handleResponse(response);
  }



  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'Ocurrió un error');
    }
  }
  Future<Map<String, dynamic>> getProfile() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/profile'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateSignature(File signatureFile) async {
    final token = await AuthService.instance.getToken();
    final uri = Uri.parse('$baseUrl/v1/profile/signature');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('signature', signatureFile.path));
      
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody);
    } else {
       final body = jsonDecode(responseBody);
       throw Exception(body['message'] ?? 'Error updating signature');
    }
  }
}
