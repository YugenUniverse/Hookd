import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../models/wall.dart';

class WallService {
  static String get baseUrl => ApiConfig.apiBaseUrl;

  Future<List<Wall>> fetchAllWalls() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/walls'));

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

  Future<List<Wall>> searchWalls(String query) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/walls/search',
      ).replace(queryParameters: {'q': query});
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as List<dynamic>;
        return jsonResponse
            .map((data) => Wall.fromJson(data as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to search walls: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching walls: $e');
    }
  }
}
