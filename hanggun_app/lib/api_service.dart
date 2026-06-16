import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://hanggun-backend-production.up.railway.app';

  static Future<List<dynamic>> getCarpools() async {
    final response = await http.get(
      Uri.parse('$baseUrl/carpools'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('카풀 목록 불러오기 실패');
  }

  static Future<void> createCarpool({
    required String departure,
    required String destination,
    required String time,
    required int maxSeats,
    double? departureLat,
    double? departureLon,
    double? destinationLat,
    double? destinationLon,
    String? driverName,
    String? driverPhone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/carpools'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'departure': departure,
        'destination': destination,
        'time': time,
        'max_seats': maxSeats,
        'departure_lat': departureLat,
        'departure_lon': departureLon,
        'destination_lat': destinationLat,
        'destination_lon': destinationLon,
        'driver_name': driverName,
        'driver_phone': driverPhone,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('카풀 등록 실패: ${response.body}');
    }
  }

  static Future<void> joinCarpool({
    required int carpoolId,
    required String riderName,
    required String riderPhone,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLon,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/carpools/$carpoolId/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'pickup_location': pickupLocation,
        'pickup_lat': pickupLat,
        'pickup_lon': pickupLon,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('탑승 신청 실패: ${response.body}');
    }
  }

  static Future<List<dynamic>> getRideRequests(int carpoolId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/carpools/$carpoolId/requests'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('신청자 목록 조회 실패: ${response.body}');
  }

  static Future<void> approveRequest(int requestId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests/$requestId/approve'),
    );

    if (response.statusCode != 200) {
      throw Exception('승인 실패: ${response.body}');
    }
  }

  static Future<void> rejectRequest(int requestId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests/$requestId/reject'),
    );

    if (response.statusCode != 200) {
      throw Exception('거절 실패: ${response.body}');
    }
  }

  static Future<List<dynamic>> searchPlace(String keyword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tmap/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'keyword': keyword,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return data['results'];
      }
    }

    throw Exception('장소 검색 실패: ${response.body}');
  }

  static Future<String> askAi(String question) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'];
    }

    throw Exception('AI 응답 실패: ${response.body}');
  }
}