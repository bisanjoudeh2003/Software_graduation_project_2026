import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class NotificationService {

  static String get baseUrl =>
      "${AuthService.apiBase}/notifications";

  static Future<List> getNotifications() async {

    String? token = await AuthService.getToken();

    final res = await http.get(

      Uri.parse(baseUrl),

      headers:{
        "Authorization":"Bearer $token"
      }

    );

    if(res.statusCode==200){
      return jsonDecode(res.body);
    }

    return [];

  }

  static Future markRead(int id) async {

    String? token = await AuthService.getToken();

    await http.put(

      Uri.parse("$baseUrl/read/$id"),

      headers:{
        "Authorization":"Bearer $token"
      }

    );

  }

}