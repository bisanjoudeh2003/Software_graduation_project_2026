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
    int otherUserId,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/conversations/$otherUserId"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("GET OR CREATE CONV STATUS: ${res.statusCode}");
      debugPrint("GET OR CREATE CONV BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }

      return null;
    } catch (e) {
      debugPrint("GET OR CREATE CONV ERROR: $e");
      return null;
    }
  }

  static Future<List> getUserConversations() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/conversations"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("GET CONVERSATIONS STATUS: ${res.statusCode}");
      debugPrint("GET CONVERSATIONS BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) return decoded;
      }

      return [];
    } catch (e) {
      debugPrint("GET CONVERSATIONS ERROR: $e");
      return [];
    }
  }

  static Future<List> getMessages(int conversationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/conversations/$conversationId/messages"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("GET MESSAGES STATUS: ${res.statusCode}");
      debugPrint("GET MESSAGES BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) return decoded;
      }

      return [];
    } catch (e) {
      debugPrint("GET MESSAGES ERROR: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> sendMessage(
    int conversationId,
    String content,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/conversations/$conversationId/messages"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "content": content,
        }),
      );

      debugPrint("SEND MESSAGE STATUS: ${res.statusCode}");
      debugPrint("SEND MESSAGE BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }

      return null;
    } catch (e) {
      debugPrint("SEND MESSAGE ERROR: $e");
      return null;
    }
  }

  static Future<List> searchUsers(String query) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final res = await http.get(
        Uri.parse(
          "$baseUrl/users/search?q=${Uri.encodeComponent(query)}",
        ),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("SEARCH USERS STATUS: ${res.statusCode}");
      debugPrint("SEARCH USERS BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) return decoded;
      }

      return [];
    } catch (e) {
      debugPrint("SEARCH USERS ERROR: $e");
      return [];
    }
  }
}