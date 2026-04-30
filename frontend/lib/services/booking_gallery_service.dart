import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'auth_service.dart';

class BookingGalleryService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }

  static Future<Map<String, dynamic>> createOrGetGallery(
    int bookingId, {
    String? title,
    String? description,
    String? estimatedDeliveryDate,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final body = <String, dynamic>{};

    if (title != null && title.trim().isNotEmpty) {
      body["title"] = title.trim();
    }

    if (description != null && description.trim().isNotEmpty) {
      body["description"] = description.trim();
    }

    if (estimatedDeliveryDate != null &&
        estimatedDeliveryDate.trim().isNotEmpty) {
      body["estimated_delivery_date"] = estimatedDeliveryDate.trim();
    }

    final res = await http.post(
      Uri.parse("$baseUrl/booking-galleries/$bookingId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to create gallery.");
  }

  static Future<Map<String, dynamic>> getGalleryByBooking(int bookingId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/booking-galleries/$bookingId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to load gallery.");
  }

  static Future<Map<String, dynamic>> uploadGalleryPhotos({
    required int galleryId,
    required List<PlatformFile> files,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    if (files.isEmpty) {
      throw Exception("Please choose at least one file.");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/booking-galleries/$galleryId/upload"),
    );

    request.headers["Authorization"] = "Bearer $token";

    for (final file in files) {
      if (file.bytes == null) {
        throw Exception("Could not read selected file: ${file.name}");
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          "photos",
          file.bytes!,
          filename: file.name,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    final data = _decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to upload photos.");
  }

  static Future<Map<String, dynamic>> deliverGallery(int galleryId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/$galleryId/deliver"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to deliver gallery.");
  }

  static Future<void> deleteGalleryItem(int itemId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.delete(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return;
    }

    throw Exception(data["message"] ?? "Failed to delete photo.");
  }

  static Future<Map<String, dynamic>> toggleFavoriteItem({
    required int itemId,
    required bool isFavorite,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId/favorite"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "is_favorite": isFavorite ? 1 : 0,
      }),
    );

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to update favorite.");
  }

  static Future<Map<String, dynamic>> requestItemRevision({
    required int itemId,
    required String note,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final cleanNote = note.trim();

    if (cleanNote.isEmpty) {
      throw Exception("Revision note is required.");
    }

    final res = await http.post(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId/revision-request"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "note": cleanNote,
      }),
    );

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to request edits.");
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {"message": "Unexpected server response."};
    } catch (_) {
      return {"message": "Unexpected server response."};
    }
  }
}