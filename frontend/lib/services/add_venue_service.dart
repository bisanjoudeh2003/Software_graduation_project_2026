import 'dart:convert';
import 'package:http/http.dart' as http;

class AddVenueService {

  static const String baseUrl = "http://10.0.2.2:3000/api";

  static Future createVenue(
      String token,
      String name,
      String description,
      String location,
      double latitude,
      double longitude,
      String price,
      String imageUrl
      ) async {

    final res = await http.post(
        Uri.parse("$baseUrl/venues"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "name": name,
          "description": description,
          "location": location,
          "latitude": latitude,
          "longitude": longitude,
          "price_per_hour": price,
          "image_url": imageUrl
        })
    );

    if(res.statusCode == 200){
      return jsonDecode(res.body);
    }

    throw Exception("Failed to create venue");
  }
}