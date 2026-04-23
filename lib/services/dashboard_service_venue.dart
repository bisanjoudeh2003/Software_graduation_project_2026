import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardService {

  static const String baseUrl = "http://10.0.2.2:3000/api";

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