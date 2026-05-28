import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AiAssistantMessage {
  final int? id;
  final String role;
  final String content;
  final DateTime? createdAt;

  AiAssistantMessage({
    this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  factory AiAssistantMessage.fromJson(Map<String, dynamic> json) {
    return AiAssistantMessage(
      id: json['id'],
      role: json['role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class AiAssistantService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("You are not logged in.");
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  static Future<List<AiAssistantMessage>> getMessages() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai-assistant/messages'),
      headers: await _headers(),
    );

    final data = _decodeBody(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final List messages = data['messages'] is List ? data['messages'] : [];

      return messages
          .whereType<Map<String, dynamic>>()
          .map((item) => AiAssistantMessage.fromJson(item))
          .toList();
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to load assistant messages',
    );
  }

  static Future<String> ask(String message) async {
    final cleanedMessage = message.trim();

    if (cleanedMessage.isEmpty) {
      throw Exception("Message cannot be empty.");
    }

    final response = await http.post(
      Uri.parse('$baseUrl/ai-assistant/ask'),
      headers: await _headers(),
      body: jsonEncode({
        'message': cleanedMessage,
      }),
    );

    final data = _decodeBody(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['answer']?.toString() ?? '';
    }

    throw Exception(
      data['message']?.toString() ?? 'Assistant error',
    );
  }

  static Future<void> clearChat() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/ai-assistant/clear'),
      headers: await _headers(),
    );

    final data = _decodeBody(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(
        data['message']?.toString() ?? 'Failed to clear assistant chat',
      );
    }
  }
}