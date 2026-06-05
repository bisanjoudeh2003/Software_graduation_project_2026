import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'auth_service.dart';


class BookingGalleryService {
static String get baseUrl {
  return "https://lensia-backend.onrender.com/api";
}
  static Future<Map<String, dynamic>> createOrGetGallery(
    int bookingId, {
    String? title,
    String? description,
    String? estimatedDeliveryDate,
    bool? allowDownload,
    bool? previewWatermarked,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final body = <String, dynamic>{};

    if (title != null && title.trim().isNotEmpty) {
      body["title"] = title.trim();
    }

    if (description != null && description.trim().isNotEmpty) {
      body["description"] = description.trim();
    }

    if (estimatedDeliveryDate != null &&
        estimatedDeliveryDate.trim().isNotEmpty) {
      body["estimated_delivery_date"] = estimatedDeliveryDate.trim();
    }

    if (allowDownload != null) {
      body["allow_download"] = allowDownload ? 1 : 0;
    }

    if (previewWatermarked != null) {
      body["preview_watermarked"] = previewWatermarked ? 1 : 0;
    }

    debugPrint("CREATE OR GET GALLERY URL:");
    debugPrint("$baseUrl/booking-galleries/$bookingId");
    debugPrint("CREATE OR GET GALLERY BODY:");
    debugPrint(jsonEncode(body));

    final res = await http.post(
      Uri.parse("$baseUrl/booking-galleries/$bookingId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint("CREATE OR GET GALLERY STATUS: ${res.statusCode}");
    debugPrint("CREATE OR GET GALLERY RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to create gallery.",
    );
  }

  static Future<Map<String, dynamic>> updateGallerySettings({
    required int galleryId,
    String? title,
    String? description,
    String? estimatedDeliveryDate,
    bool? allowDownload,
    bool? previewWatermarked,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final body = <String, dynamic>{};

    if (title != null) {
      body["title"] = title.trim();
    }

    if (description != null) {
      body["description"] = description.trim();
    }

    if (estimatedDeliveryDate != null) {
      body["estimated_delivery_date"] = estimatedDeliveryDate.trim();
    }

    if (allowDownload != null) {
      body["allow_download"] = allowDownload ? 1 : 0;
    }

    if (previewWatermarked != null) {
      body["preview_watermarked"] = previewWatermarked ? 1 : 0;
    }

    if (body.isEmpty) {
      throw Exception("No gallery settings to update.");
    }

    debugPrint("UPDATE GALLERY SETTINGS URL:");
    debugPrint("$baseUrl/booking-galleries/$galleryId/settings");
    debugPrint("UPDATE GALLERY SETTINGS BODY:");
    debugPrint(jsonEncode(body));

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/$galleryId/settings"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint("UPDATE GALLERY SETTINGS STATUS: ${res.statusCode}");
    debugPrint("UPDATE GALLERY SETTINGS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to update gallery settings.",
    );
  }

  static Future<Map<String, dynamic>> getMyGalleries() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/booking-galleries/my-galleries"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("GET MY GALLERIES STATUS: ${res.statusCode}");
    debugPrint("GET MY GALLERIES RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to load galleries.",
    );
  }

  static Future<Map<String, dynamic>> getGalleryByBooking(int bookingId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/booking-galleries/$bookingId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("GET GALLERY BY BOOKING STATUS: ${res.statusCode}");
    debugPrint("GET GALLERY BY BOOKING RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to load gallery.",
    );
  }

  static Future<Map<String, dynamic>> uploadGalleryPhotos({
    required int galleryId,
    required List<PlatformFile> files,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    if (files.isEmpty) {
      throw Exception("Please choose at least one file.");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/booking-galleries/$galleryId/upload"),
    );

    request.headers["Authorization"] = "Bearer $token";

    for (final file in files) {
      if (file.bytes == null) {
        throw Exception("Could not read selected file: ${file.name}");
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          "photos",
          file.bytes!,
          filename: file.name,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint("UPLOAD GALLERY PHOTOS STATUS: ${response.statusCode}");
    debugPrint("UPLOAD GALLERY PHOTOS RESPONSE: ${response.body}");

    final data = _decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to upload photos.",
    );
  }

  static Future<Map<String, dynamic>> deliverGallery(int galleryId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/$galleryId/deliver"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("DELIVER GALLERY STATUS: ${res.statusCode}");
    debugPrint("DELIVER GALLERY RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to deliver gallery.",
    );
  }

  static Future<Map<String, dynamic>> finalizeGallery(int galleryId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/$galleryId/finalize"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("FINALIZE GALLERY STATUS: ${res.statusCode}");
    debugPrint("FINALIZE GALLERY RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to finalize gallery.",
    );
  }

  static Future<void> deleteGalleryItem(int itemId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.delete(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("DELETE GALLERY ITEM STATUS: ${res.statusCode}");
    debugPrint("DELETE GALLERY ITEM RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to delete photo.",
    );
  }

  static Future<Map<String, dynamic>> toggleFavoriteItem({
    required int itemId,
    required bool isFavorite,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId/favorite"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "is_favorite": isFavorite ? 1 : 0,
      }),
    );

    debugPrint("TOGGLE FAVORITE STATUS: ${res.statusCode}");
    debugPrint("TOGGLE FAVORITE RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to update favorite.",
    );
  }

  static Future<Map<String, dynamic>> requestItemRevision({
    required int itemId,
    required String note,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final cleanNote = note.trim();

    if (cleanNote.isEmpty) {
      throw Exception("Revision note is required.");
    }

    final res = await http.post(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId/revision-request"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "note": cleanNote,
      }),
    );

    debugPrint("REQUEST REVISION STATUS: ${res.statusCode}");
    debugPrint("REQUEST REVISION RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to request edits.",
    );
  }

  static Future<Map<String, dynamic>> uploadEditedVersion({
    required int requestId,
    required PlatformFile file,
    String? photographerResponse,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    if (file.bytes == null) {
      throw Exception("Could not read selected file: ${file.name}");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse(
        "$baseUrl/booking-galleries/revision-requests/$requestId/upload-edited-version",
      ),
    );

    request.headers["Authorization"] = "Bearer $token";

    request.files.add(
      http.MultipartFile.fromBytes(
        "media",
        file.bytes!,
        filename: file.name,
      ),
    );

    final responseText = photographerResponse?.trim() ?? "";

    if (responseText.isNotEmpty) {
      request.fields["photographer_response"] = responseText;
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint("UPLOAD EDITED VERSION STATUS: ${response.statusCode}");
    debugPrint("UPLOAD EDITED VERSION RESPONSE: ${response.body}");

    final data = _decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to upload edited version.",
    );
  }
static Future<Map<String, dynamic>> createShareLink({
  required int galleryId,
  bool allowDownload = false,
  int expiresInDays = 7,
}) async {
  final body = {
    "allow_download": allowDownload ? 1 : 0,
    "expires_in_days": expiresInDays,
  };

  final res = await http.post(
    Uri.parse("$baseUrl/booking-galleries/$galleryId/share-link-demo"),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode(body),
  );

  debugPrint("CREATE SHARE LINK DEMO STATUS: ${res.statusCode}");
  debugPrint("CREATE SHARE LINK DEMO RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200 || res.statusCode == 201) {
    return data;
  }

  throw Exception(
    data["error"] ?? data["message"] ?? "Failed to create share link.",
  );
}
  static Future<Map<String, dynamic>> getSharedGallery(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/booking-galleries/shared/$token"),
    );

    debugPrint("GET SHARED GALLERY STATUS: ${res.statusCode}");
    debugPrint("GET SHARED GALLERY RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to load shared gallery.",
    );
  }

  static Future<Map<String, dynamic>> requestPortfolioPermission({
    required int itemId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.post(
      Uri.parse(
        "$baseUrl/booking-galleries/items/$itemId/request-portfolio-permission",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("REQUEST PORTFOLIO PERMISSION STATUS: ${res.statusCode}");
    debugPrint("REQUEST PORTFOLIO PERMISSION RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["error"] ??
          data["message"] ??
          "Failed to request portfolio permission.",
    );
  }

  static Future<Map<String, dynamic>> respondPortfolioPermission({
    required int itemId,
    required String status,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    if (status != "approved" && status != "rejected") {
      throw Exception("Invalid portfolio permission response.");
    }

    final res = await http.patch(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId/portfolio-permission"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "status": status,
      }),
    );

    debugPrint("RESPOND PORTFOLIO PERMISSION STATUS: ${res.statusCode}");
    debugPrint("RESPOND PORTFOLIO PERMISSION RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ??
          data["message"] ??
          "Failed to update portfolio permission.",
    );
  }

  static Future<Map<String, dynamic>> addGalleryItemToPortfolio({
    required int itemId,
    String? title,
    String? description,
    int? albumId,
    int? categoryId,
    bool useWatermark = true,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final body = {
      "title": title?.trim(),
      "description": description?.trim(),
      "album_id": albumId,
      "category_id": categoryId,
      "use_watermark": useWatermark ? 1 : 0,
    };

    debugPrint("ADD GALLERY ITEM TO PORTFOLIO URL:");
    debugPrint("$baseUrl/booking-galleries/items/$itemId/add-to-portfolio");
    debugPrint("ADD GALLERY ITEM TO PORTFOLIO BODY:");
    debugPrint(jsonEncode(body));

    final res = await http.post(
      Uri.parse("$baseUrl/booking-galleries/items/$itemId/add-to-portfolio"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint("ADD GALLERY ITEM TO PORTFOLIO STATUS: ${res.statusCode}");
    debugPrint("ADD GALLERY ITEM TO PORTFOLIO RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }

    throw Exception(
      data["error"] ??
          data["message"] ??
          "Failed to add photo to portfolio.",
    );
  }

  static Future<Map<String, dynamic>> getPortfolioOptions() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("You are not logged in.");
    }

    final res = await http.get(
      Uri.parse("$baseUrl/booking-galleries/portfolio/options"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    debugPrint("GET PORTFOLIO OPTIONS STATUS: ${res.statusCode}");
    debugPrint("GET PORTFOLIO OPTIONS RESPONSE: ${res.body}");

    final data = _decode(res.body);

    if (res.statusCode == 200) {
      return data;
    }

    throw Exception(
      data["error"] ?? data["message"] ?? "Failed to load portfolio options.",
    );
  }

  static Future<Map<String, dynamic>> createRemainingPaymentIntent({
  required int galleryId,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final res = await http.post(
    Uri.parse(
      "$baseUrl/booking-galleries/$galleryId/remaining-payment-intent",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  debugPrint("CREATE REMAINING PAYMENT INTENT STATUS: ${res.statusCode}");
  debugPrint("CREATE REMAINING PAYMENT INTENT RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["message"] ??
        data["error"] ??
        "Failed to create remaining payment intent.",
  );
}

static Future<Map<String, dynamic>> confirmRemainingPayment({
  required int galleryId,
  required String paymentIntentId,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final res = await http.post(
    Uri.parse(
      "$baseUrl/booking-galleries/$galleryId/confirm-remaining-payment",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "payment_intent_id": paymentIntentId,
    }),
  );

  debugPrint("CONFIRM REMAINING PAYMENT STATUS: ${res.statusCode}");
  debugPrint("CONFIRM REMAINING PAYMENT RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["message"] ??
        data["error"] ??
        "Failed to confirm remaining payment.",
  );
}


  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {"message": "Unexpected server response."};
    } catch (_) {
      return {"message": "Unexpected server response."};
    }
  }
  static Future<Map<String, dynamic>> getClientGalleries() async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final res = await http.get(
    Uri.parse("$baseUrl/booking-galleries/client/my-galleries"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  debugPrint("GET CLIENT GALLERIES STATUS: ${res.statusCode}");
  debugPrint("GET CLIENT GALLERIES RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["error"] ?? data["message"] ?? "Failed to load galleries.",
  );
}

static Future<Map<String, dynamic>> requestCleanCopy({
  required int galleryId,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final res = await http.post(
    Uri.parse("$baseUrl/booking-galleries/$galleryId/request-clean-copy"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  debugPrint("REQUEST CLEAN COPY STATUS: ${res.statusCode}");
  debugPrint("REQUEST CLEAN COPY RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["message"] ?? data["error"] ?? "Failed to request clean copy.",
  );
}

static Future<Map<String, dynamic>> respondCleanCopy({
  required int galleryId,
  required String status,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final res = await http.patch(
    Uri.parse("$baseUrl/booking-galleries/$galleryId/respond-clean-copy"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "status": status,
    }),
  );

  debugPrint("RESPOND CLEAN COPY STATUS: ${res.statusCode}");
  debugPrint("RESPOND CLEAN COPY RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["message"] ?? data["error"] ?? "Failed to respond to clean copy request.",
  );
}


static Future<Map<String, dynamic>> updateRevisionRequestStatus({
  required int requestId,
  required String status,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final allowed = ["pending", "in_progress", "done"];

  if (!allowed.contains(status)) {
    throw Exception("Invalid revision status.");
  }

  final res = await http.patch(
    Uri.parse(
      "$baseUrl/booking-galleries/revision-requests/$requestId/status",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "status": status,
    }),
  );

  debugPrint("UPDATE REVISION STATUS: ${res.statusCode}");
  debugPrint("UPDATE REVISION STATUS RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["error"] ?? data["message"] ?? "Failed to update revision status.",
  );
}
static Future<Map<String, dynamic>> updateRevisionWorkspacePlan({
  required int requestId,
  required String editType,
  String? customEditType,
  required List<Map<String, dynamic>> checklist,
  String? photographerResponse,
  String? aiSuggestionReason,
  String? aiSuggestedPreset,
  String? aiSuggestedIntensity,
  String? aiDetectedIssue,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final body = {
    "edit_type": editType,
    "custom_edit_type": customEditType?.trim(),
    "checklist": checklist,
    "photographer_response": photographerResponse?.trim(),
    "ai_suggestion_reason": aiSuggestionReason?.trim(),
    "ai_suggested_preset": aiSuggestedPreset?.trim(),
    "ai_suggested_intensity": aiSuggestedIntensity?.trim(),
    "ai_detected_issue": aiDetectedIssue?.trim(),
  };

  debugPrint("UPDATE REVISION WORKSPACE URL:");
  debugPrint("$baseUrl/booking-galleries/revision-requests/$requestId/workspace");
  debugPrint("UPDATE REVISION WORKSPACE BODY:");
  debugPrint(jsonEncode(body));

  final res = await http.patch(
    Uri.parse(
      "$baseUrl/booking-galleries/revision-requests/$requestId/workspace",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode(body),
  );

  debugPrint("UPDATE REVISION WORKSPACE STATUS: ${res.statusCode}");
  debugPrint("UPDATE REVISION WORKSPACE RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["error"] ??
        data["message"] ??
        "Failed to save revision workspace plan.",
  );
}
static Future<Map<String, dynamic>> applyPresetToRevision({
  required int requestId,
  required String preset,
  String intensity = "standard",
  String? photographerResponse,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final body = {
    "preset": preset,
    "intensity": intensity,
    "photographer_response": photographerResponse?.trim(),
  };

  debugPrint("APPLY PRESET URL:");
  debugPrint(
    "$baseUrl/booking-galleries/revision-requests/$requestId/apply-preset",
  );

  debugPrint("APPLY PRESET BODY:");
  debugPrint(jsonEncode(body));

  final res = await http.post(
    Uri.parse(
      "$baseUrl/booking-galleries/revision-requests/$requestId/apply-preset",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode(body),
  );

  debugPrint("APPLY PRESET STATUS: ${res.statusCode}");
  debugPrint("APPLY PRESET RESPONSE: ${res.body}");

  final data = jsonDecode(res.body) as Map<String, dynamic>;

  if (res.statusCode == 200 || res.statusCode == 201) {
    return data;
  }

  throw Exception(
    data["error"] ?? data["message"] ?? "Failed to apply preset.",
  );
}

static Future<Map<String, dynamic>> suggestRevisionEditPlan({
  required int requestId,
  bool regenerate = false,
}) async {
  final token = await AuthService.getToken();

  if (token == null) {
    throw Exception("You are not logged in.");
  }

  final res = await http.post(
    Uri.parse(
      "$baseUrl/booking-galleries/revision-requests/$requestId/ai-suggest-plan",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "regenerate": regenerate,
    }),
  );

  debugPrint("AI SUGGEST PLAN STATUS: ${res.statusCode}");
  debugPrint("AI SUGGEST PLAN RESPONSE: ${res.body}");

  final data = _decode(res.body);

  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["error"] ?? data["message"] ?? "Failed to generate AI edit plan.",
  );
}

}