import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FavoriteService {

  static String get baseUrl => "${AuthService.apiBase}";

  static Future<bool> addFavorite(int venueId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.post(
      Uri.parse("$baseUrl/favorites/$venueId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return res.statusCode == 200;
  }

  static Future<bool> removeFavorite(int venueId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.delete(
      Uri.parse("$baseUrl/favorites/$venueId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return res.statusCode == 200;
  }

  static Future<List> getUserFavorites() async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse("$baseUrl/favorites"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<bool> checkFavorite(int venueId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    final res = await http.get(
      Uri.parse("$baseUrl/favorites/$venueId/check"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["isFavorite"] ?? false;
    }
    return false;
  }
}