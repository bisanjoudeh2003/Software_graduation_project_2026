import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  static String get baseUrl {

    if (kIsWeb) {
      return "http://localhost:3000/api/auth";
    }

    return "http://10.0.2.2:3000/api/auth";
  }

  // REGISTER
  static Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String password,
    String role,
  ) async {

    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "full_name": fullName,
        "email": email,
        "password": password,
        "role": role,
      }),
    );

    print("REGISTER RESPONSE: ${response.body}");

    return jsonDecode(response.body);
  }

  // LOGIN
  static Future<bool> login(
    String email,
    String password,
  ) async {

    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password
      }),
    );

    print("LOGIN STATUS: ${response.statusCode}");
    print("LOGIN RESPONSE: ${response.body}");

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      SharedPreferences prefs =
          await SharedPreferences.getInstance();

      await prefs.setString("token", data["token"]);

      return true;

    } else {

      return false;

    }
  }

  // GET USER DATA
  static Future<Map<String, dynamic>?> getMe() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    String? token = prefs.getString("token");

    if (token == null) {
      print("NO TOKEN FOUND");
      return null;
    }

    final response = await http.get(
      Uri.parse("$baseUrl/me"),
      headers: {
        "Authorization": "Bearer $token"
      },
    );

    print("GET ME STATUS: ${response.statusCode}");
    print("GET ME RESPONSE: ${response.body}");

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      if (data == null || data["role"] == null) {
        print("ROLE NOT FOUND IN RESPONSE");
        return null;
      }

      return data;

    } else {

      print("FAILED TO GET USER");

      return null;

    }
  }

  // FORGOT PASSWORD
  static Future<Map<String, dynamic>> forgotPassword(
      String email) async {

    final response = await http.post(
      Uri.parse("$baseUrl/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    print("FORGOT PASSWORD RESPONSE: ${response.body}");

    return jsonDecode(response.body);
  }

  // RESET PASSWORD
  static Future<Map<String, dynamic>> resetPassword(
      String token,
      String newPassword) async {

    final response = await http.post(
      Uri.parse("$baseUrl/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": token,
        "newPassword": newPassword,
      }),
    );

    print("RESET PASSWORD RESPONSE: ${response.body}");

    return jsonDecode(response.body);
  }
static Future<String?> getToken() async {

  SharedPreferences prefs =
      await SharedPreferences.getInstance();

  return prefs.getString("token");

}
  static Future<void> logout() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.remove("token");

  }
}