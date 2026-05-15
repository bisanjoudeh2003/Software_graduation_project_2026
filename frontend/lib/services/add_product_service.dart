import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AddProductService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static String get warehouseUrl => "$baseUrl/warehouse";

  static Future<Map<String, dynamic>> createProduct(
    String token,
    Map<String, dynamic> data,
  ) async {
    final String productType = data["product_type"]?.toString() ?? "ready";
    final String? rawPreviewType = data["preview_type"]?.toString();

    final bool hasPreview = productType == "custom" &&
        rawPreviewType != null &&
        rawPreviewType.isNotEmpty &&
        rawPreviewType != "none" &&
        rawPreviewType != "null";

    final Map<String, dynamic> body = {
      "name": data["name"],
      "description": data["description"],
      "category": data["category"],
      "product_type": productType,

      // مهم للوشاح والطاقية
      "preview_type": hasPreview ? rawPreviewType : null,
      "allow_preview": hasPreview ? 1 : 0,

      "price": data["price"],
      "stock_quantity": data["stock_quantity"],
      "image_url": data["image_url"],

      "allow_custom_text": productType == "custom"
          ? (data["allow_custom_text"] ?? false)
          : false,
      "allow_color_choice": productType == "custom"
          ? (data["allow_color_choice"] ?? false)
          : false,
      "allow_size_choice": productType == "custom"
          ? (data["allow_size_choice"] ?? false)
          : false,
      "allow_event_date": productType == "custom"
          ? (data["allow_event_date"] ?? false)
          : false,
      "allow_reference_image": productType == "custom"
          ? (data["allow_reference_image"] ?? false)
          : false,

      "custom_fields": productType == "custom" ? data["custom_fields"] : null,
    };

    debugPrint("CREATE PRODUCT BODY: ${jsonEncode(body)}");

    final res = await http.post(
      Uri.parse("$warehouseUrl/products"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic> decodedBody = {};

    try {
      decodedBody = Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      decodedBody = {};
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      return decodedBody;
    }

    throw Exception(decodedBody["message"] ?? "Failed to create product");
  }
}