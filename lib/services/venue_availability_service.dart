import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class VenueAvailabilityService {

  static String get baseUrl => "${AuthService.apiBase}/venue-availability";

  /// ADD AVAILABILITY
  static Future addAvailability(
    int venueId,
    String date,
    String startTime,
    String endTime
  ) async {

    String? token = await AuthService.getToken();

    final res = await http.post(

      Uri.parse(baseUrl),

      headers: {
        "Content-Type":"application/json",
        "Authorization":"Bearer $token"
      },

      body: jsonEncode({

        "venue_id": venueId,
        "date": date,
        "start_time": startTime,
        "end_time": endTime

      })

    );

    if (res.statusCode != 200) {
  final body = jsonDecode(res.body);
  throw Exception(body["message"] ?? "Failed to add availability");
}

  }

  /// GET AVAILABILITY
  static Future<List<Map<String,dynamic>>> getAvailability(
    int venueId
  ) async {

    final res = await http.get(
      Uri.parse("$baseUrl/$venueId")
    );

    if(res.statusCode == 200){

      final data = jsonDecode(res.body);

      return List<Map<String,dynamic>>.from(data);

    }

    return [];

  }

  /// DELETE AVAILABILITY
  static Future deleteAvailability(int id) async {

    String? token = await AuthService.getToken();

    final res = await http.delete(

      Uri.parse("$baseUrl/$id"),

      headers:{
        "Authorization":"Bearer $token"
      }

    );

    if(res.statusCode != 200){
      throw Exception("Delete failed");
    }

  }

  /// UPDATE AVAILABILITY
  static Future updateAvailability(
    int id,
    String startTime,
    String endTime
  ) async {

    String? token = await AuthService.getToken();

    final res = await http.put(

      Uri.parse("$baseUrl/$id"),

      headers:{
        "Content-Type":"application/json",
        "Authorization":"Bearer $token"
      },

      body: jsonEncode({

        "start_time": startTime,
        "end_time": endTime

      })

    );

    if(res.statusCode != 200){
      throw Exception("Update failed");
    }

  }

  static Future<Map<String, dynamic>?> bulkAddAvailability({
  required int venueId,
  required String startDate,
  required String endDate,
  required List<int> daysOfWeek,
  required String startTime,
  required String endTime,
  List<String> exceptions = const [],
}) async {
  final token = await AuthService.getToken();
  if (token == null) return null;

  final res = await http.post(
    Uri.parse("$baseUrl/availability/bulk"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode({
      "venue_id":     venueId,
      "start_date":   startDate,
      "end_date":     endDate,
      "days_of_week": daysOfWeek,
      "start_time":   startTime,
      "end_time":     endTime,
      "exceptions":   exceptions,
    }),
  );

  if (res.statusCode == 200) return jsonDecode(res.body);
  return null;
}

}