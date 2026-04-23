import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsService {

  static const baseUrl = "http://10.0.2.2:3000/api";

  static Future<Map<String,dynamic>> getSettings(String token) async {

    final res = await http.get(
      Uri.parse("$baseUrl/settings"),
      headers: {"Authorization":"Bearer $token"}
    );

    if(res.statusCode == 200){
      return jsonDecode(res.body);
    }

    throw Exception("Failed to load settings");

  }

  static Future toggleNotifications(String token,bool enabled) async {

    await http.put(
      Uri.parse("$baseUrl/settings/notifications"),
      headers: {
        "Authorization":"Bearer $token",
        "Content-Type":"application/json"
      },
      body: jsonEncode({"enabled":enabled})
    );

  }

  static Future toggleDarkMode(String token,bool enabled) async {

    await http.put(
      Uri.parse("$baseUrl/settings/darkmode"),
      headers: {
        "Authorization":"Bearer $token",
        "Content-Type":"application/json"
      },
      body: jsonEncode({"enabled":enabled})
    );

  }

  static Future deleteAccount(String token) async {

    final res = await http.delete(
      Uri.parse("$baseUrl/settings/delete-account"),
      headers: {"Authorization":"Bearer $token"}
    );

    if(res.statusCode != 200){
      throw Exception("Failed to delete account");
    }

  }

}