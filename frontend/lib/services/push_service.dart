import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PushService {

static Future saveToken(String token) async {

String? auth = await AuthService.getToken();

await http.post(

Uri.parse("${AuthService.apiBase}/save-token"),

headers:{
"Content-Type":"application/json",
"Authorization":"Bearer $auth"
},

body: jsonEncode({
"token":token
})

);

}

}