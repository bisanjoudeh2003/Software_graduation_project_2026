import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WarehouseService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }

  static String get warehouseUrl => "$baseUrl/api/warehouse";

  static Future<List> getMyProducts() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("No token found");
    }

    final response = await http.get(
      Uri.parse("$warehouseUrl/products"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["products"] ?? [];
    }

    throw Exception("Failed to load products");
  }

  static Future<List> getPublicProducts() async {
    final response = await http.get(
      Uri.parse("$warehouseUrl/products/public"),
      headers: {
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["products"] ?? [];
    }

    throw Exception("Failed to load public products");
  }

  static Future<bool> addProduct({
    required String name,
    required String category,
    required String productType,
    required String description,
    required String imageUrl,
    required double price,
    required int stockQuantity,
    required bool allowCustomText,
    required bool allowColorChoice,
    required bool allowSizeChoice,
    required bool allowEventDate,
    required bool allowReferenceImage,
    required Map<String, dynamic> customFields,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("No token found");
    }

    final response = await http.post(
      Uri.parse("$warehouseUrl/products"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "category": category,
        "product_type": productType,
        "description": description,
        "image_url": imageUrl,
        "price": price,
        "stock_quantity": stockQuantity,
        "allow_custom_text": allowCustomText,
        "allow_color_choice": allowColorChoice,
        "allow_size_choice": allowSizeChoice,
        "allow_event_date": allowEventDate,
        "allow_reference_image": allowReferenceImage,
        "custom_fields": customFields,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    }

    try {
      final data = jsonDecode(response.body);
      throw Exception(data["message"] ?? "Failed to add product");
    } catch (_) {
      throw Exception("Failed to add product");
    }
  }

  static Future<bool> updateProduct({
  required int productId,
  required Map<String, dynamic> data,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("No token found");
  }

  final response = await http.put(
    Uri.parse("$warehouseUrl/products/$productId"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode(data),
  );

  if (response.statusCode == 200) {
    return true;
  }

  try {
    final body = jsonDecode(response.body);
    throw Exception(body["message"] ?? "Failed to update product");
  } catch (_) {
    throw Exception("Failed to update product");
  }
}

static Future<bool> deleteProduct(int productId) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("No token found");
  }

  final response = await http.delete(
    Uri.parse("$warehouseUrl/products/$productId"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
  );

  if (response.statusCode == 200) {
    return true;
  }

  try {
    final body = jsonDecode(response.body);
    throw Exception(body["message"] ?? "Failed to delete product");
  } catch (_) {
    throw Exception("Failed to delete product");
  }
}

  
}