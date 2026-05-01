import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class PhotographerBookingServiceForClient {
static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }
  static Future<Map<String, dynamic>> createBooking({
    required int photographerId,
    required String sessionType,
    required String date,
    required String time,
    required double durationHours,
    String? location,
    int? venueId,
    String? note,
  }) async {
    final token = await AuthService.getToken();

    final body = {
      'photographer_id': photographerId,
      'session_type': sessionType,
      'date': date,
      'time': time,
      'duration_hours': durationHours,
      if (venueId != null) 'venue_id': venueId,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final res = await http.post(
      Uri.parse('$baseUrl/ph-bookings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body);

    return {
      'statusCode': res.statusCode,
      'data': data,
    };
  }

  static Future<List<dynamic>> getMyPhotographerBookings() async {
    final token = await AuthService.getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/ph-bookings/client'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      if (data is List) return data;
      if (data is Map && data['bookings'] is List) {
        return data['bookings'];
      }
      return [];
    }

    throw Exception(data['message'] ?? 'Failed to load photographer bookings');
  }

  static Future<dynamic> getPhotographerBookingDetails(int bookingId) async {
    final token = await AuthService.getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/ph-bookings/$bookingId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to load photographer booking details',
    );
  }

  static Future<Map<String, dynamic>> payDeposit(int bookingId) async {
    final token = await AuthService.getToken();

    final res = await http.patch(
      Uri.parse('$baseUrl/ph-bookings/$bookingId/pay-deposit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(res.body);

    return {
      'statusCode': res.statusCode,
      'data': data,
    };
  }

  static Future<void> cancelPhotographerBooking(
    int bookingId, {
    String? cancellationReason,
  }) async {
    final token = await AuthService.getToken();

    final res = await http.patch(
      Uri.parse('$baseUrl/ph-bookings/$bookingId/cancel'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'cancellation_reason': cancellationReason ?? '',
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to cancel photographer booking',
      );
    }
  }
}