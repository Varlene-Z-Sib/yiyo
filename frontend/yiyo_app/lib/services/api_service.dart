import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/venue.dart';

class ApiService {
  // Replace this with your laptop's local IP address
  // Example: http://192.168.0.104:8000
  static const String baseUrl = "http://192.168.101.109:8000";

  static Future<List<Venue>> getVenues({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/venues?lat=$lat&lng=$lng",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("Failed to load venues: ${response.statusCode}");
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final venuesJson = (data["venues"] as List<dynamic>? ?? []);

    return venuesJson
        .map((item) => Venue.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}