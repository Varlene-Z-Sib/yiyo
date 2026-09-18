import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/venue.dart';
import '../models/vibe_report.dart';
import '../models/vibe_report_request.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() {
    return message;
  }
}

class ApiService {
  static String get baseUrl =>
      dotenv.env["BACKEND_BASE_URL"] ??
      "http://127.0.0.1:8000";

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getIdToken();

    return {
      "Content-Type": "application/json",
      if (token != null)
        "Authorization": "Bearer $token",
    };
  }

  static String _errorMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final decoded =
          jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded["detail"];

        if (detail != null) {
          return detail.toString();
        }
      }
    } catch (_) {
      // Fall back to the supplied message below.
    }

    return fallback;
  }

  static Future<List<Venue>> getVenues({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/venues?lat=$lat&lng=$lng",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(
          response,
          fallback: "Failed to load venues",
        ),
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final venuesJson =
        data["venues"] as List<dynamic>? ?? [];

    return venuesJson
        .map(
          (item) => Venue.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<List<Venue>> getYiyoVenues({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/venues/yiyo?lat=$lat&lng=$lng",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(
          response,
          fallback:
              "Failed to load YIYO venues",
        ),
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final venuesJson =
        data["venues"] as List<dynamic>? ?? [];

    return venuesJson
        .map(
          (item) => Venue.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>>
      searchVenues({
    required String query,
    required double lat,
    required double lng,
    bool enrichArea = false,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/search?"
      "q=${Uri.encodeQueryComponent(query)}"
      "&lat=$lat"
      "&lng=$lng"
      "&enrich_area=$enrichArea",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(
          response,
          fallback: "Search failed",
        ),
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final bestMatchJson =
        data["best_match"];

    final relatedJson =
        data["related_venues"]
                as List<dynamic>? ??
            [];

    final bestMatch =
        bestMatchJson == null
            ? null
            : Venue.fromJson(
                bestMatchJson
                    as Map<String, dynamic>,
              );

    final relatedVenues =
        relatedJson
            .map(
              (item) => Venue.fromJson(
                item
                    as Map<String, dynamic>,
              ),
            )
            .toList();

    return {
      "source": data["source"],
      "used_places_call":
          data["used_places_call"] ?? false,
      "enriched_area":
          data["enriched_area"] ?? false,
      "best_match": bestMatch,
      "related_venues": relatedVenues,
    };
  }

  static Future<void> submitVibeReport(
    VibeReportRequest report,
  ) async {
    final uri = Uri.parse(
      "$baseUrl/reports",
    );

    final response = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode(
        report.toJson(),
      ),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(
          response,
          fallback:
              "Failed to submit report",
        ),
      );
    }
  }

  static Future<Map<String, dynamic>>
      getVenueReports(
    String venueId,
  ) async {
    final uri = Uri.parse(
      "$baseUrl/reports/$venueId",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(
          response,
          fallback:
              "Failed to fetch reports",
        ),
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final reportsJson =
        data["reports"] as List<dynamic>? ??
            [];

    final reports =
        reportsJson
            .map(
              (item) =>
                  VibeReport.fromJson(
                item
                    as Map<String, dynamic>,
              ),
            )
            .toList();

    return {
      "count":
          data["count"] ?? reports.length,
      "yiyo_badge":
          data["yiyo_badge"] ?? "MID",
      "reports": reports,
    };
  }

  static Future<Map<String, dynamic>>
      flagReport({
    required String reportId,
    required String reason,
    String details = "",
  }) async {
    final uri = Uri.parse(
      "$baseUrl/reports/$reportId/flag",
    );

    final response = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode(
        {
          "reason": reason,
          "details": details.trim(),
        },
      ),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(
          response,
          fallback:
              "Failed to report this update",
        ),
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }
}