import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

class CommunityService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static String get communityUrl => "$baseUrl/community";

  static Future<List<dynamic>> getPosts({
    String category = "all",
    String search = "",
    String sort = "latest",
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final uri = Uri.parse("$communityUrl/posts").replace(
      queryParameters: {
        "category": category,
        "search": search,
        "sort": sort,
      },
    );

    final response = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["posts"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load community posts");
  }

  static Future<Map<String, dynamic>> getPostById(int postId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$communityUrl/posts/$postId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to load post details");
  }

  static Future<Map<String, dynamic>> createPost({
    required String title,
    required String body,
    required String category,
    required bool isQuestion,
    String? mediaUrl,
    String mediaType = "image",
    List<Map<String, dynamic>> media = const [],
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$communityUrl/posts"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "title": title.trim().isEmpty ? null : title.trim(),
        "body": body.trim(),
        "category": category,
        "is_question": isQuestion,
        "media_url": mediaUrl,
        "media_type": mediaType,
        "media": media,
      }),
    );

    final resBody = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(resBody);
    }

    throw Exception(resBody["message"] ?? "Failed to create post");
  }

  static Future<List<Map<String, dynamic>>> uploadMedia(
    List<XFile> files,
  ) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$communityUrl/upload-media"),
    );

    request.headers["Authorization"] = "Bearer $token";

    for (final file in files) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            "media",
            bytes,
            filename: file.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            "media",
            file.path,
            filename: file.name,
          ),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = body["media"] is List ? body["media"] : [];

      return raw.map<Map<String, dynamic>>((e) {
        return Map<String, dynamic>.from(e);
      }).toList();
    }

    throw Exception(body["message"] ?? "Failed to upload media");
  }

  static Future<List<dynamic>> getReels() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$communityUrl/reels"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["reels"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load reels");
  }

  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$communityUrl/posts/$postId/like"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to update like");
  }

  static Future<Map<String, dynamic>> toggleSave(int postId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$communityUrl/posts/$postId/save"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to update save");
  }

  static Future<List<dynamic>> getSavedPosts() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$communityUrl/posts/saved"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["posts"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load saved posts");
  }

  static Future<List<dynamic>> getComments(int postId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$communityUrl/posts/$postId/comments"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["comments"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load comments");
  }

  static Future<Map<String, dynamic>> addComment({
    required int postId,
    required String comment,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$communityUrl/posts/$postId/comments"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "comment": comment.trim(),
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to add comment");
  }

  static Future<Map<String, dynamic>> reportPost({
    required int postId,
    required String reason,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$communityUrl/posts/$postId/report"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "reason": reason.trim(),
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to report post");
  }

  static Future<Map<String, dynamic>> deletePost(int postId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.delete(
      Uri.parse("$communityUrl/posts/$postId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to delete post");
  }
}