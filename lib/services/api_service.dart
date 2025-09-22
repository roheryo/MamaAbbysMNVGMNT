import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // For Android emulator use 10.0.2.2, iOS simulator use localhost.
  // For real device use your PC LAN IP: e.g. http://192.168.1.50:3000
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<List<dynamic>> getTodos() async {
    final resp = await http.get(Uri.parse('$baseUrl/todos'));
    if (resp.statusCode == 200) {
      return List<dynamic>.from(json.decode(resp.body));
    } else {
      throw Exception('Failed to load todos - ${resp.statusCode}');
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    if (resp.statusCode == 201) return json.decode(resp.body);
    throw Exception('Register failed ${resp.statusCode}: ${resp.body}');
  }

  // add update/delete similarly...
}
