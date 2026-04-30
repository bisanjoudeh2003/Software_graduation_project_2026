// venue_image_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';

class VenueImageService {

static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }
  static Future uploadImages(
    String token,
    int venueId,
    List<File> images,
  ) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/venue-images"),
    );

    request.headers["Authorization"] = "Bearer $token";
    request.fields["venue_id"] = venueId.toString();

    for (File image in images) {
      request.files.add(
        await http.MultipartFile.fromPath("images", image.path),
      );
    }

    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception("Failed to upload images");
    }
  }

  static Future deleteImage(int imageId) async {
    String? token = await AuthService.getToken();
    if (token == null) throw Exception("User not authenticated");

    final res = await http.delete(
      Uri.parse("$baseUrl/venue-images/$imageId"),  // ✅ مصلّح
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete image");
    }
  }
}