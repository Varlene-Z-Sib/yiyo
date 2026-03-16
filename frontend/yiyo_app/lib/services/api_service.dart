import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = "http://127.0.0.1:8000";

  static Future getVenues() async {
    final response = await http.get(Uri.parse("$baseUrl/venues"));

    return response.body;
  }
}