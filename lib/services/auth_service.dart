import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  /// BASE URL
  static String get apiBase {

    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static String get authBase => "$apiBase/auth";


  /// REGISTER
  static Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String phone,
    String password,
    String role) async {

  final response = await http.post(
    Uri.parse("$authBase/register"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "full_name": fullName,
      "email": email,
      "phone": phone,
      "password": password,
      "role": role
    }),
  );

  print("REGISTER RESPONSE: ${response.body}");

  return jsonDecode(response.body);
}

  /// LOGIN
  static Future<bool> login(
      String email,
      String password) async {

    final response = await http.post(
      Uri.parse("$authBase/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password
      }),
    );

    print("LOGIN RESPONSE: ${response.body}");

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      SharedPreferences prefs =
          await SharedPreferences.getInstance();

      /// SAVE TOKEN
      await prefs.setString("token", data["token"]);

      /// SAVE ROLE
      await prefs.setString("role", data["role"]);

      return true;

    }

    return false;

  }


  /// GET TOKEN
  static Future<String?> getToken() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString("token");

  }


  /// GET ROLE
  static Future<String?> getRole() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString("role");

  }


  /// GET USER DATA
  static Future<Map<String, dynamic>?> getMe() async {

    String? token = await getToken();

    if (token == null) {
      print("NO TOKEN FOUND");
      return null;
    }

    final response = await http.get(
      Uri.parse("$authBase/me"),
      headers: {
        "Authorization": "Bearer $token"
      },
    );

    print("GET ME RESPONSE: ${response.body}");

    if (response.statusCode == 200) {

      return jsonDecode(response.body);

    }

    return null;

  }


  /// FORGOT PASSWORD
  static Future<Map<String, dynamic>> forgotPassword(
      String email) async {

    final response = await http.post(
      Uri.parse("$authBase/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    return jsonDecode(response.body);

  }


  /// RESET PASSWORD
  static Future<Map<String, dynamic>> resetPassword(
      String token,
      String newPassword) async {

    final response = await http.post(
      Uri.parse("$authBase/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": token,
        "newPassword": newPassword
      }),
    );

    return jsonDecode(response.body);

  }


  /// LOGOUT
  static Future<void> logout() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.remove("token");
    await prefs.remove("role");

  }


  /// UPDATE PROFILE
  static Future<bool> updateProfile(
      String fullName,
      String phone) async {

    String? token = await getToken();

    if(token == null) return false;

    final response = await http.put(

      Uri.parse("$authBase/update-profile"),

      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },

      body: jsonEncode({
        "full_name": fullName,
        "phone": phone
      }),

    );

    print("UPDATE PROFILE RESPONSE: ${response.body}");

    return response.statusCode == 200;

  }



  /// CHANGE PASSWORD
  static Future<bool> changePassword(
      String oldPassword,
      String newPassword) async {

    String? token = await getToken();

    if(token == null) return false;

    final response = await http.post(

      Uri.parse("$authBase/change-password"),

      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },

      body: jsonEncode({
        "oldPassword": oldPassword,
        "newPassword": newPassword
      }),

    );

    print("CHANGE PASSWORD RESPONSE: ${response.body}");

    return response.statusCode == 200;

  }

static Future<bool> updateBio(
      String bio, Map<String, String> socialLinks) async {

    String? token = await getToken();
    if (token == null) return false;

    final response = await http.put(
      Uri.parse("$apiBase/users/bio"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "bio": bio,
        "social_links": socialLinks,
      }),
    );

    print("UPDATE BIO RESPONSE: ${response.body}");
    return response.statusCode == 200;
  }

// GET public profile (bio + social links)
static Future<Map<String, dynamic>?> getPublicProfile(int userId) async {
  final response = await http.get(
    Uri.parse("$apiBase/users/$userId"),
  );
  print("GET PUBLIC PROFILE RESPONSE: ${response.body}");
  if (response.statusCode == 200) return jsonDecode(response.body);
  return null;
}
}