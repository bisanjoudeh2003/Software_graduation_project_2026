import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

static const String baseUrl = "http://10.0.2.2:3000";

  static Future<dynamic> getUsers() async {
    final response = await http.get(Uri.parse("$baseUrl/users"));
    return jsonDecode(response.body);
  }
}

