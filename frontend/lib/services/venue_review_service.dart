import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class RatingService {

static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }
  static Future addReview(
    String token,
    int venueId,
    double rating,
    String comment
  ) async {

    final res = await http.post(
      Uri.parse("$baseUrl/reviews"),
      headers:{
        "Content-Type":"application/json",
        "Authorization":"Bearer $token"
      },
      body: jsonEncode({
        "venue_id":venueId,
        "rating":rating,
        "comment":comment
      })
    );

    if(res.statusCode!=200){
      throw Exception("Failed to add review");
    }

  }

}