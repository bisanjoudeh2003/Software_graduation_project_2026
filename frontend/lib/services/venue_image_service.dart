import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class VenueImageService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static Future<void> uploadImages(
    String token,
    int venueId,
    List<dynamic> images,
  ) async {
    if (images.isEmpty) return;

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/venue-images"),
    );

    request.headers["Authorization"] = "Bearer $token";
    request.fields["venue_id"] = venueId.toString();

    for (final image in images) {
      final bytes = await image.readAsBytes();

      String filename = "venue_image.jpg";

      try {
        final name = image.name?.toString();
        if (name != null && name.trim().isNotEmpty) {
          filename = name;
        }
      } catch (_) {
        try {
          final path = image.path?.toString() ?? "";
          if (path.isNotEmpty) {
            filename = path.split(RegExp(r'[\\/]+')).last;
          }
        } catch (_) {}
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          "images",
          bytes,
          filename: filename,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    String message = "Failed to upload images";

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded["message"] != null) {
        message = decoded["message"].toString();
      } else if (decoded is Map && decoded["error"] != null) {
        message = decoded["error"].toString();
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        message = response.body;
      }
    }

    throw Exception(message);
  }

  static Future<void> deleteImage(int imageId) async {
    final String? token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.delete(
      Uri.parse("$baseUrl/venue-images/$imageId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return;
    }

    String message = "Failed to delete image";

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded["message"] != null) {
        message = decoded["message"].toString();
      } else if (decoded is Map && decoded["error"] != null) {
        message = decoded["error"].toString();
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        message = response.body;
      }
    }

    throw Exception(message);
  }
}