import 'dart:convert';
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
      role: json['role'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class AiAssistantService {
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<AiAssistantMessage>> getMessages() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai-assistant/messages'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final List messages = data['messages'] ?? [];

      return messages
          .map((item) => AiAssistantMessage.fromJson(item))
          .toList();
    }

    throw Exception(data['message'] ?? 'Failed to load assistant messages');
  }

  static Future<String> ask(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai-assistant/ask'),
      headers: await _headers(),
      body: jsonEncode({
        'message': message,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['answer'] ?? '';
    }

    throw Exception(data['message'] ?? 'Assistant error');
  }

  static Future<void> clearChat() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/ai-assistant/clear'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to clear assistant chat');
    }
  }
}