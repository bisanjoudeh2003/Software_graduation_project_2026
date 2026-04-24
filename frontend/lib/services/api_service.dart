import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }

  static Future<dynamic> getUsers() async {
    final response = await http.get(
      Uri.parse("$baseUrl/api/users"),
    );
    return jsonDecode(response.body);
  }
}