import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PrintRequestService {
  static String get baseUrl => kIsWeb
      ? "http://localhost:3000/api/print-requests"
      : "http://10.0.2.2:3000/api/print-requests";

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  static Future<Map<String, dynamic>> createPrintRequest({
    required int galleryId,
    required int bookingId,
    required List<int> itemIds,
    required String printSize,
    required int quantity,
    String? notes,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final body = {
      "gallery_id": galleryId,
      "booking_id": bookingId,
      "items": itemIds,
      "print_size": printSize,
      "quantity": quantity,
      "notes": notes?.trim(),
    };

    debugPrint("CREATE PRINT REQUEST URL:");
    debugPrint(baseUrl);
    debugPrint("CREATE PRINT REQUEST BODY:");
    debugPrint(jsonEncode(body));

    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint("CREATE PRINT REQUEST STATUS: ${res.statusCode}");
    debugPrint("CREATE PRINT REQUEST RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to create print request.",
    );
  }

  static Future<List<Map<String, dynamic>>> getClientPrintRequests() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/client"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("GET CLIENT PRINT REQUESTS STATUS: ${res.statusCode}");
    debugPrint("GET CLIENT PRINT REQUESTS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      final raw = data["requests"];

      if (raw is List) {
        return raw.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      return [];
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to load print requests.",
    );
  }

  static Future<List<Map<String, dynamic>>> getPhotographerPrintRequests() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/photographer"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("GET PHOTOGRAPHER PRINT REQUESTS STATUS: ${res.statusCode}");
    debugPrint("GET PHOTOGRAPHER PRINT REQUESTS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      final raw = data["requests"];

      if (raw is List) {
        return raw.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      return [];
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to load print requests.",
    );
  }

  static Future<List<Map<String, dynamic>>> getPrintRequestsByGallery({
    required int galleryId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/gallery/$galleryId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("GET GALLERY PRINT REQUESTS STATUS: ${res.statusCode}");
    debugPrint("GET GALLERY PRINT REQUESTS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      final raw = data["requests"];

      if (raw is List) {
        return raw.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      return [];
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to load gallery print requests.",
    );
  }

  static Future<Map<String, dynamic>> getPrintRequestDetails({
    required int requestId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/$requestId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("GET PRINT REQUEST DETAILS STATUS: ${res.statusCode}");
    debugPrint("GET PRINT REQUEST DETAILS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to load print request details.",
    );
  }

  static Future<Map<String, dynamic>> updatePrintRequestStatus({
    required int requestId,
    required String status,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final body = {
      "status": status,
    };

    debugPrint("UPDATE PRINT REQUEST STATUS URL:");
    debugPrint("$baseUrl/$requestId/status");
    debugPrint("UPDATE PRINT REQUEST STATUS BODY:");
    debugPrint(jsonEncode(body));

    final res = await http.patch(
      Uri.parse("$baseUrl/$requestId/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint("UPDATE PRINT REQUEST STATUS STATUS: ${res.statusCode}");
    debugPrint("UPDATE PRINT REQUEST STATUS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to update print request.",
    );
  }
}