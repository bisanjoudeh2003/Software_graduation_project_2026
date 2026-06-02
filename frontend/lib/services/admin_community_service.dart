import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminCommunityService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin/community";
    }

    return "http://10.0.2.2:3000/api/admin/community";
  }

  static Map<String, String> _headers(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> getPosts({
    String q = "",
    String filter = "pending",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        return {
          "summary": {},
          "posts": [],
        };
      }

      final uri = Uri.parse("$baseUrl/posts").replace(
        queryParameters: {
          "filter": filter,
          if (q.trim().isNotEmpty) "q": q.trim(),
        },
      );

      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      print("ADMIN COMMUNITY POSTS STATUS: ${response.statusCode}");
      print("ADMIN COMMUNITY POSTS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          return {
            "summary": decoded["summary"] ?? {},
            "posts": decoded["posts"] ?? [],
          };
        }
      }

      return {
        "summary": {},
        "posts": [],
      };
    } catch (e) {
      print("ADMIN COMMUNITY POSTS ERROR: $e");

      return {
        "summary": {},
        "posts": [],
      };
    }
  }

  static Future<Map<String, dynamic>?> getPostDetails(int postId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/posts/$postId/details"),
        headers: _headers(token),
      );

      print("ADMIN COMMUNITY POST DETAILS STATUS: ${response.statusCode}");
      print("ADMIN COMMUNITY POST DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["post"] is Map<String, dynamic>) {
          return decoded["post"];
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print("ADMIN COMMUNITY POST DETAILS ERROR: $e");
      return null;
    }
  }

  static Future<bool> approvePost(int postId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/posts/$postId/approve"),
        headers: _headers(token),
      );

      print("ADMIN COMMUNITY APPROVE STATUS: ${response.statusCode}");
      print("ADMIN COMMUNITY APPROVE BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN COMMUNITY APPROVE ERROR: $e");
      return false;
    }
  }

  static Future<bool> rejectPost({
    required int postId,
    required String reason,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/posts/$postId/reject"),
        headers: _headers(token),
        body: jsonEncode({
          "reason": reason,
        }),
      );

      print("ADMIN COMMUNITY REJECT STATUS: ${response.statusCode}");
      print("ADMIN COMMUNITY REJECT BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN COMMUNITY REJECT ERROR: $e");
      return false;
    }
  }

  static Future<bool> updatePostVisibility({
    required int postId,
    required bool hidden,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/posts/$postId/visibility"),
        headers: _headers(token),
        body: jsonEncode({
          "hidden": hidden,
        }),
      );

      print("ADMIN COMMUNITY VISIBILITY STATUS: ${response.statusCode}");
      print("ADMIN COMMUNITY VISIBILITY BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN COMMUNITY VISIBILITY ERROR: $e");
      return false;
    }
  }

  static Future<bool> updateCommentVisibility({
    required int commentId,
    required bool hidden,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/comments/$commentId/hide"),
        headers: _headers(token),
        body: jsonEncode({
          "hidden": hidden,
        }),
      );

      print("ADMIN COMMUNITY COMMENT VISIBILITY STATUS: ${response.statusCode}");
      print("ADMIN COMMUNITY COMMENT VISIBILITY BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN COMMUNITY COMMENT VISIBILITY ERROR: $e");
      return false;
    }
  }
}