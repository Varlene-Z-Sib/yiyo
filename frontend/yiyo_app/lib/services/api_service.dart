import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  
  static const baseUrl = "http://10.254.89.160:5000";

  static Future<List<dynamic>> getVenues() async {

    final response = await http.get(Uri.parse("$baseUrl/venues"));

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      return data["venues"];

    } else {

      throw Exception("Failed to load venues");

    }

  }
}