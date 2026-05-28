import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PhotographerService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    } else {
      return "http://10.0.2.2:3000/api";
    }
  }

  static bool _isVisiblePhotographer(dynamic photographer) {
    if (photographer == null) return false;

    final visibility = photographer["admin_visibility"]
            ?.toString()
            .toLowerCase()
            .trim() ??
        "visible";

    final accountStatus = photographer["account_status"]
            ?.toString()
            .toLowerCase()
            .trim() ??
        photographer["status"]?.toString().toLowerCase().trim() ??
        "active";

    final userStatus = photographer["user_status"]
            ?.toString()
            .toLowerCase()
            .trim() ??
        "active";

    final isHidden = visibility == "hidden";
    final isBlocked = accountStatus == "blocked" ||
        accountStatus == "inactive" ||
        accountStatus == "deactivated" ||
        userStatus == "blocked" ||
        userStatus == "inactive" ||
        userStatus == "deactivated";

    return !isHidden && !isBlocked;
  }

  static List<dynamic> _filterVisiblePhotographers(List<dynamic> list) {
    return list.where(_isVisiblePhotographer).toList();
  }

  static Future<List<dynamic>> getAllPhotographers() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/photographer"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("📸 GET ALL PHOTOGRAPHERS STATUS: ${res.statusCode}");
      print("📸 GET ALL PHOTOGRAPHERS BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        List<dynamic> photographers = [];

        if (data is List) {
          photographers = data;
        } else if (data is Map && data["photographers"] is List) {
          photographers = data["photographers"];
        }

        return _filterVisiblePhotographers(photographers);
      }

      return [];
    } catch (e) {
      print("📸 GET ALL PHOTOGRAPHERS ERROR: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getNearbyPhotographers({
    required double lat,
    required double lng,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/photographer/nearby?lat=$lat&lng=$lng"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("📍 NEARBY PHOTOGRAPHERS STATUS: ${res.statusCode}");
      print("📍 NEARBY PHOTOGRAPHERS BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        List<dynamic> photographers = [];

        if (data is List) {
          photographers = data;
        } else if (data is Map && data["photographers"] is List) {
          photographers = data["photographers"];
        }

        return _filterVisiblePhotographers(photographers);
      }

      return [];
    } catch (e) {
      print("📍 NEARBY PHOTOGRAPHERS ERROR: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getAvailablePhotographersForSession({
    required String date,
    required String time,
    required double durationHours,
    required String sessionType,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final uri = Uri.parse("$baseUrl/photographer/available-for-session")
          .replace(
        queryParameters: {
          "date": date,
          "time": time,
          "duration_hours": durationHours.toString(),
          "session_type": sessionType,
        },
      );

      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("📅 AVAILABLE PHOTOGRAPHERS STATUS: ${res.statusCode}");
      print("📅 AVAILABLE PHOTOGRAPHERS BODY: ${res.body}");

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        List<dynamic> photographers = [];

        if (data is List) {
          photographers = data;
        } else if (data is Map && data["photographers"] is List) {
          photographers = data["photographers"];
        }

        return _filterVisiblePhotographers(photographers);
      }

      throw Exception(
        data is Map
            ? data["message"] ?? "Failed to load available photographers"
            : "Failed to load available photographers",
      );
    } catch (e) {
      print("📅 AVAILABLE PHOTOGRAPHERS ERROR: $e");
      return [];
    }
  }
}