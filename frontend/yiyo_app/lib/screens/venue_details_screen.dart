import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../models/vibe_report.dart';
import '../services/api_service.dart';

class VenueDetailsScreen extends StatefulWidget {
  final Venue venue;

  const VenueDetailsScreen({
    super.key,
    required this.venue,
  });

  @override
  State<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends State<VenueDetailsScreen> {
  bool _isLoading = true;
  String _yiyoBadge = "MID";
  List<VibeReport> _reports = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final data = await ApiService.getVenueReports(widget.venue.id);

      setState(() {
        _yiyoBadge = (data["yiyo_badge"] ?? "MID").toString();
        _reports = (data["reports"] as List<VibeReport>);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load venue reports";
        _isLoading = false;
      });
    }
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case "YIYO":
        return Colors.green;
      case "NOT YIYO":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;

    return Scaffold(
      appBar: AppBar(
        title: Text(venue.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("⭐ ${venue.rating.toStringAsFixed(1)}"),
                      const SizedBox(height: 6),
                      Text(venue.address),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor(_yiyoBadge),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _yiyoBadge,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        "Latest Vibe Reports",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_reports.isEmpty)
                        const Text("No reports yet for this venue.")
                      else
                        ..._reports.map((report) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${report.yiyoStatus} • ${report.crowdLevel} • ${report.safetyLevel}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text("Music: ${report.musicType}"),
                                  Text("Queue: ${report.queueLength}"),
                                  if (report.comment.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(report.comment),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    report.reportedAt,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}