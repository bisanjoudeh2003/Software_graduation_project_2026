import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class BookingService {
  static String get baseUrl => AuthService.apiBase;

  static Future<Map<String, dynamic>?> createBooking({
    required int venueId,
    required int availabilityId,
    required String bookingDate,
    required String startTime,
    required String endTime,
    required double totalPrice,
    String? notes,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final res = await http.post(
      Uri.parse("$baseUrl/bookings"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "venue_id": venueId,
        "availability_id": availabilityId,
        "booking_date": bookingDate,
        "start_time": startTime,
        "end_time": endTime,
        "total_price": totalPrice,
        "notes": notes,
      }),
    );

    print("CREATE BOOKING STATUS: ${res.statusCode}");
    print("CREATE BOOKING BODY: ${res.body}");

    if (res.statusCode == 200) return jsonDecode(res.body);

    final body = jsonDecode(res.body);
    throw Exception(body["error"] ?? body["message"] ?? "Booking failed");
  }

  static Future<List> getClientBookings() async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse("$baseUrl/bookings/client"),
      headers: {"Authorization": "Bearer $token"},
    );

    print("GET CLIENT BOOKINGS STATUS: ${res.statusCode}");
    print("GET CLIENT BOOKINGS BODY: ${res.body}");

    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<List> getOwnerBookings() async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse("$baseUrl/bookings/owner"),
      headers: {"Authorization": "Bearer $token"},
    );

    print("GET OWNER BOOKINGS STATUS: ${res.statusCode}");
    print("GET OWNER BOOKINGS BODY: ${res.body}");

    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<bool> updateStatus(int bookingId, String status) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.put(
      Uri.parse("$baseUrl/bookings/$bookingId/status"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"status": status}),
    );

    return res.statusCode == 200;
  }

  static Future<bool> cancelBooking(int bookingId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.put(
      Uri.parse("$baseUrl/bookings/$bookingId/cancel"),
      headers: {"Authorization": "Bearer $token"},
    );

    print("CANCEL BOOKING STATUS: ${res.statusCode}");
    print("CANCEL BOOKING BODY: ${res.body}");

    return res.statusCode == 200;
  }

  static Future<bool> payDeposit(int bookingId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.put(
      Uri.parse("$baseUrl/bookings/$bookingId/pay-deposit"),
      headers: {"Authorization": "Bearer $token"},
    );

    return res.statusCode == 200;
  }

  static Future<bool> markAsCompleted(int bookingId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.put(
      Uri.parse("$baseUrl/bookings/$bookingId/complete"),
      headers: {"Authorization": "Bearer $token"},
    );

    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> ownerCancelBooking(int bookingId) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final res = await http.put(
      Uri.parse("$baseUrl/bookings/$bookingId/owner-cancel"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<int> getUnseenCount() async {
    final token = await AuthService.getToken();
    if (token == null) return 0;

    final res = await http.get(
      Uri.parse("$baseUrl/bookings/unseen-count"),
      headers: {"Authorization": "Bearer $token"},
    );

    print("=== UNSEEN COUNT STATUS: ${res.statusCode}");
    print("=== UNSEEN COUNT BODY: ${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["count"] ?? 0;
    }
    return 0;
  }

  static Future<void> markBookingsSeen() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    await http.put(
      Uri.parse("$baseUrl/bookings/mark-seen"),
      headers: {"Authorization": "Bearer $token"},
    );
  }
}