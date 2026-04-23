import 'dart:convert';
import 'package:http/http.dart' as http;

class RatingService {

  static const String baseUrl = "http://10.0.2.2:3000/api";

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