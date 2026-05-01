import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PortfolioItemService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }

  static Future<http.Response> addItem({
    required int portfolioId,
    required String title,
    required String description,
    required String mediaUrl,
    required String mediaType,
  }) async {
    final body = {
      "portfolio_id": portfolioId,
      "title": title,
      "description": description,
      "media_url": mediaUrl,
      "media_type": mediaType,
    };

    return await http.post(
      Uri.parse("$baseUrl/api/portfolio-items"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> updateItem({
    required int itemId,
    required int portfolioId,
    required String title,
    required String description,
    required String mediaUrl,
    required String mediaType,
  }) async {
    final body = {
      "portfolio_id": portfolioId,
      "title": title,
      "description": description,
      "media_url": mediaUrl,
      "media_type": mediaType,
    };

    return await http.put(
      Uri.parse("$baseUrl/api/portfolio-items/$itemId"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
  }
}