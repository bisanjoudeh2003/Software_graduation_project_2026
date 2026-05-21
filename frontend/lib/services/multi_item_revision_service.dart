import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class MultiItemRevisionService {
  static String get baseUrl {
    if (kIsWeb) {
      return "${Uri.base.origin}/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  static Future<Map<String, dynamic>> requestRevisionForSelectedItems({
    required int galleryId,
    required List<int> itemIds,
    required String note,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    if (galleryId <= 0) {
      throw Exception("Invalid gallery id.");
    }

    final cleanedItemIds = itemIds.where((id) => id > 0).toSet().toList();

    if (cleanedItemIds.isEmpty) {
      throw Exception("Select at least one file.");
    }

    if (note.trim().isEmpty) {
      throw Exception("Please write one revision note.");
    }

    final res = await http.post(
      Uri.parse(
        "$baseUrl/multi-item-revisions/galleries/$galleryId/request",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "item_ids": cleanedItemIds,
        "note": note.trim(),
      }),
    );

    debugPrint("MULTI ITEM REVISION STATUS: ${res.statusCode}");
    debugPrint("MULTI ITEM REVISION RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to request revisions.",
    );
  }

  static Future<Map<String, dynamic>> suggestGroupRevisionPlan({
    required String note,
    required int fileCount,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final cleanNote = note.trim();

    if (cleanNote.isEmpty) {
      throw Exception("Client revision note is missing.");
    }

    final res = await http.post(
      Uri.parse(
        "$baseUrl/multi-item-revisions/group-plan/suggest",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "note": cleanNote,
        "file_count": fileCount,
      }),
    );

    debugPrint("GROUP AI PLAN STATUS: ${res.statusCode}");
    debugPrint("GROUP AI PLAN RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to suggest group plan.",
    );
  }

  static Future<Map<String, dynamic>> applyPresetToSelectedRevisionRequests({
    required List<int> requestIds,
    required String preset,
    required String intensity,
    String photographerResponse = "",
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final cleanedRequestIds = requestIds.where((id) => id > 0).toSet().toList();

    if (cleanedRequestIds.isEmpty) {
      throw Exception("Select at least one edit request.");
    }

    if (cleanedRequestIds.length > 10) {
      throw Exception("You can apply a preset to up to 10 files at a time.");
    }

    if (preset.trim().isEmpty) {
      throw Exception("Please choose a preset.");
    }

    final cleanIntensity =
        intensity.trim().isEmpty ? "standard" : intensity.trim();

    final res = await http.post(
      Uri.parse(
        "$baseUrl/multi-item-revisions/revision-requests/apply-preset",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "request_ids": cleanedRequestIds,
        "preset": preset.trim(),
        "intensity": cleanIntensity,
        "photographer_response": photographerResponse.trim(),
      }),
    );

    debugPrint("MULTI APPLY PRESET STATUS: ${res.statusCode}");
    debugPrint("MULTI APPLY PRESET RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to apply preset.",
    );
  }
}