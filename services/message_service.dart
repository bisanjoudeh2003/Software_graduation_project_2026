import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class MessageService {

 static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }
  static Future<Map<String, dynamic>?> getOrCreateConversation(
      int otherUserId) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final res = await http.post(
      Uri.parse("$baseUrl/conversations/$otherUserId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<List> getUserConversations() async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse("$baseUrl/conversations"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<List> getMessages(int conversationId) async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse("$baseUrl/conversations/$conversationId/messages"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>?> sendMessage(
      int conversationId, String content) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final res = await http.post(
      Uri.parse("$baseUrl/conversations/$conversationId/messages"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"content": content}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<List> searchUsers(String query) async {
  final token = await AuthService.getToken();
  if (token == null) return [];

  final res = await http.get(
    Uri.parse("$baseUrl/users/search?q=${Uri.encodeComponent(query)}"),
    headers: {"Authorization": "Bearer $token"},
  );

  if (res.statusCode == 200) return jsonDecode(res.body);
  return [];
}
}