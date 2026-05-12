import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wall.dart';

class WallService {
  static const String baseUrl = 'http://localhost:3000';

  Future<List<Wall>> fetchAllWalls() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/walls/getAll'));

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Wall.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load walls: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching walls: $e');
    }
  }
}
