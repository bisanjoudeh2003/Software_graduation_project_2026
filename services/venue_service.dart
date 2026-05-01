
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class VenueService {

static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }
  
  static Future<List<dynamic>> getOwnerVenues(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/venues/owner"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception("Failed to load venues");
  }

  static Future deleteVenue(String token, int venueId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/venues/$venueId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) throw Exception("Failed to delete venue");
  }

  static Future getVenueDetails(int venueId) async {
    final res = await http.get(Uri.parse("$baseUrl/venues/$venueId"));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception("Failed to load venue");
  }

  static Future searchVenues(String token, String query) async {
    final res = await http.get(
      Uri.parse("$baseUrl/venues/search?q=$query"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception("Search failed");
  }

  static Future updateVenue(
    String token,
    int venueId,
    String name,
    String description,
    String location,
    double latitude,
    double longitude,
    String price,
  ) async {
    final res = await http.put(
      Uri.parse("$baseUrl/venues/$venueId"),   // ✅ مصلّح
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "description": description,
        "location": location,
        "latitude": latitude,
        "longitude": longitude,
        "price_per_hour": price,
      }),
    );

    if (res.statusCode != 200) {
      // بيعرض الخطأ الفعلي من السيرفر
      final body = jsonDecode(res.body);
      throw Exception(body["message"] ?? "Failed to update venue");
    }
  }

  static Future<List> getVenueImages(int venueId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/venues/$venueId/images"),  // ✅ مصلّح
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<List> getAllVenues() async {

final res = await http.get(
  Uri.parse("$baseUrl/venues"),
);

if(res.statusCode == 200){
  return jsonDecode(res.body);
}

throw Exception("Failed to load venues");

}
static Future deleteReview(String token, int reviewId) async {
  final res = await http.delete(
    Uri.parse("$baseUrl/reviews/$reviewId"),
    headers: {"Authorization": "Bearer $token"},
  );
  if (res.statusCode != 200) throw Exception("Failed to delete review");
}

  static Future<List<dynamic>> getNearbyVenues({
    required double lat,
    required double lng,
  }) async {
    final token = await AuthService.getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/venues/nearby?lat=$lat&lng=$lng"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["venues"] ?? [];
    }

    throw Exception("Failed to load nearby venues");
  }
}