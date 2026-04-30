import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ProfileService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }

  static Future<String?> uploadProfileImage(File image) async {
    String? token = await AuthService.getToken();

    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/upload"),
    );

    request.headers["Authorization"] = "Bearer $token";

    request.files.add(
      await http.MultipartFile.fromPath(
        "image",
        image.path,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final data = jsonDecode(res.body);
      return data["image_url"];
    }

    return null;
  }
}