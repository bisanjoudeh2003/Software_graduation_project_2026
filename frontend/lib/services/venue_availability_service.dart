import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class VenueAvailabilityService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/venue-availability";
    }
    return "http://10.0.2.2:3000/api/venue-availability";
  }

  static Future<void> addAvailability(
    int venueId,
    String date,
    String startTime,
    String endTime,
  ) async {
    String? token = await AuthService.getToken();

    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "venue_id": venueId,
        "date": date,
        "start_time": startTime,
        "end_time": endTime,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Time slot conflict. Please choose another time.");
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailability(int venueId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/$venueId"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data);
    }

    throw Exception("Failed to load availability: ${res.body}");
  }

  static Future<void> deleteAvailability(int id) async {
    String? token = await AuthService.getToken();

    final res = await http.delete(
      Uri.parse("$baseUrl/$id"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Delete failed");
    }
  }

  static Future<void> updateAvailability(
    int id,
    String startTime,
    String endTime,
  ) async {
    String? token = await AuthService.getToken();

    final res = await http.put(
      Uri.parse("$baseUrl/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "start_time": startTime,
        "end_time": endTime,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Update failed");
    }
  }

  static Future<Map<String, dynamic>?> bulkAddAvailability({
    required int venueId,
    required String startDate,
    required String endDate,
    required List<int> daysOfWeek,
    required String startTime,
    required String endTime,
    List<String> exceptions = const [],
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final res = await http.post(
      Uri.parse("$baseUrl/bulk"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "venue_id": venueId,
        "start_date": startDate,
        "end_date": endDate,
        "days_of_week": daysOfWeek,
        "start_time": startTime,
        "end_time": endTime,
        "exceptions": exceptions,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Bulk add failed: ${res.body}");
    }
  }
}