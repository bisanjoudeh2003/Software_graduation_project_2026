import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ProductImageService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static String get warehouseUrl => "$baseUrl/warehouse";

  static Future<List<String>> uploadImages({
    required String token,
    required dynamic productId,
    required List<XFile> images,
  }) async {
    if (images.isEmpty) return [];

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$warehouseUrl/products/$productId/images'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) continue;

      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: image.name.isNotEmpty ? image.name : 'product_image_$i.jpg',
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic> data = {};

    try {
      data = jsonDecode(response.body);
    } catch (_) {}

    if (response.statusCode == 200 || response.statusCode == 201) {
      final imagesData = data["images"];

      if (imagesData is List) {
        return imagesData.map((e) => e.toString()).toList();
      }

      return [];
    }

    throw Exception(
      data["message"] ??
          data["error"] ??
          "Failed to upload product images",
    );
  }

  static Future<String?> uploadImage({
    required String token,
    required dynamic productId,
    required XFile image,
  }) async {
    final uploadedImages = await uploadImages(
      token: token,
      productId: productId,
      images: [image],
    );

    if (uploadedImages.isEmpty) return null;

    return uploadedImages.first;
  }
}