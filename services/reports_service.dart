import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ReportsService {
  static Future<Map<String, dynamic>> getReports() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final res = await http.get(
      Uri.parse("${AuthService.apiBase}/reports"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    throw Exception("Failed to load reports");
  }
}