import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DashboardService {

 static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }
  static Future<Map<String,dynamic>> getDashboard(String token) async {

    final res = await http.get(
      Uri.parse("$baseUrl/dashboard"),
      headers: {
        "Authorization": "Bearer $token"
      }
    );

    if(res.statusCode == 200){
      return jsonDecode(res.body);
    }

    throw Exception("Failed to load dashboard");
  }

}