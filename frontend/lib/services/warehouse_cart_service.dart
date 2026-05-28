import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WarehouseCartService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    // Emulator Android
    return "http://10.0.2.2:3000/api";

    // إذا بتجربي على موبايل حقيقي، لازم تحطي IP اللابتوب بدل 10.0.2.2
    // مثال:
    // return "http://192.168.1.10:3000/api";
  }

  static String get warehouseUrl => "$baseUrl/warehouse";

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String url,
  ) {
    debugPrint("WAREHOUSE CART URL: $url");
    debugPrint("WAREHOUSE CART STATUS: ${response.statusCode}");
    debugPrint("WAREHOUSE CART BODY: ${response.body}");

    final rawBody = response.body.trim();

    if (rawBody.isEmpty) {
      return {};
    }

    if (rawBody.startsWith("<!DOCTYPE html") || rawBody.startsWith("<html")) {
      throw Exception(
        "The server returned HTML instead of JSON. Check this API URL: $url",
      );
    }

    try {
      final decoded = jsonDecode(rawBody);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        "success": false,
        "message": "Unexpected response format from server",
        "data": decoded,
      };
    } catch (e) {
      throw Exception(
        "Failed to read server response as JSON. URL: $url",
      );
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> getCart() async {
    final url = "$warehouseUrl/cart";

    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to load cart");
  }

  static Future<Map<String, dynamic>> addToCart({
    required int productId,
    int quantity = 1,
    Map<String, dynamic>? customDetails,
    String? referenceImageUrl,
  }) async {
    final url = "$warehouseUrl/cart";

    final response = await http.post(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({
        "product_id": productId,
        "quantity": quantity,
        "custom_details": customDetails,
        "reference_image_url": referenceImageUrl,
      }),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to add product to cart");
  }

  static Future<Map<String, dynamic>> updateCartItem({
    required int cartItemId,
    required int quantity,
  }) async {
    final url = "$warehouseUrl/cart/$cartItemId";

    final response = await http.put(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({
        "quantity": quantity,
      }),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to update cart item");
  }

  static Future<Map<String, dynamic>> removeCartItem(int cartItemId) async {
    final url = "$warehouseUrl/cart/$cartItemId";

    final response = await http.delete(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to remove cart item");
  }

  static Future<Map<String, dynamic>> clearCart() async {
    final url = "$warehouseUrl/cart";

    final response = await http.delete(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to clear cart");
  }

  static Future<Map<String, dynamic>> checkoutFromCart({
    String? neededDate,
    String? notes,
    int? photographerId,
  }) async {
    final url = "$warehouseUrl/orders/from-cart";

    final response = await http.post(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({
        "needed_date": neededDate,
        "notes": notes,
        "photographer_id": photographerId,
      }),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to create order");
  }
}